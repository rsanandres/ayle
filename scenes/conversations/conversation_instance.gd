class_name ConversationInstance
extends Node
## Manages a single 2-agent conversation: turn-taking, LLM calls, speech bubbles.

signal conversation_finished(agent_a_name: String, agent_b_name: String)

var agent_a: Node2D  # initiator
var agent_b: Node2D
var _history: Array[Dictionary] = []  # [{speaker, line}]
var _current_turn: int = 0
var _max_turns: int = 4
var _is_confession: bool = false
var _waiting_for_response: bool = false
var _line_timer: float = 0.0
var _showing_line: bool = false


func start(a: Node2D, b: Node2D, confession: bool = false) -> void:
	agent_a = a
	agent_b = b
	_is_confession = confession
	_max_turns = 2 if confession else Config.CONVERSATION_TURNS
	# Both agents enter talking state
	agent_a.enter_talking_state()
	agent_b.enter_talking_state()
	EventBus.conversation_started.emit(agent_a.agent_name, agent_b.agent_name)
	# Start first turn
	_request_next_line()


func _process(delta: float) -> void:
	if _showing_line:
		_line_timer -= delta
		if _line_timer <= 0.0:
			_showing_line = false
			_current_turn += 1
			if _current_turn >= _max_turns * 2:  # Each turn has 2 speakers
				_end_conversation()
			else:
				_request_next_line()


func _request_next_line() -> void:
	if _waiting_for_response:
		return
	var speaker := agent_a if _current_turn % 2 == 0 else agent_b
	var listener := agent_b if _current_turn % 2 == 0 else agent_a

	if not LLMManager.is_available:
		# Heuristic fallback
		var line := _heuristic_line(speaker, listener)
		_on_line_received(speaker, listener, line)
		return

	_waiting_for_response = true
	var template_name := "confession" if (_is_confession and _current_turn < 2) else "conversation"
	var history_text := _format_history()
	var rel: RelationshipEntry = speaker.relationships.get_relationship(listener.agent_name)

	var prompt := PromptBuilder.build(template_name, {
		"name": speaker.agent_name,
		"description": speaker.personality.description if speaker.personality else "",
		"personality": speaker.personality.get_personality_summary() if speaker.personality else "",
		"speech_style": speaker.personality.speech_style if speaker.personality else "",
		"other_name": listener.agent_name,
		"other_description": listener.personality.description if listener.personality else "",
		"relationship": rel.get_summary(),
		"affinity": "%.0f" % rel.affinity,
		"history": history_text,
		"mood": speaker.personality.get_mood(speaker.needs.get_all_values()) if speaker.personality else "neutral",
	})

	var format_schema := {
		"type": "object",
		"properties": {
			"line": {"type": "string"},
		},
		"required": ["line"],
	}

	LLMManager.request_chat(
		[{"role": "user", "content": prompt}],
		format_schema,
		func(success: bool, data: Dictionary, _error: String) -> void:
			_waiting_for_response = false
			if success and data.has("line"):
				_on_line_received(speaker, listener, str(data["line"]))
			else:
				_on_line_received(speaker, listener, _heuristic_line(speaker, listener)),
		LLMManager.Priority.HIGH,
	)


func _on_line_received(speaker: Node2D, _listener: Node2D, line: String) -> void:
	_history.append({"speaker": speaker.agent_name, "line": line})
	speaker.show_speech(line, Config.CONVERSATION_LINE_DURATION)
	EventBus.conversation_line.emit(speaker.agent_name, line)
	_showing_line = true
	_line_timer = Config.CONVERSATION_LINE_DURATION + 0.5


func _end_conversation() -> void:
	# Store conversation as memory for both agents
	var convo_summary := _summarize_conversation()
	agent_a.memory.add_conversation(
		"%s had a conversation with %s: %s" % [agent_a.agent_name, agent_b.agent_name, convo_summary],
		agent_b.agent_name, 5.0
	)
	agent_b.memory.add_conversation(
		"%s had a conversation with %s: %s" % [agent_b.agent_name, agent_a.agent_name, convo_summary],
		agent_a.agent_name, 5.0
	)

	# Update relationships
	agent_a.relationships.update_after_interaction(agent_b.agent_name, convo_summary, true)
	agent_b.relationships.update_after_interaction(agent_a.agent_name, convo_summary, true)

	# Restore social need
	agent_a.needs.restore(NeedType.Type.SOCIAL, 20.0)
	agent_b.needs.restore(NeedType.Type.SOCIAL, 20.0)

	# Handle confession outcome
	if _is_confession:
		_process_confession()

	# Request reflection from LLM
	_request_reflection(agent_a, agent_b)
	_request_reflection(agent_b, agent_a)

	# Exit talking state
	agent_a.exit_talking_state()
	agent_b.exit_talking_state()

	EventBus.conversation_ended.emit(agent_a.agent_name, agent_b.agent_name)
	conversation_finished.emit(agent_a.agent_name, agent_b.agent_name)
	queue_free()


