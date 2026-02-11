class_name RelationshipEntry
extends RefCounted
## Per-pair relationship data between two agents.

enum Status { NONE, CRUSHING, DATING, PARTNERS, EX }

var affinity: float = 0.0  # -100 to 100 (like/dislike)
var trust: float = 50.0  # 0 to 100
var familiarity: float = 0.0  # 0 to 100 (how well they know each other)
var romantic_interest: float = 0.0  # 0 to 100
var relationship_status: Status = Status.NONE
var tags: Array[String] = []  # "friend", "rival", "crush", etc.
var last_interaction_time: float = 0.0
var last_romantic_event_day: int = 0
var interaction_count: int = 0


func add_tag(tag: String) -> void:
	if tag not in tags:
		tags.append(tag)


func remove_tag(tag: String) -> void:
	tags.erase(tag)


func has_tag(tag: String) -> bool:
	return tag in tags


func get_summary() -> String:
	var parts: PackedStringArray = []
	if affinity > 50:
		parts.append("close friend")
	elif affinity > 20:
		parts.append("friendly")
	elif affinity < -50:
		parts.append("hostile")
	elif affinity < -20:
		parts.append("tense")
	else:
		parts.append("neutral")
	if trust > 70:
		parts.append("trusted")
	elif trust < 30:
		parts.append("distrusted")
	if romantic_interest > 50:
		parts.append("romantic feelings")
	match relationship_status:
		Status.CRUSHING: parts.append("has a crush")
		Status.DATING: parts.append("dating")
		Status.PARTNERS: parts.append("partners")
		Status.EX: parts.append("ex")
	if not tags.is_empty():
		parts.append("(%s)" % ", ".join(tags))
	return ", ".join(parts)


func to_dict() -> Dictionary:
	return {
		"affinity": affinity,
		"trust": trust,
		"familiarity": familiarity,
		"romantic_interest": romantic_interest,
		"relationship_status": relationship_status,
		"tags": tags.duplicate(),
		"last_interaction_time": last_interaction_time,
		"last_romantic_event_day": last_romantic_event_day,
		"interaction_count": interaction_count,
	}


static func from_dict(data: Dictionary) -> RelationshipEntry:
	var entry := RelationshipEntry.new()
	entry.affinity = data.get("affinity", 0.0)
	entry.trust = data.get("trust", 50.0)
	entry.familiarity = data.get("familiarity", 0.0)
	entry.romantic_interest = data.get("romantic_interest", 0.0)
	entry.relationship_status = data.get("relationship_status", Status.NONE)
	var raw_tags: Array = data.get("tags", [])
	for t in raw_tags:
		entry.tags.append(str(t))
	entry.last_interaction_time = data.get("last_interaction_time", 0.0)
	entry.last_romantic_event_day = data.get("last_romantic_event_day", 0)
	entry.interaction_count = data.get("interaction_count", 0)
	return entry
