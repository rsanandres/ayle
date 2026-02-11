class_name MemoryEntry
extends RefCounted
## A single memory in an agent's memory stream.

enum MemoryType { OBSERVATION, CONVERSATION, REFLECTION, ACTION }

var type: MemoryType
var description: String
var timestamp: float  # game_minutes when created
var importance: float  # 1-10
var keywords: PackedStringArray
var related_agents: PackedStringArray


func _init(p_type: MemoryType = MemoryType.OBSERVATION, p_desc: String = "", p_time: float = 0.0, p_importance: float = 1.0) -> void:
	type = p_type
	description = p_desc
	timestamp = p_time
	importance = p_importance
	keywords = _extract_keywords(p_desc)


func _extract_keywords(text: String) -> PackedStringArray:
	var words := text.to_lower().split(" ", false)
	var stop_words := ["the", "a", "an", "is", "was", "are", "to", "and", "of", "in", "at", "for", "on", "with", "i", "my", "that", "this"]
	var result: PackedStringArray = []
	for word in words:
		var clean := word.strip_edges().trim_suffix(".").trim_suffix(",").trim_suffix("!")
		if clean.length() > 2 and clean not in stop_words and clean not in result:
			result.append(clean)
	return result


func to_dict() -> Dictionary:
	return {
		"type": type,
		"description": description,
		"timestamp": timestamp,
		"importance": importance,
	}
