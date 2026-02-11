class_name SocialGroup
extends RefCounted
## Emergent social group detected from relationship clustering.

var group_id: String = ""
var group_name: String = ""
var group_type: String = "social_circle"  # "family", "faction", "social_circle"
var members: Array[String] = []
var formed_day: int = 0
var average_affinity: float = 0.0
var cohesion: float = 0.0  # 0-100, how tightly bonded
var rival_groups: Array[String] = []  # group_ids


func to_dict() -> Dictionary:
	return {
		"group_id": group_id,
		"group_name": group_name,
		"group_type": group_type,
		"members": members.duplicate(),
		"formed_day": formed_day,
		"average_affinity": average_affinity,
		"cohesion": cohesion,
		"rival_groups": rival_groups.duplicate(),
	}


static func from_dict(data: Dictionary) -> SocialGroup:
	var group := SocialGroup.new()
	group.group_id = data.get("group_id", "")
	group.group_name = data.get("group_name", "")
	group.group_type = data.get("group_type", "social_circle")
	var raw_members: Array = data.get("members", [])
	for m in raw_members:
		group.members.append(str(m))
	group.formed_day = data.get("formed_day", 0)
	group.average_affinity = data.get("average_affinity", 0.0)
	group.cohesion = data.get("cohesion", 0.0)
	var raw_rivals: Array = data.get("rival_groups", [])
	for r in raw_rivals:
		group.rival_groups.append(str(r))
	return group


func get_summary() -> String:
	return "%s (%s, %d members)" % [group_name, group_type, members.size()]
