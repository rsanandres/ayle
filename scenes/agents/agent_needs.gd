class_name AgentNeeds
extends Node
## Tracks and decays an agent's needs over game time.

signal need_changed(need: NeedType.Type, value: float)
signal need_critical(need: NeedType.Type)

var _values: Dictionary = {}
var _decay_rates: Dictionary = {}
var _agent: Node2D


func _ready() -> void:
	_agent = get_parent()
	for need in NeedType.get_all():
		_values[need] = Config.NEED_MAX
		_decay_rates[need] = Config.NEED_DECAY_BASE[need]
	EventBus.time_tick.connect(_on_time_tick)


func get_value(need: NeedType.Type) -> float:
	return _values.get(need, 0.0)


func set_value(need: NeedType.Type, value: float) -> void:
	var old := _values[need]
	_values[need] = clampf(value, 0.0, Config.NEED_MAX)
	if _values[need] != old:
		need_changed.emit(need, _values[need])
		EventBus.agent_need_changed.emit(_agent, need, _values[need])
		if _values[need] <= Config.NEED_CRITICAL_THRESHOLD and old > Config.NEED_CRITICAL_THRESHOLD:
			need_critical.emit(need)
			EventBus.agent_need_critical.emit(_agent, need)


func restore(need: NeedType.Type, amount: float) -> void:
	set_value(need, _values[need] + amount)


func get_most_urgent() -> NeedType.Type:
	var lowest_need := NeedType.Type.ENERGY
	var lowest_value := Config.NEED_MAX + 1.0
	for need in NeedType.get_all():
		if _values[need] < lowest_value:
			lowest_value = _values[need]
			lowest_need = need
	return lowest_need


func get_all_values() -> Dictionary:
	return _values.duplicate()


func set_decay_rate(need: NeedType.Type, rate: float) -> void:
	_decay_rates[need] = rate


func _on_time_tick(_game_minutes: float) -> void:
	for need in NeedType.get_all():
		set_value(need, _values[need] - _decay_rates[need])
