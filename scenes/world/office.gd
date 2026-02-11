extends Node2D
## The office world. Holds tilemap, navigation, and interactable objects.

@onready var objects_container: Node2D = $Objects
@onready var agents_container: Node2D = $Agents

var _all_objects: Array[InteractableObject] = []


func _ready() -> void:
	add_to_group("world")
	_collect_objects()
	_draw_floor()


func get_all_objects() -> Array[InteractableObject]:
	return _all_objects


func _collect_objects() -> void:
	_all_objects.clear()
	for child in objects_container.get_children():
		if child is InteractableObject:
			_all_objects.append(child)


func _draw_floor() -> void:
	# Floor will be drawn by the TileMapLayer or a simple ColorRect
	queue_redraw()


func _draw() -> void:
	# Draw a simple office floor
	var floor_color := Color(0.85, 0.82, 0.75)
	var wall_color := Color(0.45, 0.42, 0.38)
	var floor_rect := Rect2(0, 0, 320, 240)

	# Floor
	draw_rect(floor_rect, floor_color)

	# Walls (4px thick borders)
	draw_rect(Rect2(0, 0, 320, 4), wall_color)        # top
	draw_rect(Rect2(0, 236, 320, 4), wall_color)       # bottom
	draw_rect(Rect2(0, 0, 4, 240), wall_color)         # left
	draw_rect(Rect2(316, 0, 4, 240), wall_color)       # right

	# Some floor details - tile grid lines
	var line_color := Color(0.8, 0.77, 0.7)
	for x in range(0, 321, 16):
		draw_line(Vector2(x, 4), Vector2(x, 236), line_color, 1.0)
	for y in range(0, 241, 16):
		draw_line(Vector2(4, y), Vector2(316, y), line_color, 1.0)
