class_name HintOverlay
extends CanvasLayer
## Pixel-art styled hint popup that appears at the top of the screen.

var _panel: PanelContainer = null
var _label: Label = null
var _dismiss_btn: Button = null
var _dont_show_btn: Button = null


func _ready() -> void:
	layer = 90

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -140
	_panel.offset_right = 140
	_panel.offset_top = 20
	_panel.offset_bottom = 60
	_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.2, 0.92)
	style.border_color = Color(0.4, 0.6, 0.8, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 9)
	_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(260, 0)
	vbox.add_child(_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	_dismiss_btn = Button.new()
	_dismiss_btn.text = "Got it"
	_dismiss_btn.add_theme_font_size_override("font_size", 9)
	_dismiss_btn.pressed.connect(_dismiss)
	btn_row.add_child(_dismiss_btn)

	_dont_show_btn = Button.new()
	_dont_show_btn.text = "Don't show again"
	_dont_show_btn.add_theme_font_size_override("font_size", 9)
	_dont_show_btn.pressed.connect(func() -> void:
		TutorialManager.dismiss_all()
		_dismiss()
	)
	btn_row.add_child(_dont_show_btn)

	# Connect to tutorial manager
	TutorialManager.hint_triggered.connect(_on_hint)


func _on_hint(_id: String, text: String) -> void:
	_label.text = text
	_panel.visible = true
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.3)


func _dismiss() -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: _panel.visible = false)
