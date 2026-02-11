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
	# Roll for random events each day
	for definition in _event_definitions:
		# Check cooldown
		var last_triggered: int = _cooldowns.get(definition.event_id, 0)
		if day - last_triggered < definition.cooldown_days:
			continue
		# Roll probability
		if randf() < definition.probability:
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
