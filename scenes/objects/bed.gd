extends InteractableObject
## Bed: major energy restoration, long duration.


func _ready() -> void:
	super._ready()
	object_type = "bed"
	display_name = "Bed"
	interaction_duration = 60.0  # 1 game hour
	max_occupants = 1
	_need_effects = {
		NeedType.Type.ENERGY: 60.0,
	}
	$Sprite2D.texture = SpriteFactory.create_bed_sprite()
