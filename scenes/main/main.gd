extends Node2D
## Root scene: starts in expanded mode (960x640) by default.
## Can shrink to desktop pet mode (480x320 transparent) via context menu.

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var expanded_mode: bool = true  # Default to expanded
var _camera: Camera2D = null
var _camera_zoom: float = 1.0
var _camera_panning: bool = false
var _follow_agent: Node2D = null


func _ready() -> void:
	var win := get_window()
	win.mouse_passthrough = false

	# Create camera
	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE
	add_child(_camera)

	# Start in expanded mode
	_setup_expanded_mode()

	EventBus.game_ready.emit()
	EventBus.agent_selected.connect(_on_agent_selected_camera)

	# Fade in from menu
	modulate.a = 0.0
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.5)

	# Game over overlay
	var game_over := GameOverOverlay.new()
	add_child(game_over)

	# Tutorial hint overlay
	var hint_overlay := HintOverlay.new()
	add_child(hint_overlay)

	# LLM loading overlay
	_setup_loading_overlay()

	# Auto-pause on focus loss
	get_window().focus_exited.connect(func() -> void:
		if SettingsManager.auto_pause_on_focus_loss and not TimeManager.is_paused:
			TimeManager.toggle_pause()
	)

	# Try loading save on startup (unless "New Sandbox" was chosen)
	if SaveManager.has_save() and not SaveManager.skip_auto_load:
		call_deferred("_try_load_save")
	SaveManager.skip_auto_load = false


func _try_load_save() -> void:
	var slot: int = SaveManager.current_slot
	SaveManager.load_game(slot)


func _setup_expanded_mode() -> void:
	var win := get_window()
	win.transparent = false
	get_viewport().transparent_bg = false
	win.borderless = false
	win.always_on_top = false
	win.min_size = Vector2i(480, 320)
	_camera.enabled = true
	# Center camera on the office
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("get_bounds"):
		var bounds: Rect2 = world.get_bounds()
		_camera.position = bounds.get_center()
	else:
		_camera.position = Vector2(480, 320)
	_camera_zoom = 1.0
	_camera.zoom = Vector2.ONE


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
		win.size = Vector2i(960, 640)
		win.min_size = Vector2i(480, 320)
		_camera.enabled = true
		var world := get_tree().get_first_node_in_group("world")
		if world and world.has_method("get_bounds"):
			_camera.position = world.get_bounds().get_center()
		_camera_zoom = 1.0
		_camera.zoom = Vector2.ONE
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
		var world := get_tree().get_first_node_in_group("world")
		if world and world.has_method("resize_for_agents"):
			world.resize_for_agents(Config.MAX_AGENTS_DESKTOP)


func _process(_delta: float) -> void:
	if expanded_mode and _follow_agent and is_instance_valid(_follow_agent):
		_camera.position = _follow_agent.global_position


func _unhandled_input(event: InputEvent) -> void:
	# Screenshot key (F12)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_take_screenshot()
		get_viewport().set_input_as_handled()
		return

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

	elif expanded_mode and event is InputEventMagnifyGesture:
		# macOS trackpad pinch-to-zoom
		_camera_zoom = clampf(_camera_zoom * event.factor, 0.5, 4.0)
		_camera.zoom = Vector2(_camera_zoom, _camera_zoom)

	elif expanded_mode and event is InputEventPanGesture:
		# macOS trackpad two-finger pan
		_camera.position += event.delta * (3.0 / _camera_zoom)
		_follow_agent = null


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
		_camera_zoom = clampf(_camera_zoom + 0.2, 0.5, 4.0)
		_camera.zoom = Vector2(_camera_zoom, _camera_zoom)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_camera_zoom = clampf(_camera_zoom - 0.2, 0.5, 4.0)
		_camera.zoom = Vector2(_camera_zoom, _camera_zoom)


func _on_agent_selected_camera(agent: Node2D) -> void:
	if expanded_mode:
		_follow_agent = agent


func _take_screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "user://screenshot_%s.png" % timestamp
	img.save_png(path)
	EventBus.narrative_event.emit("Screenshot saved.", [], 1.0)


func _setup_loading_overlay() -> void:
	# Show overlay while bundled LLM loads
	var overlay := CanvasLayer.new()
	overlay.layer = 95
	overlay.name = "LoadingOverlay"
	add_child(overlay)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08, 0.85)
	bg.visible = false
	overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)

	var lbl := Label.new()
	lbl.text = "Loading AI brain..."
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(lbl)

	# Show while model is loading
	LLMManager.model_loading.connect(func(is_loading: bool) -> void:
		if is_loading:
			bg.visible = true
			bg.modulate.a = 1.0
		else:
			# Fade out then remove
			var tween := create_tween()
			tween.tween_property(bg, "modulate:a", 0.0, 0.5)
			tween.tween_callback(func() -> void:
				overlay.queue_free()
			)
	)
