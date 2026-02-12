extends CanvasLayer
## Minimal desktop HUD: status bar, agent tooltip on hover/click, right-click menu.
## Integrates god mode toolbar, narrative log, relationship web, agent inspector.

@onready var status_bar: HBoxContainer = $StatusBar
@onready var time_label: Label = $StatusBar/TimeLabel
@onready var speed_label: Label = $StatusBar/SpeedLabel
@onready var llm_label: Label = $StatusBar/LLMLabel
@onready var context_menu: PopupMenu = $ContextMenu

var _selected_agent: Node2D = null
var _god_mode: bool = false
var _god_toolbar: GodToolbar
var _agent_inspector: AgentInspector
var _narrative_log: NarrativeLog
var _relationship_web: RelationshipWeb
var _story_feed: StoryFeedPanel
var _settings_panel: Control = null
var _achievement_panel: Control = null
var _save_picker: SaveSlotPicker = null


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.time_speed_changed.connect(_on_speed_changed)
	EventBus.agent_selected.connect(_on_agent_selected)
	EventBus.agent_deselected.connect(_on_agent_deselected)
	LLMManager.ollama_status_changed.connect(func(_a: bool) -> void: _update_llm_label())
	LLMManager.active_backend_changed.connect(func(_b: String) -> void: _update_llm_label())
	context_menu.id_pressed.connect(_on_context_menu)
	_update_time()
	_update_speed()
	_update_llm_label()

	# Create god mode toolbar
	_god_toolbar = GodToolbar.new()
	add_child(_god_toolbar)

	# Create agent inspector (right side)
	_agent_inspector = AgentInspector.new()
	_agent_inspector.offset_left = -180
	_agent_inspector.offset_top = 10
	_agent_inspector.offset_right = -10
	_agent_inspector.offset_bottom = 280
	_agent_inspector.anchors_preset = Control.PRESET_TOP_RIGHT
	_agent_inspector.anchor_left = 1.0
	_agent_inspector.anchor_right = 1.0
	_agent_inspector.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_agent_inspector)

	# Create narrative log (bottom-left, always visible)
	_narrative_log = NarrativeLog.new()
	_narrative_log.offset_left = 10
	_narrative_log.offset_top = -250
	_narrative_log.offset_right = 320
	_narrative_log.offset_bottom = -10
	_narrative_log.anchors_preset = Control.PRESET_BOTTOM_LEFT
	_narrative_log.anchor_top = 1.0
	_narrative_log.anchor_bottom = 1.0
	_narrative_log.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_narrative_log)

	# Create relationship web (center overlay)
	_relationship_web = RelationshipWeb.new()
	_relationship_web.offset_left = 100
	_relationship_web.offset_top = 30
	_relationship_web.offset_right = 380
	_relationship_web.offset_bottom = 270
	add_child(_relationship_web)

	# Create story feed panel (center-right)
	_story_feed = StoryFeedPanel.new()
	_story_feed.offset_left = 250
	_story_feed.offset_top = 30
	_story_feed.offset_right = 470
	_story_feed.offset_bottom = 270
	add_child(_story_feed)

	# Achievement toast listener
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_show_context_menu(event.global_position)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			_toggle_god_mode()
			get_viewport().set_input_as_handled()


func _on_time_tick(_gm: float) -> void:
	_update_time()


func _on_speed_changed(_i: int) -> void:
	_update_speed()


func _update_time() -> void:
	var agent_count := AgentManager.agents.size()
	if agent_count > Config.MAX_AGENTS_DESKTOP:
		time_label.text = "Day %d  %s  [%d agents]" % [TimeManager.day, TimeManager.time_string, agent_count]
	else:
		time_label.text = "Day %d  %s" % [TimeManager.day, TimeManager.time_string]


func _update_speed() -> void:
	speed_label.text = TimeManager.SPEED_LABELS[TimeManager.speed_index]


