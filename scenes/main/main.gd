extends Node2D
## Root scene: desktop mode with transparent window, draggable, right-click menu.

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Enable transparent background
	get_viewport().transparent_bg = true
	var win := get_window()
	win.transparent = true
	win.borderless = true
	win.always_on_top = true
	win.mouse_passthrough = false
	EventBus.game_ready.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging the window
				_dragging = true
				_drag_offset = get_window().position - Vector2i(
					int(DisplayServer.mouse_get_position().x),
					int(DisplayServer.mouse_get_position().y)
				)
			else:
				_dragging = false
			# Deselect agent when clicking empty space
			EventBus.agent_deselected.emit()

	elif event is InputEventMouseMotion and _dragging:
		var mouse_pos := DisplayServer.mouse_get_position()
		get_window().position = Vector2i(
			int(mouse_pos.x) + int(_drag_offset.x),
			int(mouse_pos.y) + int(_drag_offset.y)
		)
