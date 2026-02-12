extends Node
## Registry of all agents. Tiered round-robin think ticks with spatial grid.

enum ThinkTier { ACTIVE, NORMAL, BACKGROUND }

var agents: Array[Node2D] = []
var spatial_grid: SpatialGrid = null
var _spawn_index: int = 0

# Tiered scheduling
var _agent_tiers: Dictionary = {}  # Node2D -> ThinkTier
var _tier_timers: Dictionary = {
	ThinkTier.ACTIVE: 0.0,
	ThinkTier.NORMAL: 0.0,
	ThinkTier.BACKGROUND: 0.0,
}
var _tier_indices: Dictionary = {
	ThinkTier.ACTIVE: 0,
	ThinkTier.NORMAL: 0,
	ThinkTier.BACKGROUND: 0,
}
var _tier_reclassify_timer: float = 0.0
var _grid_update_timer: float = 0.0


func _ready() -> void:
	spatial_grid = SpatialGrid.new(Config.SPATIAL_GRID_CELL_SIZE)


func register(agent: Node2D) -> void:
	if agent not in agents:
		agents.append(agent)
		_agent_tiers[agent] = ThinkTier.NORMAL
		spatial_grid.update_agent(agent)
		EventBus.agent_spawned.emit(agent)


func unregister(agent: Node2D) -> void:
	agents.erase(agent)
	_agent_tiers.erase(agent)
	spatial_grid.remove_agent(agent)
	# Check if all agents are dead
	if agents.is_empty():
		call_deferred("_check_all_dead")


func _check_all_dead() -> void:
	if agents.is_empty():
		EventBus.all_agents_dead.emit()


func get_agent_by_name(agent_name: String) -> Node2D:
	for agent in agents:
		if agent.agent_name == agent_name:
			return agent
	return null


func get_agents_near(position: Vector2, radius: float, exclude: Node2D = null) -> Array[Node2D]:
	# Use spatial grid for large populations, linear scan for small
	if agents.size() > 10:
		return spatial_grid.get_agents_in_radius(position, radius, exclude)
	var result: Array[Node2D] = []
	for agent in agents:
		if agent == exclude:
			continue
		if agent.global_position.distance_to(position) <= radius:
			result.append(agent)
	return result


func spawn_agent(personality_file: String, pos: Vector2) -> Node2D:
	var agent_scene := preload("res://scenes/agents/agent.tscn")
	var agent: Node2D = agent_scene.instantiate()
	agent.personality_file = personality_file
	agent.position = pos
	var world := _get_world()
	if world:
		world.get_node("Agents").add_child(agent)
		EventBus.agent_spawned_dynamic.emit(agent)
		EventBus.narrative_event.emit(
			"A new person appeared: %s" % agent.agent_name,
			[agent.agent_name], 5.0
		)
		return agent
	return null


func spawn_procedural_agent(pos: Vector2, personality_data: Dictionary = {}) -> Node2D:
	var agent_scene := preload("res://scenes/agents/agent.tscn")
	var agent: Node2D = agent_scene.instantiate()
	agent.personality_file = "__procedural__"
	if personality_data.is_empty():
		var profile := PersonalityGenerator.generate_heuristic(_spawn_index)
		personality_data = profile.to_dict()
	agent.procedural_personality_data = personality_data
	agent.position = pos
	_spawn_index += 1
	var world := _get_world()
	if world:
		world.get_node("Agents").add_child(agent)
		EventBus.agent_spawned_dynamic.emit(agent)
		EventBus.narrative_event.emit(
			"A new person appeared: %s" % agent.agent_name,
			[agent.agent_name], 5.0
		)
		return agent
	return null


func remove_agent(agent_name: String) -> void:
	var agent := get_agent_by_name(agent_name)
	if agent:
		EventBus.agent_removed.emit(agent_name)
		EventBus.narrative_event.emit(
			"%s has left the office." % agent_name,
			[agent_name], 5.0
		)
		agent.queue_free()


func get_tier(agent: Node2D) -> ThinkTier:
	return _agent_tiers.get(agent, ThinkTier.NORMAL)


func _get_world() -> Node2D:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		return tree.get_first_node_in_group("world")
	return null


