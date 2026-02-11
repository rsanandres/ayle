class_name LifeStage

enum Type {
	YOUNG,
	ADULT,
	SENIOR,
	DYING,
	DEAD,
}

static func to_string_name(type: Type) -> String:
	match type:
		Type.YOUNG: return "young"
		Type.ADULT: return "adult"
		Type.SENIOR: return "senior"
		Type.DYING: return "dying"
		Type.DEAD: return "dead"
	return "unknown"
