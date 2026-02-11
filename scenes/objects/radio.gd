extends InteractableObject
## Radio: passive area effect, social boost for all agents within radius. Toggleable.

var _playing: bool = true


func _ready() -> void:
	super._ready()
	object_type = "radio"
	display_name = "Radio"
	interaction_duration = 5.0  # Quick toggle
	max_occupants = 1
	passive_effect_radius = 80.0
	passive_need_effects = {
		NeedType.Type.SOCIAL: 0.5,
	}
	_need_effects = {}  # Toggling doesn't give direct effects
	$Sprite2D.texture = SpriteFactory.create_radio_sprite()


func release(agent: Node2D) -> void:
	super.release(agent)
	_playing = not _playing
	if _playing:
		passive_need_effects = {NeedType.Type.SOCIAL: 0.5}
	else:
		passive_need_effects = {}