func _update_llm_label() -> void:
	llm_label.text = LLMManager.get_status_text()
	if LLMManager.is_available:
		llm_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	else:
		llm_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))


func _on_agent_selected(agent: Node2D) -> void:
	_selected_agent = agent


func _on_agent_deselected() -> void:
	_selected_agent = null


func _toggle_god_mode() -> void:
	_god_mode = not _god_mode
	EventBus.god_mode_toggled.emit(_god_mode)


func _show_context_menu(pos: Vector2) -> void:
	context_menu.clear()
	context_menu.add_item("Pause / Resume", 0)
	context_menu.add_item("Speed Up", 1)
	context_menu.add_item("Speed Down", 2)
	context_menu.add_separator()
	context_menu.add_item("Toggle God Mode (Tab)", 5)
	context_menu.add_item("Narrative Log", 6)
	context_menu.add_item("Story Feed", 8)
	context_menu.add_item("Relationship Web", 7)
	context_menu.add_separator()
	# Expanded mode toggle
	var main := get_tree().get_first_node_in_group("world")
	var root := get_tree().current_scene
	if root and root.has_method("set_expanded_mode"):
		if root.expanded_mode:
			context_menu.add_item("Shrink to Desktop Pet", 20)
		else:
			context_menu.add_item("Expand to Full Window", 20)
	context_menu.add_separator()
	context_menu.add_item("Reconnect LLM", 3)
	context_menu.add_item("Save Game", 10)
	context_menu.add_item("Load Game", 11)
	context_menu.add_separator()
	context_menu.add_item("Achievements", 13)
	context_menu.add_item("Settings", 12)
	context_menu.add_item("Return to Menu", 14)
	context_menu.add_separator()
	context_menu.add_item("Quit", 99)
	context_menu.position = Vector2i(int(pos.x), int(pos.y))
	context_menu.popup()


func _on_context_menu(id: int) -> void:
	match id:
		0: TimeManager.toggle_pause()
		1: TimeManager.increase_speed()
		2: TimeManager.decrease_speed()
		3: LLMManager.retry_health_check()
		5: _toggle_god_mode()
		6: _narrative_log.toggle()
		7: _relationship_web.toggle()
		8: _story_feed.toggle()
		10: _show_save_picker("save")
		11: _show_save_picker("load")
		12: _toggle_settings()
		13: _toggle_achievements()
		14: _return_to_menu()
		20:
			var root := get_tree().current_scene
			if root and root.has_method("set_expanded_mode"):
				root.set_expanded_mode(not root.expanded_mode)
		99: _confirm_quit()


func _confirm_quit() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Save and quit?"
	dialog.ok_button_text = "Quit"
	dialog.add_button("Save & Quit", true, "save_quit")
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		get_tree().quit()
	)
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == "save_quit":
			SaveManager.save_game()
		dialog.queue_free()
		get_tree().quit()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()


func _toggle_settings() -> void:
	if not _settings_panel:
		_settings_panel = preload("res://scenes/ui/settings_panel.gd").new()
		add_child(_settings_panel)
	_settings_panel.visible = not _settings_panel.visible


func _toggle_achievements() -> void:
	if not _achievement_panel:
		var panel_script := load("res://scenes/ui/achievement_panel.gd")
		if panel_script:
			_achievement_panel = panel_script.new()
			add_child(_achievement_panel)
	if _achievement_panel:
		_achievement_panel.visible = not _achievement_panel.visible


func _show_save_picker(mode: String) -> void:
	if not _save_picker:
		_save_picker = SaveSlotPicker.new()
		add_child(_save_picker)
	_save_picker.show_picker(mode)


func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_achievement_unlocked(_id: String, achievement_name: String) -> void:
	var toast := AchievementToast.new()
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.anchor_top = 0.0
	toast.offset_left = -80
	toast.offset_right = 80
	toast.offset_top = 4
	toast.offset_bottom = 24
	add_child(toast)
	toast.show_achievement(achievement_name)
