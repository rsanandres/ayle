extends Node2D
## The office world. Draws pixel art floor with warm cozy palette.

@onready var objects_container: Node2D = $Objects
@onready var agents_container: Node2D = $Agents

var _all_objects: Array[InteractableObject] = []
var _w: float = Config.DESKTOP_OFFICE_WIDTH
var _h: float = Config.DESKTOP_OFFICE_HEIGHT
var _m: float = 10.0  # margin


func _ready() -> void:
	add_to_group("world")
	_collect_objects()
	queue_redraw()


func get_all_objects() -> Array[InteractableObject]:
	return _all_objects


func _collect_objects() -> void:
	_all_objects.clear()
	for child in objects_container.get_children():
		if child is InteractableObject:
			_all_objects.append(child)


func _draw() -> void:
	var floor_rect := Rect2(_m, _m, _w, _h)

	# Main floor — dark warm tone with slight transparency
	draw_rect(floor_rect, Color(Palette.DARK_GRAY, 0.92))

	# Floor planks (horizontal lines, wood feel)
	for y in range(int(_m), int(_m + _h), 16):
		draw_line(
			Vector2(_m, y), Vector2(_m + _w, y),
			Color(Palette.WOOD_DARK, 0.15), 1.0
		)

	# Subtle vertical plank offsets every other row
	var row := 0
	for y in range(int(_m), int(_m + _h), 16):
		var offset := 8 if row % 2 == 1 else 0
		for x in range(int(_m) + offset, int(_m + _w), 32):
			draw_line(
				Vector2(x, y), Vector2(x, y + 16),
				Color(Palette.WOOD_DARK, 0.1), 1.0
			)
		row += 1

	# Wall — top
	draw_rect(Rect2(_m, _m, _w, 3), Color(Palette.WOOD_MID, 0.9))
	draw_line(Vector2(_m, _m + 3), Vector2(_m + _w, _m + 3), Color(Palette.WOOD_DARK, 0.6), 1.0)

	# Wall — left
	draw_rect(Rect2(_m, _m, 3, _h), Color(Palette.WOOD_MID, 0.9))

	# Baseboard — bottom
	draw_rect(Rect2(_m, _m + _h - 2, _w, 2), Color(Palette.WOOD_DARK, 0.5))

	# Border outline
	draw_rect(floor_rect, Color(Palette.OUTLINE, 0.8), false, 1.0)

	# Warm glow in center (ambient light spot)
	var center := Vector2(_m + _w / 2, _m + _h / 2)
	for r in range(60, 0, -5):
		var alpha := 0.02 * (1.0 - float(r) / 60.0)
		draw_circle(center, r, Color(Palette.WARM_YELLOW, alpha))
