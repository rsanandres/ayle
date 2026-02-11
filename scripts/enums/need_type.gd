class_name NeedType

enum Type {
	ENERGY,
	HUNGER,
	SOCIAL,
	PRODUCTIVITY,
	HEALTH,
}

static func get_all() -> Array[Type]:
	return [Type.ENERGY, Type.HUNGER, Type.SOCIAL, Type.PRODUCTIVITY, Type.HEALTH]

static func get_core() -> Array[Type]:
	## Returns just the original 4 needs (excludes HEALTH for backward compat).
	return [Type.ENERGY, Type.HUNGER, Type.SOCIAL, Type.PRODUCTIVITY]

static func to_string_name(type: Type) -> String:
	match type:
		Type.ENERGY: return "energy"
		Type.HUNGER: return "hunger"
		Type.SOCIAL: return "social"
		Type.PRODUCTIVITY: return "productivity"
		Type.HEALTH: return "health"
	return "unknown"
