extends PanelContainer
## Grid viewer showing all achievements and unlock status.

var _content: VBoxContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(260, 200)
	offset_left = -130
	offset_top = -100
	offset_right = 130
	offset_bottom = 100

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style.border_color = Color(0.4, 0.35, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 2)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

	_rebuild()
	EventBus.achievement_unlocked.connect(func(_id: String, _name: String) -> void:
		_rebuild()
	)


func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()

	# Title
	var title := Label.new()
	title.text = "Achievements (%d/%d)" % [AchievementManager.get_unlocked_count(), AchievementManager.get_total_count()]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	_content.add_child(title)

	var sep := HSeparator.new()
	_content.add_child(sep)

	var all := AchievementManager.get_all()
	for a in all:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_content.add_child(row)

		var icon := Label.new()
		icon.text = "[x]" if a["unlocked"] else "[ ]"
		icon.add_theme_font_size_override("font_size", 9)
		icon.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3) if a["unlocked"] else Color(0.4, 0.4, 0.45))
		icon.custom_minimum_size = Vector2(20, 0)
		row.add_child(icon)

		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		row.add_child(info)

		var name_lbl := Label.new()
		name_lbl.text = a["name"]
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9) if a["unlocked"] else Color(0.5, 0.5, 0.55))
		info.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = a["description"]
		desc_lbl.add_theme_font_size_override("font_size", 9)
		desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		info.add_child(desc_lbl)

	# Close button
	var close := Button.new()
	close.text = "Close"
	close.add_theme_font_size_override("font_size", 9)
	close.pressed.connect(func() -> void: visible = false)
	_content.add_child(close)
