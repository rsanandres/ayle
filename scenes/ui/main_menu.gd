extends Control
## Main menu: title, new sandbox, continue, settings, quit.

var _settings_panel: Control = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _button_container: VBoxContainer = null
var _version_label: Label = null


func _ready() -> void:
	# Fill the screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Dark background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.12, 1.0)
	add_child(bg)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(200, 0)
	center.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "AYLE"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(_title_label)

	# Subtitle
	_subtitle_label = Label.new()
	_subtitle_label.text = "AI Agent Office Simulation"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 8)
	_subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(_subtitle_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	# Buttons
	_button_container = VBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_button_container)

	_add_button("New Sandbox", _on_new_sandbox)
	if SaveManager.has_save():
		_add_button("Continue", _on_continue)
	_add_button("Settings", _on_settings)
	_add_button("Quit", _on_quit)

	# Version label (bottom-right)
	_version_label = Label.new()
	_version_label.text = "v0.1.0"
	_version_label.add_theme_font_size_override("font_size", 6)
	_version_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	_version_label.anchor_left = 1.0
	_version_label.anchor_top = 1.0
	_version_label.anchor_right = 1.0
	_version_label.anchor_bottom = 1.0
	_version_label.offset_left = -60
	_version_label.offset_top = -14
	_version_label.offset_right = -4
	_version_label.offset_bottom = -2
	add_child(_version_label)

	# Create settings panel (hidden)
	_settings_panel = preload("res://scenes/ui/settings_panel.gd").new()
	_settings_panel.visible = false
	add_child(_settings_panel)


func _add_button(text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 24)
	btn.add_theme_font_size_override("font_size", 8)
	btn.pressed.connect(callback)
	_button_container.add_child(btn)


func _on_new_sandbox() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
	# Save will be loaded by main.gd _ready


func _on_settings() -> void:
	_settings_panel.visible = not _settings_panel.visible


func _on_quit() -> void:
	get_tree().quit()
