class_name AgentInspector
extends PanelContainer
## Detailed agent inspection panel showing needs, personality, memory, relationships, health.

var _agent: Node2D = null
var _vbox: VBoxContainer
var _name_label: Label
var _personality_label: Label
var _state_label: Label
var _health_label: Label
var _needs_container: VBoxContainer
var _relationships_label: Label
var _memory_label: Label
var _need_bars: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(170, 250)
	_build_ui()
	visible = false
	EventBus.agent_selected.connect(_on_agent_selected)
	EventBus.agent_deselected.connect(_on_agent_deselected)
	EventBus.agent_need_changed.connect(_on_need_changed)
	EventBus.agent_state_changed.connect(_on_state_changed)


func _process(_delta: float) -> void:
	if visible and _agent and is_instance_valid(_agent):
		_update_dynamic()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 11)
	_vbox.add_child(_name_label)

	_personality_label = Label.new()
	_personality_label.add_theme_font_size_override("font_size", 8)
	_personality_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_personality_label)

	_state_label = Label.new()
	_state_label.add_theme_font_size_override("font_size", 9)
	_state_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	_vbox.add_child(_state_label)

	_health_label = Label.new()
	_health_label.add_theme_font_size_override("font_size", 9)
	_vbox.add_child(_health_label)

	var needs_title := Label.new()
	needs_title.text = "Needs"
	needs_title.add_theme_font_size_override("font_size", 9)
	_vbox.add_child(needs_title)

	_needs_container = VBoxContainer.new()
	_vbox.add_child(_needs_container)

	_vbox.add_child(HSeparator.new())

	var rel_title := Label.new()
	rel_title.text = "Relationships"
	rel_title.add_theme_font_size_override("font_size", 9)
	_vbox.add_child(rel_title)

	_relationships_label = Label.new()
	_relationships_label.add_theme_font_size_override("font_size", 8)
	_relationships_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_relationships_label)

	_vbox.add_child(HSeparator.new())

	var mem_title := Label.new()
	mem_title.text = "Recent Memories"
	mem_title.add_theme_font_size_override("font_size", 9)
	_vbox.add_child(mem_title)

	_memory_label = Label.new()
	_memory_label.add_theme_font_size_override("font_size", 7)
	_memory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_memory_label)


func _on_agent_selected(agent: Node2D) -> void:
	_agent = agent
	visible = true
	_update_static()
	_rebuild_need_bars()
	_update_dynamic()


func _on_agent_deselected() -> void:
	_agent = null
	visible = false


func _on_need_changed(agent: Node2D, need: NeedType.Type, value: float) -> void:
	if agent == _agent and _need_bars.has(need):
		_need_bars[need].value = value


func _on_state_changed(agent: Node2D, _old: AgentState.Type, _new: AgentState.Type) -> void:
	if agent == _agent:
		_update_state()


func _update_static() -> void:
	if not _agent:
		return
	_name_label.text = _agent.agent_name
	if _agent.personality:
		_personality_label.text = _agent.personality.get_personality_summary()
	else:
		_personality_label.text = ""
	_update_state()


func _update_state() -> void:
	if not _agent:
		return
	var names := ["Idle", "Deciding", "Walking", "Interacting", "Talking"]
	var idx: int = _agent.state
	_state_label.text = names[idx] if idx < names.size() else "?"


func _update_dynamic() -> void:
	if not _agent or not is_instance_valid(_agent):
		return
	# Health
	if _agent.health_state:
		var hs: HealthState = _agent.health_state
		_health_label.text = "Age: Day %d | Health: %.0f | %s" % [
			hs.age_days, hs.health, LifeStage.to_string_name(hs.life_stage)
		]
		if not hs.conditions.is_empty():
			_health_label.text += " | " + ", ".join(hs.conditions)
	else:
		_health_label.text = ""
	# Relationships
	if _agent.relationships:
		_relationships_label.text = _agent.relationships.get_all_as_summary()
	# Memory
	var recent: Array[MemoryEntry] = _agent.memory.get_recent(5)
	_memory_label.text = _agent.memory.format_memories_for_prompt(recent)


func _rebuild_need_bars() -> void:
	for child in _needs_container.get_children():
		child.queue_free()
	_need_bars.clear()
	if not _agent:
		return
	var data: Dictionary = _agent.needs.get_all_values()
	for need in NeedType.get_all():
		var hbox := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = NeedType.to_string_name(need).substr(0, 4).capitalize()
		lbl.custom_minimum_size.x = 35
		lbl.add_theme_font_size_override("font_size", 8)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = Config.NEED_MAX
		bar.value = data.get(need, 0.0)
		bar.custom_minimum_size = Vector2(80, 10)
		bar.show_percentage = false
		hbox.add_child(lbl)
		hbox.add_child(bar)
		_needs_container.add_child(hbox)
		_need_bars[need] = bar
