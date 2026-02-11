extends InteractableObject
## Bookshelf: productivity boost, slight energy cost. Chance to trigger creative_breakthrough.


func _ready() -> void:
	super._ready()
	object_type = "bookshelf"
	display_name = "Bookshelf"
	interaction_duration = 30.0
	max_occupants = 1
	_need_effects = {
		NeedType.Type.PRODUCTIVITY: 15.0,
		NeedType.Type.ENERGY: -3.0,
	}
	$Sprite2D.texture = SpriteFactory.create_bookshelf_sprite()


func release(agent: Node2D) -> void:
	super.release(agent)
	# 15% chance to trigger creative breakthrough on release
	if randf() < 0.15:
		EventManager.trigger_event("creative_breakthrough", [agent])
