extends InteractableObject
## Whiteboard: productivity + social when multiple agents use it. Supports 3 occupants.


func _ready() -> void:
	super._ready()
	object_type = "whiteboard"
	display_name = "Whiteboard"
	interaction_duration = 45.0
	max_occupants = 3
	_need_effects = {
		NeedType.Type.PRODUCTIVITY: 20.0,
		NeedType.Type.SOCIAL: 10.0,
	}
	$Sprite2D.texture = SpriteFactory.create_whiteboard_sprite()


func get_need_effects() -> Dictionary:
	# Bonus effects when multiple people use it (meeting)
	var effects := _need_effects.duplicate()
	if _occupants.size() >= 2:
		effects[NeedType.Type.SOCIAL] = 20.0
		effects[NeedType.Type.PRODUCTIVITY] = 30.0
	return effects
