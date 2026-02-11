class_name StoryEntry
extends RefCounted
## Simple feed entry for the narrator's story feed.

var text: String = ""
var storyline_id: String = ""
var day: int = 0
var drama_level: float = 0.0  # 0-10


func to_dict() -> Dictionary:
	return {
		"text": text,
		"storyline_id": storyline_id,
		"day": day,
		"drama_level": drama_level,
	}


static func from_dict(data: Dictionary) -> StoryEntry:
	var entry := StoryEntry.new()
	entry.text = data.get("text", "")
	entry.storyline_id = data.get("storyline_id", "")
	entry.day = data.get("day", 0)
	entry.drama_level = data.get("drama_level", 0.0)
	return entry
