class_name InteractableObject
extends StaticBody2D
## Base class for all office objects agents can interact with.

@export var object_type: String = "generic"
@export var interaction_duration: float = 30.0  # game minutes
@export var display_name: String = "Object"

var _occupied_by: Node2D = null
var _need_effects: Dictionary = {}  # NeedType.Type -> float


func get_object_type() -> String:
	return object_type


func get_interaction_duration() -> float:
	return interaction_duration


func get_need_effects() -> Dictionary:
	return _need_effects


func is_available() -> bool:
	return _occupied_by == null


func occupy(agent: Node2D) -> void:
	_occupied_by = agent


func release(_agent: Node2D) -> void:
	_occupied_by = null


func get_occupant() -> Node2D:
	return _occupied_by
