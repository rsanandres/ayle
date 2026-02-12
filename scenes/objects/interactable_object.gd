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
var _use_indicator: Node2D = null


func _ready() -> void:
	if passive_effect_radius > 0.0:
		EventBus.time_tick.connect(_on_passive_tick)
	_setup_use_indicator()


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
		_update_use_indicator()


func release(agent: Node2D) -> void:
	_occupants.erase(agent)
	_update_use_indicator()


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


func _setup_use_indicator() -> void:
	_use_indicator = Node2D.new()
	_use_indicator.visible = false
	_use_indicator.z_index = -1
	add_child(_use_indicator)
	_use_indicator.draw.connect(_draw_use_indicator)


func _draw_use_indicator() -> void:
	if _use_indicator:
		var pulse := 0.3 + sin(Time.get_ticks_msec() * 0.004) * 0.15
		_use_indicator.draw_arc(Vector2.ZERO, 12.0, 0, TAU, 16, Color(0.4, 0.7, 1.0, pulse), 1.0)


func _update_use_indicator() -> void:
	if not _use_indicator:
		return
	_use_indicator.visible = not _occupants.is_empty()


func _process(_delta: float) -> void:
	if _use_indicator and _use_indicator.visible:
		_use_indicator.queue_redraw()
