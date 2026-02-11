extends CanvasLayer
## Minimal desktop HUD: status bar, agent tooltip on hover/click, right-click menu.

@onready var status_bar: HBoxContainer = $StatusBar
@onready var time_label: Label = $StatusBar/TimeLabel
@onready var speed_label: Label = $StatusBar/SpeedLabel
@onready var llm_label: Label = $StatusBar/LLMLabel
@onready var tooltip: PanelContainer = $Tooltip
@onready var tooltip_name: Label = $Tooltip/VBox/AgentName
@onready var tooltip_state: Label = $Tooltip/VBox/StateLabel
@onready var tooltip_thought: Label = $Tooltip/VBox/ThoughtLabel
@onready var tooltip_needs: VBoxContainer = $Tooltip/VBox/NeedsContainer
@onready var context_menu: PopupMenu = $ContextMenu

var _selected_agent: Node2D = null
var _need_bars: Dictionary = {}


func _ready() -> void:
	tooltip.visible = false
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.time_speed_changed.connect(_on_speed_changed)
	EventBus.agent_selected.connect(_on_agent_selected)
	EventBus.agent_deselected.connect(_on_agent_deselected)
	EventBus.agent_state_changed.connect(_on_agent_state_changed)
	EventBus.agent_need_changed.connect(_on_agent_need_changed)
	LLMManager.ollama_status_changed.connect(func(_a: bool) -> void: _update_llm_label())
	LLMManager.active_backend_changed.connect(func(_b: String) -> void: _update_llm_label())
	context_menu.id_pressed.connect(_on_context_menu)
	_update_time()
	_update_speed()
	_update_llm_label()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_show_context_menu(event.global_position)
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
	tooltip.visible = true
	tooltip_name.text = agent.agent_name
	if agent.personality:
		tooltip_name.text += " — " + agent.personality.get_personality_summary()
	_update_state_label()
	_update_thought()
	_rebuild_need_bars()


func _on_agent_deselected() -> void:
	_selected_agent = null
	tooltip.visible = false


func _on_agent_state_changed(agent: Node2D, _old: AgentState.Type, _new: AgentState.Type) -> void:
	if agent == _selected_agent:
		_update_state_label()


func _on_agent_need_changed(agent: Node2D, need: NeedType.Type, value: float) -> void:
	if agent == _selected_agent and _need_bars.has(need):
		_need_bars[need].value = value


func _update_state_label() -> void:
	if not _selected_agent:
		return
	var names := ["Idle", "Deciding", "Walking", "Interacting", "Talking"]
	var idx: int = _selected_agent.state
	tooltip_state.text = names[idx] if idx < names.size() else "?"
	if _selected_agent.current_target and idx == AgentState.Type.INTERACTING:
		tooltip_state.text += " (%s)" % _selected_agent.current_target.display_name


func _update_thought() -> void:
	if not _selected_agent:
		return
	var recent: Array[MemoryEntry] = _selected_agent.memory.get_recent(1)
	if not recent.is_empty():
		tooltip_thought.text = recent[0].description
	else:
		tooltip_thought.text = ""


func _rebuild_need_bars() -> void:
	for child in tooltip_needs.get_children():
		child.queue_free()
	_need_bars.clear()
	if not _selected_agent:
		return
	var data: Dictionary = _selected_agent.needs.get_all_values()
	for need in NeedType.get_all():
		var hbox := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = NeedType.to_string_name(need).substr(0, 3).capitalize()
		lbl.custom_minimum_size.x = 35
		lbl.add_theme_font_size_override("font_size", 10)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = Config.NEED_MAX
		bar.value = data.get(need, 0.0)
		bar.custom_minimum_size.x = 80
		bar.show_percentage = false
		hbox.add_child(lbl)
		hbox.add_child(bar)
		tooltip_needs.add_child(hbox)
		_need_bars[need] = bar


func _show_context_menu(pos: Vector2) -> void:
	context_menu.clear()
	context_menu.add_item("Pause / Resume", 0)
	context_menu.add_item("Speed Up", 1)
	context_menu.add_item("Speed Down", 2)
	context_menu.add_separator()
	context_menu.add_item("Reconnect LLM", 3)
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
		99: get_tree().quit()
