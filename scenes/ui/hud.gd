extends CanvasLayer
## Heads-up display showing time, speed controls, and selected agent info.

@onready var time_label: Label = $TopBar/TimeLabel
@onready var speed_label: Label = $TopBar/SpeedLabel
@onready var day_label: Label = $TopBar/DayLabel
@onready var agent_panel: PanelContainer = $AgentPanel
@onready var agent_name_label: Label = $AgentPanel/VBox/AgentName
@onready var needs_container: VBoxContainer = $AgentPanel/VBox/NeedsContainer
@onready var state_label: Label = $AgentPanel/VBox/StateLabel

var _selected_agent: Node2D = null
var _need_bars: Dictionary = {}


func _ready() -> void:
	agent_panel.visible = false
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.time_speed_changed.connect(_on_speed_changed)
	EventBus.agent_selected.connect(_on_agent_selected)
	EventBus.agent_deselected.connect(_on_agent_deselected)
	EventBus.agent_state_changed.connect(_on_agent_state_changed)
	EventBus.agent_need_changed.connect(_on_agent_need_changed)
	_update_time_display()
	_update_speed_display()


func _on_time_tick(_game_minutes: float) -> void:
	_update_time_display()


func _on_speed_changed(_index: int) -> void:
	_update_speed_display()


func _update_time_display() -> void:
	time_label.text = TimeManager.time_string
	day_label.text = "Day %d" % TimeManager.day


func _update_speed_display() -> void:
	speed_label.text = TimeManager.SPEED_LABELS[TimeManager.speed_index]


func _on_agent_selected(agent: Node2D) -> void:
	_selected_agent = agent
	agent_panel.visible = true
	agent_name_label.text = agent.agent_name
	_rebuild_need_bars()
	_update_state_label()


func _on_agent_deselected() -> void:
	_selected_agent = null
	agent_panel.visible = false


func _on_agent_state_changed(agent: Node2D, _old: AgentState.Type, _new: AgentState.Type) -> void:
	if agent == _selected_agent:
		_update_state_label()


func _on_agent_need_changed(agent: Node2D, need: NeedType.Type, value: float) -> void:
	if agent == _selected_agent and _need_bars.has(need):
		_need_bars[need].value = value


func _update_state_label() -> void:
	if not _selected_agent:
		return
	var state_names := ["Idle", "Deciding", "Walking", "Interacting", "Talking"]
	var state_idx: int = _selected_agent.state
	state_label.text = state_names[state_idx] if state_idx < state_names.size() else "Unknown"
	if _selected_agent.current_target and _selected_agent.state == AgentState.Type.INTERACTING:
		state_label.text += " (%s)" % _selected_agent.current_target.display_name


func _on_pause_pressed() -> void:
	TimeManager.toggle_pause()


func _on_speed_up_pressed() -> void:
	TimeManager.increase_speed()


func _on_speed_down_pressed() -> void:
	TimeManager.decrease_speed()


func _rebuild_need_bars() -> void:
	for child in needs_container.get_children():
		child.queue_free()
	_need_bars.clear()
	if not _selected_agent:
		return
	var needs_data: Dictionary = _selected_agent.needs.get_all_values()
	for need in NeedType.get_all():
		var hbox := HBoxContainer.new()
		var label := Label.new()
		label.text = NeedType.to_string_name(need).capitalize()
		label.custom_minimum_size.x = 80
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = Config.NEED_MAX
		bar.value = needs_data.get(need, 0.0)
		bar.custom_minimum_size.x = 120
		bar.show_percentage = false
		hbox.add_child(label)
		hbox.add_child(bar)
		needs_container.add_child(hbox)
		_need_bars[need] = bar
