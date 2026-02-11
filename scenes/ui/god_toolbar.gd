class_name GodToolbar
extends CanvasLayer
## God mode toolbar: object palette, agent controls, event triggers, inspect mode.

var _enabled: bool = false
var _toolbar: HBoxContainer
var _object_panel: VBoxContainer
var _agent_panel: VBoxContainer
var _event_panel: VBoxContainer
var _inspect_mode: bool = false
var _placing_object_type: String = ""
var _panel_bg: PanelContainer


func _ready() -> void:
	layer = 10
	_build_toolbar()
	_build_panels()
	visible = false
	EventBus.god_mode_toggled.connect(_on_god_mode_toggled)


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _placing_object_type != "" and event.position.y > 20:
			_place_object_at(event.position)
			get_viewport().set_input_as_handled()


func _on_god_mode_toggled(enabled: bool) -> void:
	_enabled = enabled
	visible = enabled
	if not enabled:
		_hide_all_panels()
		_placing_object_type = ""


func _build_toolbar() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar.offset_left = 10
	_toolbar.offset_top = 2
	_toolbar.offset_right = 470
	_toolbar.offset_bottom = 18
	_toolbar.add_theme_constant_override("separation", 4)
	add_child(_toolbar)

	_add_toolbar_button("Objects", _toggle_object_panel)
	_add_toolbar_button("Agents", _toggle_agent_panel)
	_add_toolbar_button("Events", _toggle_event_panel)
	_add_toolbar_button("Inspect", _toggle_inspect)

	# God mode label
	var lbl := Label.new()
	lbl.text = "GOD MODE"
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3, 0.9))
	_toolbar.add_child(lbl)


func _build_panels() -> void:
	_panel_bg = PanelContainer.new()
	_panel_bg.offset_left = 10
	_panel_bg.offset_top = 20
	_panel_bg.offset_right = 200
	_panel_bg.offset_bottom = 200
	_panel_bg.visible = false
	add_child(_panel_bg)

	var panel_vbox := VBoxContainer.new()
	_panel_bg.add_child(panel_vbox)

	_object_panel = VBoxContainer.new()
	_object_panel.visible = false
	panel_vbox.add_child(_object_panel)

	_agent_panel = VBoxContainer.new()
	_agent_panel.visible = false
	panel_vbox.add_child(_agent_panel)

	_event_panel = VBoxContainer.new()
	_event_panel.visible = false
	panel_vbox.add_child(_event_panel)


func _add_toolbar_button(text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(50, 14)
	btn.add_theme_font_size_override("font_size", 8)
	btn.pressed.connect(callback)
	_toolbar.add_child(btn)


func _toggle_object_panel() -> void:
	_hide_all_panels()
	_object_panel.visible = not _object_panel.visible
	_panel_bg.visible = _object_panel.visible
	if _object_panel.visible:
		_rebuild_object_panel()


func _toggle_agent_panel() -> void:
	_hide_all_panels()
	_agent_panel.visible = not _agent_panel.visible
	_panel_bg.visible = _agent_panel.visible
	if _agent_panel.visible:
		_rebuild_agent_panel()


func _toggle_event_panel() -> void:
	_hide_all_panels()
	_event_panel.visible = not _event_panel.visible
	_panel_bg.visible = _event_panel.visible
	if _event_panel.visible:
		_rebuild_event_panel()


func _toggle_inspect() -> void:
	_inspect_mode = not _inspect_mode
	_hide_all_panels()


func _hide_all_panels() -> void:
	_object_panel.visible = false
	_agent_panel.visible = false
	_event_panel.visible = false
	_panel_bg.visible = false


func _rebuild_object_panel() -> void:
	for child in _object_panel.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "Place Object"
	title.add_theme_font_size_override("font_size", 9)
	_object_panel.add_child(title)

	var types := ["desk", "couch", "coffee_machine", "water_cooler", "whiteboard", "bookshelf", "plant", "radio", "bed"]
	for t in types:
		var btn := Button.new()
		btn.text = t.replace("_", " ").capitalize()
		btn.add_theme_font_size_override("font_size", 8)
		btn.pressed.connect(_on_select_object_type.bind(t))
		_object_panel.add_child(btn)


func _rebuild_agent_panel() -> void:
	for child in _agent_panel.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "Agents"
	title.add_theme_font_size_override("font_size", 9)
	_agent_panel.add_child(title)

	# Spawn buttons for each personality
	var personalities := ["alice", "bob", "clara", "dave", "emma"]
	for p in personalities:
		var btn := Button.new()
		btn.text = "Spawn %s" % p.capitalize()
		btn.add_theme_font_size_override("font_size", 8)
		btn.pressed.connect(_on_spawn_agent.bind(p))
		_agent_panel.add_child(btn)

	# Remove buttons for existing agents
	var sep := HSeparator.new()
	_agent_panel.add_child(sep)
	for agent in AgentManager.agents:
		var btn := Button.new()
		btn.text = "Remove %s" % agent.agent_name
		btn.add_theme_font_size_override("font_size", 8)
		btn.pressed.connect(_on_remove_agent.bind(agent.agent_name))
		_agent_panel.add_child(btn)


func _rebuild_event_panel() -> void:
	for child in _event_panel.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "Trigger Event"
	title.add_theme_font_size_override("font_size", 9)
	_event_panel.add_child(title)

	var events := EventManager.get_available_events()
	for ev in events:
		var btn := Button.new()
		btn.text = ev.event_name
		btn.add_theme_font_size_override("font_size", 8)
		btn.tooltip_text = ev.description
		btn.pressed.connect(_on_trigger_event.bind(ev.event_id))
		_event_panel.add_child(btn)


func _on_select_object_type(obj_type: String) -> void:
	_placing_object_type = obj_type
	_hide_all_panels()


func _place_object_at(pos: Vector2) -> void:
	var world := get_tree().get_first_node_in_group("world")
	if not world:
		return
	var obj := _create_object(_placing_object_type)
	if obj:
		world.add_object(obj, pos)
	_placing_object_type = ""


func _create_object(obj_type: String) -> InteractableObject:
	# Create object based on type
	var script_path := "res://scenes/objects/%s.gd" % obj_type
	if not FileAccess.file_exists(script_path):
		return null
	var obj := StaticBody2D.new()
	obj.collision_layer = 4
	obj.collision_mask = 0
	var script := load(script_path)
	obj.set_script(script)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	obj.add_child(sprite)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(24, 16)
	shape.shape = rect_shape
	obj.add_child(shape)
	return obj


func _on_spawn_agent(personality_file: String) -> void:
	var spawn_pos := Vector2(randf_range(50, 400), randf_range(50, 250))
	AgentManager.spawn_agent(personality_file, spawn_pos)
	_hide_all_panels()


func _on_remove_agent(agent_name: String) -> void:
	AgentManager.remove_agent(agent_name)
	_hide_all_panels()


func _on_trigger_event(event_id: String) -> void:
	EventManager.trigger_event(event_id)
	_hide_all_panels()
