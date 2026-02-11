class_name HeuristicBrain
extends Node
## Fallback decision-making: picks actions based on most urgent need.

# Maps need types to preferred object types for fulfillment
const NEED_TO_OBJECT_TYPE := {
	NeedType.Type.ENERGY: "couch",
	NeedType.Type.HUNGER: "coffee_machine",
	NeedType.Type.SOCIAL: "",  # handled via talk_to_agent
	NeedType.Type.PRODUCTIVITY: "desk",
}

var _agent: Node2D


func _ready() -> void:
	_agent = get_parent()


func decide(needs: AgentNeeds, nearby_objects: Array, nearby_agents: Array) -> Dictionary:
	var urgent_need := needs.get_most_urgent()
	var urgent_value := needs.get_value(urgent_need)

	# If no needs are particularly pressing, wander or idle
	if urgent_value > 70.0:
		if randf() < 0.3:
			return {"action": ActionType.Type.WANDER}
		return {"action": ActionType.Type.IDLE}

	# Social need: try to talk
	if urgent_need == NeedType.Type.SOCIAL and not nearby_agents.is_empty():
		var target_agent = nearby_agents[randi() % nearby_agents.size()]
		return {"action": ActionType.Type.TALK_TO_AGENT, "target": target_agent}

	# Find an object that satisfies the need
	var desired_type: String = NEED_TO_OBJECT_TYPE.get(urgent_need, "")
	if desired_type != "":
		var best_object: Node2D = _find_available_object(nearby_objects, desired_type)
		if best_object:
			return {"action": ActionType.Type.GO_TO_OBJECT, "target": best_object}

	# Fallback: wander to find something
	return {"action": ActionType.Type.WANDER}


func _find_available_object(objects: Array, object_type: String) -> Node2D:
	var candidates: Array[Node2D] = []
	for obj in objects:
		if obj.has_method("get_object_type") and obj.get_object_type() == object_type:
			if obj.has_method("is_available") and obj.is_available():
				candidates.append(obj)
	if candidates.is_empty():
		return null
	# Pick the closest one
	var closest: Node2D = null
	var closest_dist := INF
	for c in candidates:
		var dist: float = _agent.global_position.distance_squared_to(c.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = c
	return closest
