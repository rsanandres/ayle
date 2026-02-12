class_name AchievementToast
extends PanelContainer
## Pop-up toast shown when an achievement unlocks.

var _label: Label = null


func _ready() -> void:
	# Style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.08, 0.9)
	style.border_color = Color(0.9, 0.75, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 7)
	_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


func show_achievement(achievement_name: String) -> void:
	_label.text = "Achievement: %s" % achievement_name
	modulate.a = 0.0
	visible = true

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_interval(3.0)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: queue_free())
