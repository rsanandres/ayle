class_name InteractableObject
extends StaticBody2D
## Base class for all office objects agents can interact with.

@export var object_type: String = "generic"
@export var interaction_duration: float = 30.0  # game minutes
@export var display_name: String = "Object"
@export var max_occupants: int = 1
@export var passive_effect_radius: float = 0.0  # 0 = no passive effect
@export var passive_need_effects: Dictionary = {}  # NeedType.Type -> float per tick

var _occupants: Array[Node2D] = []
var _need_effects: Dictionary = {}  # NeedType.Type -> float


func _ready() -> void:
	if passive_effect_radius > 0.0:
		EventBus.time_tick.connect(_on_passive_tick)


func get_object_type() -> String:
	return object_type


func get_interaction_duration() -> float:
	return interaction_duration


func get_need_effects() -> Dictionary:
	return _need_effects


func is_available() -> bool:
	return _occupants.size() < max_occupants


func get_occupant_count() -> int:
	return _occupants.size()


func occupy(agent: Node2D) -> void:
	if agent not in _occupants and _occupants.size() < max_occupants:
		_occupants.append(agent)


func release(agent: Node2D) -> void:
	_occupants.erase(agent)


func get_occupant() -> Node2D:
	return _occupants[0] if not _occupants.is_empty() else null


func get_all_occupants() -> Array[Node2D]:
	return _occupants


func _on_passive_tick(_game_minutes: float) -> void:
	if passive_need_effects.is_empty():
		return
	# Apply passive effects to agents within radius
	var nearby := AgentManager.get_agents_near(global_position, passive_effect_radius)
	for agent in nearby:
		for need in passive_need_effects:
			var amount: float = passive_need_effects[need]
			agent.needs.restore(need, amount)
