class_name ErrorToast
extends PanelContainer
## Non-intrusive toast notification for errors and warnings.

var _label: Label = null


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.1, 0.1, 0.85)
	style.border_color = Color(0.8, 0.3, 0.3, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 7)
	_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.8))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


func show_error(text: String, duration: float = 5.0) -> void:
	_label.text = text
	modulate.a = 0.0
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_interval(duration)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: queue_free())


func show_warning(text: String, duration: float = 4.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.18, 0.08, 0.85)
	style.border_color = Color(0.8, 0.7, 0.2, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", style)
	_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	show_error(text, duration)
