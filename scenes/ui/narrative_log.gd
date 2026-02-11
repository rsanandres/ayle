class_name NarrativeLog
extends PanelContainer
## Scrollable log of significant events with timestamps.

var _entries: Array[Dictionary] = []  # {text, agents, importance, timestamp, day}
var _vbox: VBoxContainer
var _scroll: ScrollContainer
var _title: Label
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
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(outer)

	_title = Label.new()
	_title.text = "Narrative Log"
	_title.add_theme_font_size_override("font_size", 10)
	_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	outer.add_child(_title)

	outer.add_child(HSeparator.new())

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(_vbox)


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
	if visible:
		_add_entry_label(entry)
		# Auto-scroll to bottom
		_scroll.call_deferred("set_v_scroll", _scroll.get_v_scroll_bar().max_value as int)


func _rebuild_display() -> void:
	for child in _vbox.get_children():
		child.queue_free()
	for entry in _entries:
		_add_entry_label(entry)


func _add_entry_label(entry: Dictionary) -> void:
	var lbl := Label.new()
	lbl.text = "[Day %d %s] %s" % [entry["day"], entry["timestamp"], entry["text"]]
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Color by importance
	var importance: float = entry["importance"]
	if importance >= 8.0:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	elif importance >= 5.0:
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	else:
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_vbox.add_child(lbl)


func get_entries() -> Array[Dictionary]:
	return _entries


func load_entries(entries: Array) -> void:
	_entries.clear()
	for e in entries:
		_entries.append(e)
