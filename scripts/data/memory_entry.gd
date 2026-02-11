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
# Phase 3: Deep memory fields
var emotion: String = ""  # "happy", "sad", "angry", "grief", etc.
var sentiment: float = 0.0  # -1 to 1
var narrative_thread: String = ""  # e.g. "friendship_with_bob", "career_stress"
var decay_protected: bool = false  # landmark memories survive compaction


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
		"emotion": emotion,
		"sentiment": sentiment,
		"narrative_thread": narrative_thread,
		"decay_protected": decay_protected,
		"related_agents": Array(related_agents),
	}


static func from_dict(data: Dictionary) -> MemoryEntry:
	var entry := MemoryEntry.new(
		data.get("type", MemoryType.OBSERVATION),
		data.get("description", ""),
		data.get("timestamp", 0.0),
		data.get("importance", 1.0),
	)
	entry.emotion = data.get("emotion", "")
	entry.sentiment = data.get("sentiment", 0.0)
	entry.narrative_thread = data.get("narrative_thread", "")
	entry.decay_protected = data.get("decay_protected", false)
	var agents_raw: Array = data.get("related_agents", [])
	for a in agents_raw:
		entry.related_agents.append(str(a))
	return entry
