extends Node2D
## Root scene: assembles the office world, camera, and UI.


func _ready() -> void:
	EventBus.game_ready.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Click on empty space to deselect agent
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Only deselect if we didn't click on an agent (handled by agent's ClickArea)
		EventBus.agent_deselected.emit()
