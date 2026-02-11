class_name AgentMemory
extends Node
## Per-agent memory stream with retrieval scoring and reflection triggers.

const MAX_MEMORIES := 200
const REFLECTION_IMPORTANCE_THRESHOLD := 50.0
const COMPACTION_BATCH := 50

var memories: Array[MemoryEntry] = []
var _importance_accumulator: float = 0.0
var _agent_name: String = ""
var _is_reflecting: bool = false


func setup(agent_name: String) -> void:
	_agent_name = agent_name


func add_memory(type: MemoryEntry.MemoryType, description: String, importance: float = 3.0, related_agents: PackedStringArray = []) -> void:
	var entry := MemoryEntry.new(type, description, TimeManager.game_minutes, importance)
	entry.related_agents = related_agents
	memories.append(entry)
	_importance_accumulator += importance

	# Trigger reflection if accumulated importance is high enough
	if _importance_accumulator >= REFLECTION_IMPORTANCE_THRESHOLD and not _is_reflecting:
		_trigger_reflection()

	# Compact if too many memories
	if memories.size() > MAX_MEMORIES:
		_compact()


func add_observation(description: String, importance: float = 2.0) -> void:
	add_memory(MemoryEntry.MemoryType.OBSERVATION, description, importance)


func add_action(description: String, importance: float = 3.0) -> void:
	add_memory(MemoryEntry.MemoryType.ACTION, description, importance)


func add_conversation(description: String, related_agent: String, importance: float = 5.0) -> void:
	add_memory(MemoryEntry.MemoryType.CONVERSATION, description, importance, PackedStringArray([related_agent]))


func add_reflection(description: String) -> void:
	add_memory(MemoryEntry.MemoryType.REFLECTION, description, 8.0)


func retrieve(query: String, count: int = 5) -> Array[MemoryEntry]:
	if memories.is_empty():
		return []
	var query_keywords := _extract_keywords(query)
	var scored: Array[Dictionary] = []
	var current_time := TimeManager.game_minutes

	for mem in memories:
		var score := _score_memory(mem, query_keywords, current_time)
		scored.append({"memory": mem, "score": score})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])

	var result: Array[MemoryEntry] = []
	var limit := mini(count, scored.size())
	for i in range(limit):
		result.append(scored[i]["memory"])
	return result


func get_recent(count: int = 10) -> Array[MemoryEntry]:
	var start := maxi(0, memories.size() - count)
	var result: Array[MemoryEntry] = []
	for i in range(start, memories.size()):
		result.append(memories[i])
	return result


func format_memories_for_prompt(mems: Array[MemoryEntry]) -> String:
	if mems.is_empty():
		return "(no memories yet)"
	var lines: PackedStringArray = []
	for mem in mems:
		var time_str := "%02d:%02d" % [int(mem.timestamp / 60.0) % 24, int(mem.timestamp) % 60]
		lines.append("- [%s] %s" % [time_str, mem.description])
	return "\n".join(lines)


func _score_memory(mem: MemoryEntry, query_keywords: PackedStringArray, current_time: float) -> float:
	# Recency: exponential decay, half-life of 120 game minutes
	var age := maxf(current_time - mem.timestamp, 0.0)
	var recency := exp(-0.00578 * age)  # ln(2)/120

	# Importance: normalized to 0-1
	var importance := mem.importance / 10.0

	# Relevance: keyword overlap
	var relevance := 0.0
	if not query_keywords.is_empty() and not mem.keywords.is_empty():
		var overlap := 0
		for kw in query_keywords:
			if kw in mem.keywords:
				overlap += 1
		relevance = float(overlap) / float(query_keywords.size())

	return recency + importance + relevance


func _extract_keywords(text: String) -> PackedStringArray:
	var words := text.to_lower().split(" ", false)
	var result: PackedStringArray = []
	for word in words:
		var clean := word.strip_edges().trim_suffix(".").trim_suffix(",")
		if clean.length() > 2:
			result.append(clean)
	return result


func _trigger_reflection() -> void:
	_is_reflecting = true
	_importance_accumulator = 0.0

	if not LLMManager.is_available:
		# Heuristic reflection
		var recent := get_recent(5)
		if not recent.is_empty():
			add_reflection("%s reflects on recent events and feels %s about how things are going." % [
				_agent_name, ["good", "okay", "uncertain", "thoughtful"].pick_random()
			])
		_is_reflecting = false
		return

	var recent := get_recent(10)
	var recent_text := format_memories_for_prompt(recent)
	var agent := get_parent()
	var profile: PersonalityProfile = agent.personality if agent and agent.get("personality") else null

	var prompt := PromptBuilder.build("reflection", {
		"name": _agent_name,
		"description": profile.description if profile else "",
		"personality": profile.get_personality_summary() if profile else "",
		"recent_memories": recent_text,
	})

	var format_schema := {
		"type": "object",
		"properties": {
			"reflection": {"type": "string"},
		},
		"required": ["reflection"],
	}

	LLMManager.request_chat(
		[
			{"role": "user", "content": prompt},
		],
		format_schema,
		func(success: bool, data: Dictionary, _error: String) -> void:
			_is_reflecting = false
			if success and data.has("reflection"):
				add_reflection(str(data["reflection"]))
			else:
				add_reflection("%s takes a moment to think about recent events." % _agent_name),
		LLMManager.Priority.LOW,
	)


func _compact() -> void:
	# Keep reflections and high-importance memories, drop oldest low-importance ones
	var to_remove: Array[int] = []
	for i in range(mini(COMPACTION_BATCH, memories.size())):
		var mem := memories[i]
		if mem.type != MemoryEntry.MemoryType.REFLECTION and mem.importance < 5.0:
			to_remove.append(i)
	# Remove in reverse order to preserve indices
	to_remove.reverse()
	for idx in to_remove:
		memories.remove_at(idx)
