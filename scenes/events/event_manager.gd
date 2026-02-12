extends Node
## Autoload: manages random and triggered life events.

var _event_definitions: Array[EventDefinition] = []
var _active_events: Array[Dictionary] = []  # {definition, affected_agents, start_time, end_time}
var _cooldowns: Dictionary = {}  # event_id -> last_triggered_day
var _loaded: bool = false


func _ready() -> void:
	_load_events()
	EventBus.day_changed.connect(_on_day_changed)
	EventBus.time_tick.connect(_on_time_tick)


func trigger_event(event_id: String, specific_agents: Array = []) -> bool:
	var definition := _find_definition(event_id)
	if not definition:
		push_warning("EventManager: Unknown event '%s'" % event_id)
		return false
	return _execute_event(definition, specific_agents)


func get_available_events() -> Array[EventDefinition]:
	return _event_definitions


func get_active_events() -> Array[Dictionary]:
	return _active_events


func _on_day_changed(day: int) -> void:
	# Get drama-based probability modifier from the DramaDirector.
	var drama_mod: float = 1.0
	if DramaDirector:
		drama_mod = DramaDirector.get_probability_modifier()
		# Sync narrator drama into the director once per day.
		DramaDirector.sync_with_narrator()

	# Roll for random events each day
	for definition in _event_definitions:
		# Check cooldown
		var last_triggered: int = _cooldowns.get(definition.event_id, 0)
		if day - last_triggered < definition.cooldown_days:
			continue
		# Roll probability, scaled by drama pacing
		var adjusted_prob: float = definition.probability * drama_mod
		if randf() < adjusted_prob:
			_execute_event(definition)


func _on_time_tick(game_minutes: float) -> void:
	# Check for ending active events
	var to_remove: Array[int] = []
	for i in range(_active_events.size()):
		var ev: Dictionary = _active_events[i]
		if ev["end_time"] > 0.0 and game_minutes >= ev["end_time"]:
			_end_event(ev)
			to_remove.append(i)
	to_remove.reverse()
	for idx in to_remove:
		_active_events.remove_at(idx)


func _execute_event(definition: EventDefinition, specific_agents: Array = []) -> bool:
	var affected: Array = specific_agents
	if affected.is_empty():
		affected = _select_targets(definition)
	if affected.is_empty() and definition.target_mode != "global":
		return false

	_cooldowns[definition.event_id] = TimeManager.day

	var start_time := TimeManager.game_minutes
	var end_time := start_time + definition.duration_minutes if definition.duration_minutes > 0 else 0.0

	var event_data := {
		"definition": definition,
		"affected_agents": affected,
		"start_time": start_time,
		"end_time": end_time,
	}

	if definition.duration_minutes > 0:
		_active_events.append(event_data)

	# Apply immediate effects
	_apply_effects(definition, affected)

	# Apply cascading consequences
	_apply_consequences(definition.event_id, affected)

	# Create memories for witnesses
	_create_event_memories(definition, affected)

	# Emit signals
	var agent_names: Array = []
	for a in affected:
		agent_names.append(a.agent_name if a is Node2D and a.has_method("request_think") else str(a))
	EventBus.event_triggered.emit(definition.event_id, agent_names)
	EventBus.narrative_event.emit(
		definition.description,
		agent_names, 6.0
	)
	return true


func _end_event(event_data: Dictionary) -> void:
	var definition: EventDefinition = event_data["definition"]
	# Undo global effects
	if definition.global_effect == "disable_objects":
		pass  # Objects auto-resume when event ends
	EventBus.event_ended.emit(definition.event_id)


