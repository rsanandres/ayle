extends InteractableObject
## Water cooler: social hotspot. Supports 2 occupants — triggers conversation if both occupied.


func _ready() -> void:
	super._ready()
	object_type = "water_cooler"
	display_name = "Water Cooler"
	interaction_duration = 10.0
	max_occupants = 2
	_need_effects = {
		NeedType.Type.HUNGER: 10.0,
		NeedType.Type.SOCIAL: 20.0,
	}
	$Sprite2D.texture = SpriteFactory.create_water_cooler_sprite()


func occupy(agent: Node2D) -> void:
	super.occupy(agent)
	# If 2 occupants, trigger a conversation between them
	if _occupants.size() == 2:
		var a: Node2D = _occupants[0]
		var b: Node2D = _occupants[1]
		# Defer to avoid conflicts during interaction processing
		call_deferred("_trigger_water_cooler_chat", a, b)


func _trigger_water_cooler_chat(a: Node2D, b: Node2D) -> void:
	if is_instance_valid(a) and is_instance_valid(b):
		ConversationManager.start_conversation(a, b)
