extends Node
## Top-level game state management.

var selected_agent: Node2D = null


func _ready() -> void:
	EventBus.agent_selected.connect(_on_agent_selected)
	EventBus.agent_deselected.connect(_on_agent_deselected)


func _on_agent_selected(agent: Node2D) -> void:
	selected_agent = agent


func _on_agent_deselected() -> void:
	selected_agent = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		TimeManager.toggle_pause()
	elif event.is_action_pressed("speed_up"):
		TimeManager.increase_speed()
	elif event.is_action_pressed("speed_down"):
		TimeManager.decrease_speed()
