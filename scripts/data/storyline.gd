class_name Storyline
extends RefCounted
## A narrative thread curated by the Narrator from emergent events.

var title: String = ""
var involved_agents: Array[String] = []
var events: Array[Dictionary] = []  # {text, day, importance, timestamp}
var drama_score: float = 0.0  # 0-10
var category: String = "misc"  # romance, rivalry, career, tragedy, comedy
var summary: String = ""
var is_active: bool = true


func add_event(text: String, day: int, importance: float, timestamp: String = "") -> void:
	events.append({
		"text": text,
		"day": day,
		"importance": importance,
		"timestamp": timestamp,
	})
	recalculate_drama_score()


func recalculate_drama_score() -> void:
	if events.is_empty():
		drama_score = 0.0
		return

	# Base: sum of event importances, normalized
	var importance_sum: float = 0.0
	for ev in events:
		importance_sum += ev.get("importance", 1.0)
	drama_score = clampf(importance_sum / max(events.size(), 1), 0.0, 5.0)

	# Category bonuses
	match category:
		"romance": drama_score += 3.0
		"tragedy": drama_score += 5.0
		"rivalry": drama_score += 2.0
		"comedy": drama_score += 1.0

	# Bonus for confession events
	for ev in events:
		var text: String = ev.get("text", "")
		if "confess" in text.to_lower():
			drama_score += 4.0
			break
		if "died" in text.to_lower() or "passed away" in text.to_lower():
			drama_score += 5.0
			break

	# Agent count bonus (more agents = more interesting)
	drama_score += clampf(involved_agents.size() * 0.5, 0.0, 2.0)

	# Recency multiplier: recent events boost score
	if not events.is_empty():
		var latest_day: int = events[-1].get("day", 0)
		var age: int = TimeManager.day - latest_day
		if age > 10:
			drama_score *= 0.5
		elif age > 5:
			drama_score *= 0.7

	drama_score = clampf(drama_score, 0.0, 10.0)


func to_dict() -> Dictionary:
	return {
		"title": title,
		"involved_agents": involved_agents.duplicate(),
		"events": events.duplicate(true),
		"drama_score": drama_score,
		"category": category,
		"summary": summary,
		"is_active": is_active,
	}


static func from_dict(data: Dictionary) -> Storyline:
	var s := Storyline.new()
	s.title = data.get("title", "")
	var raw_agents: Array = data.get("involved_agents", [])
	for a in raw_agents:
		s.involved_agents.append(str(a))
	var raw_events: Array = data.get("events", [])
	for e in raw_events:
		s.events.append(e)
	s.drama_score = data.get("drama_score", 0.0)
	s.category = data.get("category", "misc")
	s.summary = data.get("summary", "")
	s.is_active = data.get("is_active", true)
	return s
