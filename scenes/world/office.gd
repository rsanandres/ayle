extends Node2D
## The office world. Clean white room with subtle details.

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

	# Clean white floor
	draw_rect(floor_rect, Color(0.96, 0.96, 0.97, 0.95))

	# Subtle tile grid
	var grid_color := Color(0.88, 0.88, 0.9, 0.4)
	for x in range(int(_m), int(_m + _w) + 1, 16):
		draw_line(Vector2(x, _m), Vector2(x, _m + _h), grid_color, 1.0)
	for y in range(int(_m), int(_m + _h) + 1, 16):
		draw_line(Vector2(_m, y), Vector2(_m + _w, y), grid_color, 1.0)

	# Thin border
	draw_rect(floor_rect, Color(0.75, 0.75, 0.78, 0.8), false, 1.0)

	# Soft shadow along bottom and right edges (depth)
	draw_line(Vector2(_m, _m + _h), Vector2(_m + _w, _m + _h), Color(0.7, 0.7, 0.72, 0.5), 2.0)
	draw_line(Vector2(_m + _w, _m), Vector2(_m + _w, _m + _h), Color(0.7, 0.7, 0.72, 0.5), 2.0)