func _process(delta: float) -> void:
	if agents.is_empty() or TimeManager.is_paused:
		return

	# Update spatial grid periodically
	_grid_update_timer += delta
	if _grid_update_timer >= 0.5:
		_grid_update_timer = 0.0
		for agent in agents:
			if is_instance_valid(agent):
				spatial_grid.update_agent(agent)

	# Reclassify tiers every 2 seconds
	_tier_reclassify_timer += delta
	if _tier_reclassify_timer >= 2.0:
		_tier_reclassify_timer = 0.0
		_reclassify_tiers()

	# Small population: use simple round-robin like before
	if agents.size() <= Config.MAX_AGENTS_DESKTOP:
		_tier_timers[ThinkTier.ACTIVE] += delta
		if _tier_timers[ThinkTier.ACTIVE] >= Config.AGENT_THINK_INTERVAL:
			_tier_timers[ThinkTier.ACTIVE] -= Config.AGENT_THINK_INTERVAL
			_trigger_next_think_simple()
		return

	# Large population: tiered scheduling
	_tier_timers[ThinkTier.ACTIVE] += delta
	_tier_timers[ThinkTier.NORMAL] += delta
	_tier_timers[ThinkTier.BACKGROUND] += delta

	if _tier_timers[ThinkTier.ACTIVE] >= Config.THINK_TIER_ACTIVE_INTERVAL:
		_tier_timers[ThinkTier.ACTIVE] -= Config.THINK_TIER_ACTIVE_INTERVAL
		_trigger_tier_think(ThinkTier.ACTIVE)

	if _tier_timers[ThinkTier.NORMAL] >= Config.THINK_TIER_NORMAL_INTERVAL:
		_tier_timers[ThinkTier.NORMAL] -= Config.THINK_TIER_NORMAL_INTERVAL
		_trigger_tier_think(ThinkTier.NORMAL)

	if _tier_timers[ThinkTier.BACKGROUND] >= Config.THINK_TIER_BACKGROUND_INTERVAL:
		_tier_timers[ThinkTier.BACKGROUND] -= Config.THINK_TIER_BACKGROUND_INTERVAL
		_trigger_tier_think(ThinkTier.BACKGROUND)


func _trigger_next_think_simple() -> void:
	if agents.is_empty():
		return
	var idx: int = _tier_indices.get(ThinkTier.ACTIVE, 0) % agents.size()
	var agent := agents[idx]
	if agent.has_method("request_think"):
		agent.request_think()
	_tier_indices[ThinkTier.ACTIVE] = (idx + 1) % agents.size()


func _trigger_tier_think(tier: ThinkTier) -> void:
	var tier_agents: Array[Node2D] = _get_agents_in_tier(tier)
	if tier_agents.is_empty():
		return
	var idx: int = _tier_indices.get(tier, 0) % tier_agents.size()
	var agent := tier_agents[idx]
	if agent.has_method("request_think"):
		# Background agents always use heuristic
		if tier == ThinkTier.BACKGROUND and agent.has_node("AgentBrain"):
			agent.get_node("AgentBrain").force_heuristic = true
		elif agent.has_node("AgentBrain"):
			agent.get_node("AgentBrain").force_heuristic = false
		agent.request_think()
	_tier_indices[tier] = (idx + 1) % tier_agents.size()


func _get_agents_in_tier(tier: ThinkTier) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for agent in agents:
		if _agent_tiers.get(agent, ThinkTier.NORMAL) == tier:
			result.append(agent)
	return result


func _reclassify_tiers() -> void:
	# Get camera/viewport reference point
	var viewport := get_viewport()
	if not viewport:
		return
	var camera := viewport.get_camera_2d()
	var view_center := Vector2(240, 160)  # Desktop default
	var view_radius := 300.0

	if camera:
		view_center = camera.global_position
		var zoom: float = camera.zoom.x if camera.zoom.x > 0 else 1.0
		view_radius = max(viewport.get_visible_rect().size.x, viewport.get_visible_rect().size.y) / zoom

	# Selected agent is always active
	var selected: Node2D = GameManager.selected_agent

	for agent in agents:
		if not is_instance_valid(agent):
			continue
		var dist := agent.global_position.distance_to(view_center)
		if agent == selected or dist < 100.0:
			_agent_tiers[agent] = ThinkTier.ACTIVE
		elif dist < view_radius:
			_agent_tiers[agent] = ThinkTier.NORMAL
		else:
			_agent_tiers[agent] = ThinkTier.BACKGROUND