func _process_confession() -> void:
	var rel_b: RelationshipEntry = agent_b.relationships.get_relationship(agent_a.agent_name)
	var accepted: bool = rel_b.romantic_interest > 40.0
	EventBus.confession_made.emit(agent_a.agent_name, agent_b.agent_name, accepted)
	if accepted:
		var rel_a: RelationshipEntry = agent_a.relationships.get_relationship(agent_b.agent_name)
		rel_a.relationship_status = RelationshipEntry.Status.DATING
		rel_b.relationship_status = RelationshipEntry.Status.DATING
		rel_a.add_tag("partner")
		rel_b.add_tag("partner")
		EventBus.romance_started.emit(agent_a.agent_name, agent_b.agent_name)
		EventBus.narrative_event.emit(
			"%s confessed feelings to %s, and they started dating!" % [agent_a.agent_name, agent_b.agent_name],
			[agent_a.agent_name, agent_b.agent_name], 9.0
		)
		agent_a.memory.add_memory(MemoryEntry.MemoryType.CONVERSATION,
			"%s confessed feelings to %s and they accepted! They are now dating." % [agent_a.agent_name, agent_b.agent_name],
			10.0, PackedStringArray([agent_b.agent_name]))
		agent_b.memory.add_memory(MemoryEntry.MemoryType.CONVERSATION,
			"%s confessed their feelings, and %s said yes! They are now dating." % [agent_a.agent_name, agent_b.agent_name],
			10.0, PackedStringArray([agent_a.agent_name]))
	else:
		EventBus.narrative_event.emit(
			"%s confessed feelings to %s, but was rejected." % [agent_a.agent_name, agent_b.agent_name],
			[agent_a.agent_name, agent_b.agent_name], 7.0
		)
		agent_a.memory.add_memory(MemoryEntry.MemoryType.CONVERSATION,
			"%s confessed feelings to %s but was rejected. This is heartbreaking." % [agent_a.agent_name, agent_b.agent_name],
			9.0, PackedStringArray([agent_b.agent_name]))


func _request_reflection(agent: Node2D, other: Node2D) -> void:
	if not LLMManager.is_available:
		return
	var rel: RelationshipEntry = agent.relationships.get_relationship(other.agent_name)
	var prompt := PromptBuilder.build("conversation_reflect", {
		"name": agent.agent_name,
		"other_name": other.agent_name,
		"relationship": rel.get_summary(),
		"conversation_summary": _summarize_conversation(),
		"personality": agent.personality.get_personality_summary() if agent.personality else "",
	})
	var format_schema := {
		"type": "object",
		"properties": {
			"feeling": {"type": "string"},
			"opinion_change": {"type": "string"},
		},
		"required": ["feeling"],
	}
	LLMManager.request_chat(
		[{"role": "user", "content": prompt}],
		format_schema,
		func(success: bool, data: Dictionary, _error: String) -> void:
			if success:
				var feeling: String = data.get("feeling", "")
				if feeling != "":
					agent.memory.add_reflection(
						"%s reflects on conversation with %s: %s" % [agent.agent_name, other.agent_name, feeling]
					),
		LLMManager.Priority.LOW,
	)


func _summarize_conversation() -> String:
	if _history.is_empty():
		return "a brief exchange"
	var parts: PackedStringArray = []
	var limit := mini(3, _history.size())
	for i in range(limit):
		parts.append("%s said '%s'" % [_history[i]["speaker"], _history[i]["line"]])
	return "; ".join(parts)


func _format_history() -> String:
	if _history.is_empty():
		return "(conversation just started)"
	var lines: PackedStringArray = []
	for entry in _history:
		lines.append("%s: %s" % [entry["speaker"], entry["line"]])
	return "\n".join(lines)


func _heuristic_line(speaker: Node2D, listener: Node2D) -> String:
	var rel: RelationshipEntry = speaker.relationships.get_relationship(listener.agent_name)
	var lines: Array[String] = []
	if _is_confession and _current_turn == 0:
		lines = [
			"I've been meaning to tell you something... I really like you, %s." % listener.agent_name,
			"I can't stop thinking about you, %s. I think I have feelings for you." % listener.agent_name,
		]
	elif _is_confession and _current_turn == 1:
		if rel.romantic_interest > 40.0:
			lines = [
				"I... I feel the same way about you, %s." % speaker.agent_name,
				"Really? I've been hoping you'd say that!" ,
			]
		else:
			lines = [
				"I appreciate you telling me, but I don't feel that way.",
				"That's really sweet, but I think we're better as friends.",
			]
	elif rel.affinity > 30:
		lines = [
			"Hey %s, how's your day going?" % listener.agent_name,
			"I've been thinking about that project we discussed.",
			"Want to grab some coffee later?",
			"It's nice working with you.",
		]
	elif rel.affinity < -20:
		lines = [
			"Hmm.",
			"I suppose.",
			"Let's keep this brief.",
		]
	else:
		lines = [
			"Hey there.",
			"How's it going?",
			"Nice weather today.",
			"Back to work, I guess.",
		]
	return lines[randi() % lines.size()]
