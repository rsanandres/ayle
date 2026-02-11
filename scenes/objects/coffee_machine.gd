extends InteractableObject
## Coffee machine that restores hunger and gives a small energy boost.


func _ready() -> void:
	super._ready()
	object_type = "coffee_machine"
	display_name = "Coffee Machine"
	interaction_duration = 5.0  # 5 game minutes
	max_occupants = 1
	_need_effects = {
		NeedType.Type.HUNGER: 25.0,
		NeedType.Type.ENERGY: 10.0,
	}
	$Sprite2D.texture = SpriteFactory.create_coffee_machine_sprite()
