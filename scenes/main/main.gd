extends Node2D
## Root scene: desktop mode with transparent window, draggable, right-click menu.
## Supports expanded mode with camera pan/zoom for larger populations.

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var expanded_mode: bool = false
var _camera: Camera2D = null
var _camera_zoom: float = 1.0
var _camera_panning: bool = false
var _camera_pan_start: Vector2 = Vector2.ZERO
var _follow_agent: Node2D = null


func _ready() -> void:
	# Enable transparent background
	get_viewport().transparent_bg = true
	var win := get_window()
	win.transparent = true
	win.borderless = true
	win.always_on_top = true
	win.mouse_passthrough = false

	# Create camera for expanded mode
	_camera = Camera2D.new()
	_camera.enabled = false
	_camera.zoom = Vector2.ONE
	add_child(_camera)

	EventBus.game_ready.emit()
	EventBus.agent_selected.connect(_on_agent_selected_camera)

	# Try loading save on startup
	if SaveManager.has_save():
		call_deferred("_try_load_save")


func _try_load_save() -> void:
	SaveManager.load_game()


func set_expanded_mode(enable: bool) -> void:
	if expanded_mode == enable:
		return
	expanded_mode = enable
	var win := get_window()
	if enable:
		win.transparent = false
		get_viewport().transparent_bg = false
		win.borderless = false
		win.always_on_top = false
		win.size = Vector2i(Config.OFFICE_MAX_WIDTH, Config.OFFICE_MAX_HEIGHT)
		win.min_size = Vector2i(480, 320)
		_camera.enabled = true
		_camera.position = Vector2(Config.OFFICE_MAX_WIDTH / 2.0, Config.OFFICE_MAX_HEIGHT / 2.0)
		_camera_zoom = 1.0
		_camera.zoom = Vector2.ONE
		# Resize office for current agent count
		var world := get_tree().get_first_node_in_group("world")
		if world and world.has_method("resize_for_agents"):
			world.resize_for_agents(AgentManager.agents.size())
	else:
		win.transparent = true
		get_viewport().transparent_bg = true
		win.borderless = true
		win.always_on_top = true
		win.size = Vector2i(Config.DESKTOP_WINDOW_WIDTH, Config.DESKTOP_WINDOW_HEIGHT)
		_camera.enabled = false
		_follow_agent = null
		# Reset office to desktop size
		var world := get_tree().get_first_node_in_group("world")
		if world and world.has_method("resize_for_agents"):
			world.resize_for_agents(Config.MAX_AGENTS_DESKTOP)


func _process(_delta: float) -> void:
	if expanded_mode and _follow_agent and is_instance_valid(_follow_agent):
		_camera.position = _follow_agent.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if expanded_mode:
			_handle_expanded_input(event)
		else:
			_handle_desktop_input(event)

	elif event is InputEventMouseMotion:
		if expanded_mode and _camera_panning:
			_camera.position -= event.relative / _camera_zoom
			_follow_agent = null
		elif not expanded_mode and _dragging:
			var mouse_pos := DisplayServer.mouse_get_position()
			get_window().position = Vector2i(
				int(mouse_pos.x) + int(_drag_offset.x),
				int(mouse_pos.y) + int(_drag_offset.y)
			)


func _handle_desktop_input(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = get_window().position - Vector2i(
				int(DisplayServer.mouse_get_position().x),
				int(DisplayServer.mouse_get_position().y)
			)
		else:
			_dragging = false
		EventBus.agent_deselected.emit()


func _handle_expanded_input(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		EventBus.agent_deselected.emit()
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		_camera_panning = event.pressed
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_camera_zoom = clampf(_camera_zoom + 0.15, 0.5, 2.0)
		_camera.zoom = Vector2(_camera_zoom, _camera_zoom)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_camera_zoom = clampf(_camera_zoom - 0.15, 0.5, 2.0)
		_camera.zoom = Vector2(_camera_zoom, _camera_zoom)


func _on_agent_selected_camera(agent: Node2D) -> void:
	if expanded_mode:
		_follow_agent = agent
