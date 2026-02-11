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

	# Create narrative log (bottom-left)
	_narrative_log = NarrativeLog.new()
	_narrative_log.offset_left = 10
	_narrative_log.offset_top = -160
	_narrative_log.offset_right = 210
	_narrative_log.offset_bottom = -25
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
	context_menu.add_item("Relationship Web", 7)
	context_menu.add_separator()
	context_menu.add_item("Reconnect LLM", 3)
	context_menu.add_item("Save Game", 10)
	context_menu.add_item("Load Game", 11)
	context_menu.add_item("Settings", 12)
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
		10: SaveManager.save_game()
		11: SaveManager.load_game()
		12: pass  # Settings menu (Phase 10)
		99: get_tree().quit()
