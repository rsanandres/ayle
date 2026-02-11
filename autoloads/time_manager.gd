extends Node
## Game clock: 1 real second = 1 game minute at 1x speed.

const SPEED_MULTIPLIERS := [0.0, 1.0, 2.0, 3.0]
const SPEED_LABELS := ["Paused", "1x", "2x", "3x"]

var game_minutes: float = 480.0  # Start at 8:00 AM (8 * 60)
var speed_index: int = 1
var _accumulator: float = 0.0

var is_paused: bool:
	get: return speed_index == 0

var current_speed: float:
	get: return SPEED_MULTIPLIERS[speed_index]

var hours: int:
	get: return int(game_minutes / 60.0) % 24

var minutes: int:
	get: return int(game_minutes) % 60

var time_string: String:
	get: return "%02d:%02d" % [hours, minutes]

var day: int:
	get: return int(game_minutes / 1440.0) + 1


func _process(delta: float) -> void:
	if is_paused:
		return
	_accumulator += delta * current_speed
	if _accumulator >= 1.0:
		var ticks := int(_accumulator)
		game_minutes += ticks
		_accumulator -= ticks
		EventBus.time_tick.emit(game_minutes)


func set_speed(index: int) -> void:
	var old := speed_index
	speed_index = clampi(index, 0, SPEED_MULTIPLIERS.size() - 1)
	if speed_index != old:
		EventBus.time_speed_changed.emit(speed_index)
		if speed_index == 0:
			EventBus.time_paused.emit()
		elif old == 0:
			EventBus.time_resumed.emit()


func toggle_pause() -> void:
	if is_paused:
		set_speed(1)
	else:
		set_speed(0)


func increase_speed() -> void:
	set_speed(speed_index + 1)


func decrease_speed() -> void:
	set_speed(speed_index - 1)
