extends Node
## Registry of all agents. Handles staggered round-robin think ticks.

var agents: Array[Node2D] = []
var _current_think_index: int = 0
var _think_timer: float = 0.0


func register(agent: Node2D) -> void:
	if agent not in agents:
		agents.append(agent)
		EventBus.agent_spawned.emit(agent)


func unregister(agent: Node2D) -> void:
	agents.erase(agent)


func get_agent_by_name(agent_name: String) -> Node2D:
	for agent in agents:
		if agent.agent_name == agent_name:
			return agent
	return null


func get_agents_near(position: Vector2, radius: float, exclude: Node2D = null) -> Array[Node2D]:
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
	# Add to the world's Agents container
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


func _get_world() -> Node2D:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		return tree.get_first_node_in_group("world")
	return null


func _process(delta: float) -> void:
	if agents.is_empty() or TimeManager.is_paused:
		return
	_think_timer += delta
	if _think_timer >= Config.AGENT_THINK_INTERVAL:
		_think_timer -= Config.AGENT_THINK_INTERVAL
		_trigger_next_think()


func _trigger_next_think() -> void:
	if agents.is_empty():
		return
	_current_think_index = _current_think_index % agents.size()
	var agent := agents[_current_think_index]
	if agent.has_method("request_think"):
		agent.request_think()
	_current_think_index = (_current_think_index + 1) % agents.size()
