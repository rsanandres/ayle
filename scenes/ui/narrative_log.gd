class_name NarrativeLog
extends PanelContainer
## Scrollable log with tabbed Events / Stories view.

var _entries: Array[Dictionary] = []  # {text, agents, importance, timestamp, day}
var _vbox: VBoxContainer
var _scroll: ScrollContainer
var _tab_bar: HBoxContainer
var _events_btn: Button
var _stories_btn: Button
var _content_vbox: VBoxContainer
var _active_tab: String = "events"
const MAX_ENTRIES := 100


func _ready() -> void:
	custom_minimum_size = Vector2(200, 150)
	visible = false
	_build_ui()
	EventBus.narrative_event.connect(_on_narrative_event)


func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild_display()


func _build_ui() -> void:
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(outer)

	# Tab bar
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 2)
	outer.add_child(_tab_bar)

	_events_btn = Button.new()
	_events_btn.text = "Events"
	_events_btn.add_theme_font_size_override("font_size", 8)
	_events_btn.pressed.connect(_show_events_tab)
	_tab_bar.add_child(_events_btn)

	_stories_btn = Button.new()
	_stories_btn.text = "Stories"
	_stories_btn.add_theme_font_size_override("font_size", 8)
	_stories_btn.pressed.connect(_show_stories_tab)
	_tab_bar.add_child(_stories_btn)

	outer.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content_vbox)


func _show_events_tab() -> void:
	_active_tab = "events"
	_rebuild_display()


func _show_stories_tab() -> void:
	_active_tab = "stories"
	_rebuild_display()


func _on_narrative_event(text: String, agents: Array, importance: float) -> void:
	var entry := {
		"text": text,
		"agents": agents,
		"importance": importance,
		"timestamp": TimeManager.time_string,
		"day": TimeManager.day,
	}
	_entries.append(entry)
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	if visible and _active_tab == "events":
		_add_event_label(entry)
		_scroll.call_deferred("set_v_scroll", _scroll.get_v_scroll_bar().max_value as int)


func _rebuild_display() -> void:
	for child in _content_vbox.get_children():
		child.queue_free()

	if _active_tab == "events":
		_events_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		_stories_btn.remove_theme_color_override("font_color")
		for entry in _entries:
			_add_event_label(entry)
	else:
		_stories_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		_events_btn.remove_theme_color_override("font_color")
		_build_stories_view()


func _add_event_label(entry: Dictionary) -> void:
	var lbl := Label.new()
	lbl.text = "[Day %d %s] %s" % [entry["day"], entry["timestamp"], entry["text"]]
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var importance: float = entry["importance"]
	if importance >= 8.0:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	elif importance >= 5.0:
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	else:
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_content_vbox.add_child(lbl)


func _build_stories_view() -> void:
	var top: Array[Storyline] = Narrator.get_top_storylines(10)
	if top.is_empty():
		var empty := Label.new()
		empty.text = "No stories yet. Events need time to develop into narratives."
		empty.add_theme_font_size_override("font_size", 8)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content_vbox.add_child(empty)
		return

	for sl in top:
		var box := VBoxContainer.new()

		var title_lbl := Label.new()
		title_lbl.text = "%s [%.0f]" % [sl.title, sl.drama_score]
		title_lbl.add_theme_font_size_override("font_size", 8)
		if sl.drama_score >= 7.0:
			title_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
		elif sl.drama_score >= 4.0:
			title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		else:
			title_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		box.add_child(title_lbl)

		if sl.summary != "":
			var sum_lbl := Label.new()
			sum_lbl.text = sl.summary
			sum_lbl.add_theme_font_size_override("font_size", 7)
			sum_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(sum_lbl)

		var agents_lbl := Label.new()
		agents_lbl.text = ", ".join(sl.involved_agents)
		agents_lbl.add_theme_font_size_override("font_size", 7)
		agents_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
		box.add_child(agents_lbl)

		box.add_child(HSeparator.new())
		_content_vbox.add_child(box)


func get_entries() -> Array[Dictionary]:
	return _entries


func load_entries(entries: Array) -> void:
	_entries.clear()
	for e in entries:
		_entries.append(e)