func _select_targets(definition: EventDefinition) -> Array:
	var agents := AgentManager.agents
	if agents.is_empty():
		return []
	match definition.target_mode:
		"random":
			return [agents[randi() % agents.size()]]
		"most_productive":
			var best: Node2D = null
			var best_val: float = -1.0
			for a in agents:
				var val: float = a.needs.get_value(NeedType.Type.PRODUCTIVITY)
				if val > best_val:
					best_val = val
					best = a
			return [best] if best else []
		"most_social":
			var best: Node2D = null
			var best_val: float = -1.0
			for a in agents:
				var val: float = a.needs.get_value(NeedType.Type.SOCIAL)
				if val > best_val:
					best_val = val
					best = a
			return [best] if best else []
		"global":
			return agents.duplicate()
		_:
			return [agents[randi() % agents.size()]]


func _apply_effects(definition: EventDefinition, affected: Array) -> void:
	for agent in affected:
		if not is_instance_valid(agent) or not agent.has_node("AgentNeeds"):
			continue
		for need in definition.need_effects:
			var delta: float = definition.need_effects[need]
			agent.needs.restore(need, delta)
		# Special conditions
		match definition.event_id:
			"flu_outbreak":
				if agent.health_state:
					agent.health_state.add_condition("flu")
			"exhaustion_collapse":
				if agent.health_state:
					agent.health_state.add_condition("exhaustion")
			"recovery":
				if agent.health_state:
					agent.health_state.conditions.clear()


func _apply_consequences(event_id: String, affected: Array) -> void:
	match event_id:
		"heated_argument":
			_consequence_heated_argument(affected)
		"flu_outbreak":
			_consequence_flu_spread(affected)
		"promotion":
			_consequence_promotion_reactions(affected)
		"exhaustion_collapse":
			_consequence_exhaustion_collapse(affected)


func _consequence_heated_argument(affected: Array) -> void:
	# Need at least 2 agents for an argument; pick a second from nearby if only 1 targeted
	var agents_in_argument: Array = affected.duplicate()
	if agents_in_argument.size() == 1 and is_instance_valid(agents_in_argument[0]):
		var nearby := AgentManager.get_agents_near(agents_in_argument[0].global_position, 120.0, agents_in_argument[0])
		if not nearby.is_empty():
			agents_in_argument.append(nearby[randi() % nearby.size()])
	if agents_in_argument.size() < 2:
		return

	var agent_a: Node2D = agents_in_argument[0]
	var agent_b: Node2D = agents_in_argument[1]
	if not is_instance_valid(agent_a) or not is_instance_valid(agent_b):
		return

	# Add angry tags and reduce affinity
	var rel_a: RelationshipEntry = agent_a.relationships.get_relationship(agent_b.agent_name)
	rel_a.add_tag("angry_at_%s" % agent_b.agent_name)
	rel_a.affinity = clampf(rel_a.affinity - 15.0, -100.0, 100.0)
	EventBus.relationship_changed.emit(agent_a.agent_name, agent_b.agent_name, rel_a)

	var rel_b: RelationshipEntry = agent_b.relationships.get_relationship(agent_a.agent_name)
	rel_b.add_tag("angry_at_%s" % agent_a.agent_name)
	rel_b.affinity = clampf(rel_b.affinity - 15.0, -100.0, 100.0)
	EventBus.relationship_changed.emit(agent_b.agent_name, agent_a.agent_name, rel_b)

	# Add memories about the argument
	agent_a.memory.add_memory(
		MemoryEntry.MemoryType.OBSERVATION,
		"%s had a heated argument with %s. Things got personal." % [agent_a.agent_name, agent_b.agent_name],
		7.0, PackedStringArray([agent_b.agent_name])
	)
	agent_a.memory.memories[-1].emotion = "anger"
	agent_a.memory.memories[-1].sentiment = -0.7

	agent_b.memory.add_memory(
		MemoryEntry.MemoryType.OBSERVATION,
		"%s had a heated argument with %s. Things got personal." % [agent_b.agent_name, agent_a.agent_name],
		7.0, PackedStringArray([agent_a.agent_name])
	)
	agent_b.memory.memories[-1].emotion = "anger"
	agent_b.memory.memories[-1].sentiment = -0.7

	EventBus.narrative_event.emit(
		"%s and %s had a bitter argument — their relationship took a hit." % [agent_a.agent_name, agent_b.agent_name],
		[agent_a.agent_name, agent_b.agent_name], 7.0
	)


