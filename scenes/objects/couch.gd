extends InteractableObject
## A couch where agents rest to restore energy.


func _ready() -> void:
	super._ready()
	object_type = "couch"
	display_name = "Couch"
	interaction_duration = 30.0  # 30 game minutes of rest
	max_occupants = 1
	_need_effects = {
		NeedType.Type.ENERGY: 40.0,
		NeedType.Type.PRODUCTIVITY: -3.0,
	}
	$Sprite2D.texture = SpriteFactory.create_couch_sprite()
