extends Camera2D
## Fixed camera centered on the desktop office.


func _ready() -> void:
	# Center on the office
	position = Vector2(Config.DESKTOP_OFFICE_WIDTH / 2.0 + 10, Config.DESKTOP_OFFICE_HEIGHT / 2.0 + 10)
	zoom = Vector2(1.0, 1.0)