func _consequence_flu_spread(affected: Array) -> void:
	# For each initially sick agent, check nearby agents for contagion
	var newly_infected: Array = []
	for sick_agent in affected:
		if not is_instance_valid(sick_agent):
			continue
		var nearby := AgentManager.get_agents_near(sick_agent.global_position, 80.0, sick_agent)
		for other in nearby:
			if not is_instance_valid(other) or other in affected or other in newly_infected:
				continue
			if not other.health_state:
				continue
			# 30% chance of catching flu
			if randf() < 0.3:
				other.health_state.add_condition("flu")
				other.needs.restore(NeedType.Type.ENERGY, -15.0)
				other.needs.restore(NeedType.Type.HEALTH, -10.0)
				newly_infected.append(other)
				other.memory.add_memory(
					MemoryEntry.MemoryType.OBSERVATION,
					"%s caught the flu from being near %s." % [other.agent_name, sick_agent.agent_name],
					5.0, PackedStringArray([sick_agent.agent_name])
				)
				other.memory.memories[-1].emotion = "discomfort"
				other.memory.memories[-1].sentiment = -0.5

	if not newly_infected.is_empty():
		var names: Array = []
		for a in newly_infected:
			names.append(a.agent_name)
		EventBus.narrative_event.emit(
			"The flu is spreading! %s also caught it." % ", ".join(PackedStringArray(names)),
			names, 6.0
		)


func _consequence_promotion_reactions(affected: Array) -> void:
	if affected.is_empty():
		return
	var promoted_agent: Node2D = affected[0]
	if not is_instance_valid(promoted_agent):
		return

	for agent in AgentManager.agents:
		if not is_instance_valid(agent) or agent == promoted_agent:
			continue
		if not agent.personality:
			continue

		var agreeableness: float = agent.personality.agreeableness
		var rel: RelationshipEntry = agent.relationships.get_relationship(promoted_agent.agent_name)

		if agreeableness < 0.4:
			# Jealousy — reduce affinity
			rel.affinity = clampf(rel.affinity - 10.0, -100.0, 100.0)
			rel.add_tag("jealous")
			agent.memory.add_memory(
				MemoryEntry.MemoryType.OBSERVATION,
				"%s feels jealous about %s getting promoted. Why not me?" % [agent.agent_name, promoted_agent.agent_name],
				5.0, PackedStringArray([promoted_agent.agent_name])
			)
			agent.memory.memories[-1].emotion = "jealousy"
			agent.memory.memories[-1].sentiment = -0.5
		elif agreeableness > 0.7:
			# Supportive — increase affinity
			rel.affinity = clampf(rel.affinity + 5.0, -100.0, 100.0)
			agent.memory.add_memory(
				MemoryEntry.MemoryType.OBSERVATION,
				"%s is happy for %s getting promoted. They deserve it!" % [agent.agent_name, promoted_agent.agent_name],
				4.0, PackedStringArray([promoted_agent.agent_name])
			)
			agent.memory.memories[-1].emotion = "happiness"
			agent.memory.memories[-1].sentiment = 0.6

		EventBus.relationship_changed.emit(agent.agent_name, promoted_agent.agent_name, rel)


