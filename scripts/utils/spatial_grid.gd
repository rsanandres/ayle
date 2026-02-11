class_name SpatialGrid
extends RefCounted
## Cell-based spatial hash for O(1) proximity queries.

var _cell_size: float
var _cells: Dictionary = {}  # Vector2i -> Array[Node2D]
var _agent_cells: Dictionary = {}  # Node2D -> Vector2i


func _init(cell_size: float = 64.0) -> void:
	_cell_size = cell_size


func clear() -> void:
	_cells.clear()
	_agent_cells.clear()


func update_agent(agent: Node2D) -> void:
	var new_cell := _pos_to_cell(agent.global_position)
	if _agent_cells.has(agent):
		var old_cell: Vector2i = _agent_cells[agent]
		if old_cell == new_cell:
			return
		# Remove from old cell
		if _cells.has(old_cell):
			var arr: Array = _cells[old_cell]
			arr.erase(agent)
			if arr.is_empty():
				_cells.erase(old_cell)
	# Add to new cell
	if not _cells.has(new_cell):
		_cells[new_cell] = []
	_cells[new_cell].append(agent)
	_agent_cells[agent] = new_cell


func remove_agent(agent: Node2D) -> void:
	if _agent_cells.has(agent):
		var cell: Vector2i = _agent_cells[agent]
		if _cells.has(cell):
			var arr: Array = _cells[cell]
			arr.erase(agent)
			if arr.is_empty():
				_cells.erase(cell)
		_agent_cells.erase(agent)


func get_agents_in_radius(position: Vector2, radius: float, exclude: Node2D = null) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var radius_sq := radius * radius
	var min_cell := _pos_to_cell(position - Vector2(radius, radius))
	var max_cell := _pos_to_cell(position + Vector2(radius, radius))

	for cx in range(min_cell.x, max_cell.x + 1):
		for cy in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(cx, cy)
			if not _cells.has(cell):
				continue
			var agents: Array = _cells[cell]
			for agent in agents:
				if agent == exclude:
					continue
				if not is_instance_valid(agent):
					continue
				if agent.global_position.distance_squared_to(position) <= radius_sq:
					result.append(agent)
	return result


func rebuild(agents: Array[Node2D]) -> void:
	clear()
	for agent in agents:
		if is_instance_valid(agent):
			update_agent(agent)


func _pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / _cell_size)), int(floor(pos.y / _cell_size)))
