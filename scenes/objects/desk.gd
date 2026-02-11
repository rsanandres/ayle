extends InteractableObject
## A desk where agents work to fulfill productivity needs.


func _ready() -> void:
	object_type = "desk"
	display_name = "Desk"
	interaction_duration = 60.0  # 1 game hour of work
	_need_effects = {
		NeedType.Type.PRODUCTIVITY: 35.0,
		NeedType.Type.ENERGY: -5.0,
	}
	$Sprite2D.texture = SpriteFactory.create_desk_sprite()