func _consequence_exhaustion_collapse(affected: Array) -> void:
	for agent in affected:
		if not is_instance_valid(agent):
			continue

		# Force energy to 0
		agent.needs.set_value(NeedType.Type.ENERGY, 0.0)

		# Add exhaustion condition if not already present
		if agent.health_state and not agent.health_state.conditions.has("exhaustion"):
			agent.health_state.add_condition("exhaustion")

		# Try to find a bed and navigate to it
		var bed: Node2D = _find_nearest_object(agent.global_position, "bed")
		if bed:
			agent.current_target = bed
			agent.current_action = ActionType.Type.GO_TO_OBJECT
			agent._navigate_to(bed.global_position)
			agent.memory.add_memory(
				MemoryEntry.MemoryType.OBSERVATION,
				"%s collapsed from exhaustion and is stumbling toward the bed." % agent.agent_name,
				7.0
			)
			agent.memory.memories[-1].emotion = "exhaustion"
			agent.memory.memories[-1].sentiment = -0.8
		else:
			# No bed available — collapse in place
			agent.state = AgentState.Type.IDLE
			agent.memory.add_memory(
				MemoryEntry.MemoryType.OBSERVATION,
				"%s collapsed from exhaustion with nowhere to rest." % agent.agent_name,
				8.0
			)
			agent.memory.memories[-1].emotion = "despair"
			agent.memory.memories[-1].sentiment = -0.9

		EventBus.narrative_event.emit(
			"%s collapsed from exhaustion!" % agent.agent_name,
			[agent.agent_name], 8.0
		)


func _find_nearest_object(pos: Vector2, obj_type: String) -> Node2D:
	var world: Node2D = null
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		world = tree.get_first_node_in_group("world")
	if not world or not world.has_method("get_all_objects"):
		return null
	var best: Node2D = null
	var best_dist: float = INF
	for obj in world.get_all_objects():
		if obj.object_type == obj_type:
			var dist: float = pos.distance_to(obj.global_position)
			if dist < best_dist:
				best_dist = dist
				best = obj
	return best


func _create_event_memories(definition: EventDefinition, affected: Array) -> void:
	# All nearby agents witness the event
	for agent in AgentManager.agents:
		if not is_instance_valid(agent):
			continue
		var is_affected := agent in affected
		var importance: float = 6.0 if is_affected else 3.0
		var desc: String
		if is_affected:
			desc = "%s experienced: %s" % [agent.agent_name, definition.description]
		else:
			desc = "%s observed: %s" % [agent.agent_name, definition.description]
		agent.memory.add_observation(desc, importance)


func _find_definition(event_id: String) -> EventDefinition:
	for ed in _event_definitions:
		if ed.event_id == event_id:
			return ed
	return null


func _load_events() -> void:
	var path := "res://resources/events/events.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("EventManager: Could not load events.json")
		_load_default_events()
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("EventManager: JSON parse error in events.json")
		_load_default_events()
		return
	var data: Array = json.data
	for entry in data:
		_event_definitions.append(EventDefinition.from_dict(entry))
	_loaded = true


func _load_default_events() -> void:
	# Hardcoded fallback if JSON fails
	var events_data: Array = [
		{"id": "gossip_spreads", "name": "Gossip Spreads", "description": "Office gossip is making the rounds.", "probability": 0.15, "category": "social", "target_mode": "random", "need_effects": {"social": 10}, "cooldown_days": 2},
		{"id": "heated_argument", "name": "Heated Argument", "description": "A heated argument breaks out.", "probability": 0.05, "category": "social", "target_mode": "random", "need_effects": {"social": -15}, "cooldown_days": 3},
		{"id": "promotion", "name": "Promotion", "description": "Someone earned a promotion!", "probability": 0.03, "category": "work", "target_mode": "most_productive", "need_effects": {"productivity": 30, "social": 10}, "cooldown_days": 10},
		{"id": "pizza_delivery", "name": "Pizza Delivery", "description": "Someone ordered pizza for the office!", "probability": 0.1, "category": "environment", "target_mode": "global", "need_effects": {"hunger": 40}, "cooldown_days": 3},
		{"id": "flu_outbreak", "name": "Flu Outbreak", "description": "A flu is going around the office.", "probability": 0.04, "category": "health", "target_mode": "random", "need_effects": {"energy": -20, "health": -10}, "cooldown_days": 7},
		{"id": "birthday", "name": "Birthday", "description": "It's someone's birthday today!", "probability": 0.08, "category": "personal", "target_mode": "random", "need_effects": {"social": 25}, "cooldown_days": 5},
	]
	for entry in events_data:
		_event_definitions.append(EventDefinition.from_dict(entry))
	_loaded = true
