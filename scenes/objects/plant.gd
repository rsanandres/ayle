extends InteractableObject
## Decorative plant: passive mood boost for nearby agents.


func _ready() -> void:
	super._ready()
	object_type = "plant"
	display_name = "Plant"
	interaction_duration = 0.0  # Not directly interactable
	max_occupants = 0
	passive_effect_radius = 60.0
	passive_need_effects = {
		NeedType.Type.SOCIAL: 0.3,
	}
	$Sprite2D.texture = SpriteFactory.create_plant_sprite()


func is_available() -> bool:
	return false  # Can't be directly used
