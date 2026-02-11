class_name RelationshipWeb
extends Control
## Visual graph showing agents as nodes and relationship lines between them.

var _visible_flag: bool = false


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(200, 150)


func toggle() -> void:
	_visible_flag = not _visible_flag
	visible = _visible_flag
	if visible:
		queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return

	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.15, 0.9))

	var agents := AgentManager.agents
	if agents.is_empty():
		return

	# Position agents in a circle
	var center := size / 2.0
	var radius := minf(size.x, size.y) * 0.35
	var positions: Dictionary = {}

	for i in range(agents.size()):
		var angle := (TAU / agents.size()) * i - PI / 2.0
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		positions[agents[i].agent_name] = pos

	# Draw relationship lines
	for agent in agents:
		if not agent.relationships:
			continue
		var rels := agent.relationships.get_all_relationships()
		for other_name in rels:
			if not positions.has(other_name):
				continue
			var rel: RelationshipEntry = rels[other_name]
			if rel.familiarity < 5.0:
				continue  # Don't show non-relationships

			var from_pos: Vector2 = positions[agent.agent_name]
			var to_pos: Vector2 = positions[other_name]

			# Line color based on relationship type
			var line_color: Color
			if rel.relationship_status == RelationshipEntry.Status.DATING or rel.relationship_status == RelationshipEntry.Status.PARTNERS:
				line_color = Color(1.0, 0.5, 0.7, 0.8)  # Pink for romance
			elif rel.affinity > 30:
				line_color = Color(0.3, 0.8, 0.3, 0.6)  # Green for friends
			elif rel.affinity < -30:
				line_color = Color(0.8, 0.3, 0.3, 0.6)  # Red for rivals
			else:
				line_color = Color(0.5, 0.5, 0.5, 0.3)  # Gray for neutral

			# Line thickness based on familiarity
			var thickness := clampf(rel.familiarity / 30.0, 1.0, 3.0)
			draw_line(from_pos, to_pos, line_color, thickness)

	# Draw agent nodes
	for agent in agents:
		var pos: Vector2 = positions[agent.agent_name]
		draw_circle(pos, 8.0, agent.agent_color)
		draw_circle(pos, 8.0, Palette.OUTLINE, false, 1.0)

		# Name label
		var font := ThemeDB.fallback_font
		var font_size := 8
		var text_size := font.get_string_size(agent.agent_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, pos - Vector2(text_size.x / 2.0, -14.0), agent.agent_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
