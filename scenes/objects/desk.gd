extends InteractableObject
## A desk where agents work to fulfill productivity needs.


func _ready() -> void:
	super._ready()
	object_type = "desk"
	display_name = "Desk"
	interaction_duration = 60.0  # 1 game hour of work
	max_occupants = 1
	_need_effects = {
		NeedType.Type.PRODUCTIVITY: 35.0,
		NeedType.Type.ENERGY: -5.0,
	}
	$Sprite2D.texture = SpriteFactory.create_desk_sprite()
