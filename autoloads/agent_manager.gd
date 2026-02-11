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


func get_agents_near(position: Vector2, radius: float, exclude: Node2D = null) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for agent in agents:
		if agent == exclude:
			continue
		if agent.global_position.distance_to(position) <= radius:
			result.append(agent)
	return result


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
