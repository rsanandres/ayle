class_name SaveSlotPicker
extends PanelContainer
## Save/load slot picker UI with 5 slots.

signal slot_selected(slot: int)

var _mode: String = "save"  # "save" or "load"
var _content: VBoxContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(220, 180)
	offset_left = -110
	offset_top = -90
	offset_right = 110
	offset_bottom = 90

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 3)
	add_child(_content)


func show_picker(mode: String) -> void:
	_mode = mode
	visible = true
	_rebuild()


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "Save Game" if _mode == "save" else "Load Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_content.add_child(title)

	for i in range(SaveManager.MAX_SLOTS):
		var info := SaveManager.get_slot_info(i)
		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 7)

		if info.get("exists", false):
			btn.text = "Slot %d - Day %d (%d agents) %s" % [
				i + 1, info.get("day", 0), info.get("agent_count", 0),
				str(info.get("save_time", "")).substr(0, 10)
			]
		else:
			btn.text = "Slot %d - Empty" % (i + 1)
			if _mode == "load":
				btn.disabled = true

		var slot := i
		btn.pressed.connect(func() -> void:
			slot_selected.emit(slot)
			if _mode == "save":
				SaveManager.save_game(slot)
			else:
				SaveManager.load_game(slot)
			visible = false
		)
		_content.add_child(btn)

	var close := Button.new()
	close.text = "Cancel"
	close.add_theme_font_size_override("font_size", 7)
	close.pressed.connect(func() -> void: visible = false)
	_content.add_child(close)
