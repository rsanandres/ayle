extends Camera2D
## Player camera with zoom and edge-pan.

var _target_zoom: float = 3.0
var _is_panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	zoom = Vector2(_target_zoom, _target_zoom)
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	# Center on the office
	position = Vector2(160, 120)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
			_pan_start = event.position
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_is_panning = event.pressed
			_pan_start = event.position
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _is_panning:
		var delta := (_pan_start - event.position) / zoom.x
		position += delta
		_pan_start = event.position
		get_viewport().set_input_as_handled()


func _zoom_in() -> void:
	_target_zoom = minf(_target_zoom + Config.CAMERA_ZOOM_STEP, Config.CAMERA_ZOOM_MAX)
	zoom = Vector2(_target_zoom, _target_zoom)


func _zoom_out() -> void:
	_target_zoom = maxf(_target_zoom - Config.CAMERA_ZOOM_STEP, Config.CAMERA_ZOOM_MIN)
	zoom = Vector2(_target_zoom, _target_zoom)
