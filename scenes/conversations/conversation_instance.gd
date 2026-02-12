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
	var s_name: String = speaker.agent_name
	var l_name: String = listener.agent_name

	# --- Confession lines (expanded) ---
	if _is_confession and _current_turn == 0:
		var pool: Array[String] = [
			"I've been meaning to tell you something... I really like you, %s." % l_name,
			"I can't stop thinking about you, %s. I think I have feelings for you." % l_name,
			"%s, this is hard to say, but... I've developed feelings for you." % l_name,
			"I know this might change things between us, but %s... I like you. A lot." % l_name,
			"Every time I see you, %s, my heart does this stupid thing. I had to tell you." % l_name,
			"I've been going back and forth about this, but... %s, I have a crush on you." % l_name,
			"Okay, deep breath. %s, I think about you way more than a coworker should." % l_name,
			"I wrote this down so I wouldn't chicken out. %s, I have feelings for you." % l_name,
		]
		return pool[randi() % pool.size()]

	if _is_confession and _current_turn == 1:
		if rel.romantic_interest > 40.0:
			var pool: Array[String] = [
				"I... I feel the same way about you, %s." % s_name,
				"Really? I've been hoping you'd say that!",
				"You have no idea how long I've wanted to hear that, %s." % s_name,
				"I thought it was just me! Yes, %s, I feel it too." % s_name,
				"My heart is racing right now. I like you too, %s." % s_name,
				"I've been dropping hints for weeks! Yes, absolutely yes.",
				"I can't stop smiling. I feel exactly the same way.",
				"You just made my whole week, %s. I like you too." % s_name,
			]
			return pool[randi() % pool.size()]
		else:
			var pool: Array[String] = [
				"I appreciate you telling me, but I don't feel that way.",
				"That's really sweet, but I think we're better as friends.",
				"Oh, %s... I care about you, but not like that. I'm sorry." % s_name,
				"I'm flattered, honestly. But I don't have those feelings.",
				"That took courage, and I respect that. But I can't return those feelings.",
				"I wish I felt the same, %s. You deserve someone who does." % s_name,
				"I think you're great, but my heart's just not there. I'm sorry.",
				"I don't want to hurt you, but I have to be honest. I see you as a friend.",
			]
			return pool[randi() % pool.size()]

	# --- Parametric helpers ---
	var quirk: String = _random_from_array(speaker.personality.quirks) if speaker.personality and not speaker.personality.quirks.is_empty() else ""
	var goal: String = _random_from_array(speaker.personality.goals) if speaker.personality and not speaker.personality.goals.is_empty() else ""
	var l_quirk: String = _random_from_array(listener.personality.quirks) if listener.personality and not listener.personality.quirks.is_empty() else ""

	var hour: int = TimeManager.hours
	var time_greeting: String = "Morning" if hour < 12 else ("Afternoon" if hour < 17 else "Evening")
	var is_late: bool = hour >= 20 or hour < 6

	# --- Need-based lines (40% chance if any need is critical) ---
	var energy_val: float = speaker.needs.get_value(NeedType.Type.ENERGY)
	var hunger_val: float = speaker.needs.get_value(NeedType.Type.HUNGER)
	var productivity_val: float = speaker.needs.get_value(NeedType.Type.PRODUCTIVITY)

	var need_pools: Array[Array] = []
	if energy_val < 30.0:
		need_pools.append(_get_tired_lines(s_name, l_name))
	if hunger_val < 30.0:
		need_pools.append(_get_hungry_lines(s_name, l_name))
	if productivity_val < 30.0:
		need_pools.append(_get_stressed_lines(s_name, l_name, goal))

	if not need_pools.is_empty() and randf() < 0.4:
		var chosen_pool: Array = need_pools[randi() % need_pools.size()]
		return _apply_substitutions(chosen_pool[randi() % chosen_pool.size()], s_name, l_name, quirk, goal, l_quirk, time_greeting)

	# --- Romantic lines (romantic_interest > 40 OR dating/partners) ---
	var is_romantic: bool = rel.romantic_interest > 40.0 or rel.relationship_status == RelationshipEntry.Status.DATING or rel.relationship_status == RelationshipEntry.Status.PARTNERS
	if is_romantic:
		var pool: Array[String] = _get_romantic_lines(s_name, l_name, is_late)
		return _apply_substitutions(pool[randi() % pool.size()], s_name, l_name, quirk, goal, l_quirk, time_greeting)

	# --- Relationship-tier lines ---
	var pool: Array[String] = []
	if rel.affinity > 30.0:
		pool = _get_positive_lines(s_name, l_name, quirk, goal, l_quirk, time_greeting)
	elif rel.affinity < -20.0:
		pool = _get_negative_lines(s_name, l_name)
	else:
		pool = _get_neutral_lines(s_name, l_name, time_greeting, is_late)

	return _apply_substitutions(pool[randi() % pool.size()], s_name, l_name, quirk, goal, l_quirk, time_greeting)


func _random_from_array(arr: Array) -> String:
	if arr.is_empty():
		return ""
	return str(arr[randi() % arr.size()])


func _apply_substitutions(line: String, s_name: String, l_name: String, quirk: String, goal: String, l_quirk: String, time_greeting: String) -> String:
	# Replace parametric tokens with actual values
	line = line.replace("{speaker}", s_name)
	line = line.replace("{listener}", l_name)
	line = line.replace("{quirk}", quirk if quirk != "" else "that thing I do")
	line = line.replace("{goal}", goal if goal != "" else "what I'm working toward")
	line = line.replace("{l_quirk}", l_quirk if l_quirk != "" else "your thing")
	line = line.replace("{greeting}", time_greeting)
	line = line.replace("{time}", TimeManager.time_string)
	return line


func _get_tired_lines(_s_name: String, l_name: String) -> Array:
	var pool: Array[String] = [
		"*yawns* Sorry, {listener}. I'm running on fumes today.",
		"I could really use a nap right now, not gonna lie.",
		"Is it just me or is this day lasting forever?",
		"I think I need another coffee... or maybe three.",
		"My eyes keep closing on their own. How are you so awake, {listener}?",
		"I barely slept last night. Everything is a blur.",
		"If I fall asleep mid-sentence, just... let it happen.",
		"I need to find that couch before I collapse at my desk.",
		"*stifles a yawn* What were we talking about?",
		"I've hit a wall, {listener}. A big, soft, sleepy wall.",
		"I'm basically a zombie right now. Be gentle.",
		"You know that feeling where your brain just... stops? That's me right now.",
		"Can we talk sitting down? Standing is... a lot right now.",
		"I think the couch is calling my name. Do you hear it too?",
		"Every blink is a micro-nap at this point.",
		"I wonder if anyone would notice if I napped under my desk.",
		"My energy level is somewhere between 'depleted' and 'nonexistent'.",
		"*rubs eyes* Sorry, you were saying something, {listener}?",
	]
	return pool


func _get_hungry_lines(_s_name: String, l_name: String) -> Array:
	var pool: Array[String] = [
		"Is it lunchtime yet? I'm starving.",
		"I can't focus on anything except food right now.",
		"My stomach just growled so loud I think the whole office heard it.",
		"Want to grab something to eat, {listener}? I'm desperate.",
		"I skipped breakfast and I'm paying the price.",
		"I keep thinking about what's in the break room fridge.",
		"If someone doesn't feed me soon, I might get cranky. Well, crankier.",
		"Do you have any snacks? I will trade you literally anything.",
		"I'm so hungry I'd eat whatever's been in the microwave for a week.",
		"My brain has been replaced by a single thought: food.",
		"*stomach growls* ...pretend you didn't hear that.",
		"I think I could eat an entire pizza by myself right now.",
		"Who decided we only get one lunch break? I need at least three.",
		"Have you tried the coffee machine snacks? Asking for a very hungry friend.",
		"I've been staring at my screen but all I see is sandwiches.",
		"Fun fact, {listener}: I get progressively more useless when hungry. We're at stage four.",
		"I would sell my desk for a burrito right now.",
		"Is it weird that I keep smelling food that isn't there?",
	]
	return pool


func _get_stressed_lines(_s_name: String, _l_name: String, _goal: String) -> Array:
	var pool: Array[String] = [
		"I'm so behind on everything. The deadlines are piling up.",
		"I feel like I haven't accomplished anything productive all day.",
		"There's this project I keep putting off and it's eating at me.",
		"I really need to buckle down and get some work done.",
		"Does it ever feel like the to-do list just keeps growing, {listener}?",
		"I'm stressed about {goal}. It's all I can think about.",
		"My productivity today has been absolutely abysmal.",
		"I should be working right now but my brain won't cooperate.",
		"The pressure is really getting to me today.",
		"I keep staring at my tasks and none of them are getting done.",
		"Have you ever had one of those days where nothing goes right? That's today.",
		"I think I need to step back and reprioritize. Everything feels urgent.",
		"I'm falling behind and it's stressing me out, {listener}.",
		"My desk is covered in notes and I can't make sense of any of them.",
		"I need a plan. Or a miracle. Either works.",
		"I keep switching between tasks and finishing none of them.",
		"If I don't make progress on {goal} soon, I'm going to lose it.",
		"It's that kind of day where the coffee isn't strong enough and the clock isn't fast enough.",
	]
	return pool


func _get_romantic_lines(_s_name: String, l_name: String, is_late: bool) -> Array[String]:
	var pool: Array[String] = [
		"Hey you. I was hoping I'd run into you today, {listener}.",
		"You look really nice today, {listener}. Just thought you should know.",
		"I always feel better when you're around, {listener}.",
		"I saved you a spot by the coffee machine. Your usual, right?",
		"Every time you walk by, I completely forget what I was doing.",
		"I keep finding excuses to come talk to you. Is it obvious?",
		"You know what I like about you, {listener}? Everything. I like everything.",
		"I had this dream about us last night. It was... nice.",
		"My favorite part of the day is whenever I get to see you.",
		"I made you something. It's just a doodle, but... I was thinking of you.",
		"You make even the boring parts of office life feel special, {listener}.",
		"I catch myself smiling every time you laugh. It's embarrassing, honestly.",
		"Want to sneak out for a walk later? Just the two of us.",
		"I brought extra snacks today. The good kind. For you, obviously.",
		"Is it cheesy if I say I missed you? Because I kind of did.",
		"Nobody else in this office makes me feel the way you do, {listener}.",
		"I keep replaying our last conversation in my head. Is that weird?",
		"I wrote your name in my notebook margin. Very subtle, I know.",
		"When you smile like that, {listener}, the whole room gets brighter.",
		"I'm not great with words, but... being with you feels like home.",
	]
	if is_late:
		pool.append("It's late. Walk back together? I'd feel better knowing you're okay.")
		pool.append("The office is so quiet at night. I'm glad you're still here, {listener}.")
		pool.append("We should head out soon. But I'm not ready to stop talking to you.")
	return pool


func _get_positive_lines(s_name: String, l_name: String, quirk: String, goal: String, l_quirk: String, time_greeting: String) -> Array[String]:
	var pool: Array[String] = [
		"Hey {listener}! {greeting}! How's everything going?",
		"I've been meaning to catch up with you, {listener}. It's been a while!",
		"You know, working with you makes the tough days easier, {listener}.",
		"I had this idea I wanted to run by you, {listener}. Got a minute?",
		"Want to grab some coffee later, {listener}? My treat.",
		"I was just thinking about that thing you said the other day. You were so right.",
		"Remember when we worked on that project together? Good times, {listener}.",
		"You always know how to lighten the mood, {listener}. I appreciate that.",
		"I trust your judgment on stuff like this, {listener}. What do you think?",
		"I heard something funny and immediately thought of you, {listener}.",
		"You've been doing great work lately, {listener}. Seriously impressive.",
		"Hey {listener}, thanks for always being supportive. It means a lot.",
		"I feel like we make a really good team, {listener}.",
		"Got any plans this weekend, {listener}? We should hang out!",
		"That was a brilliant point you made in the meeting, {listener}.",
		"I noticed {l_quirk} and honestly it's one of my favorite things about you.",
		"You always have such interesting things to say, {listener}. Tell me more.",
		"I'm working on {goal} and I'd love your input, {listener}.",
		"Not gonna lie, talking to you is the highlight of my day sometimes.",
		"You ever notice how we always end up chatting? I'm not complaining.",
		"I brought snacks. Want some, {listener}? I got your favorite.",
		"I keep meaning to say this: you're a really good friend, {listener}.",
		"Can I be honest? I'm glad you're on this team, {listener}.",
		"I just wanted to check in. How are you really doing, {listener}?",
		"If I'm ever stuck on something, you're the first person I think to ask.",
	]
	return pool


func _get_negative_lines(_s_name: String, l_name: String) -> Array[String]:
	var pool: Array[String] = [
		"Oh. It's you.",
		"Hmm.",
		"I suppose.",
		"Let's keep this brief.",
		"What do you want, {listener}?",
		"Can this wait? I'm busy.",
		"I'd rather not, but fine. What is it?",
		"Sure. Whatever you say.",
		"...right.",
		"Is this going to take long?",
		"I have things to do, {listener}.",
		"That's... one way to look at it.",
		"Must we do this right now?",
		"I'll keep my thoughts to myself on that one.",
		"How nice for you.",
		"Fascinating. Truly.",
		"I'm going to pretend I didn't hear that.",
		"We clearly see things differently.",
		"Look, I'd love to chat but actually no I wouldn't.",
		"Some of us have actual work to do.",
		"I see you're still... like that.",
		"Are we done here?",
		"Noted. Moving on.",
		"You and I never seem to agree on anything.",
		"I'll smile and nod. That's the best I can offer right now.",
	]
	return pool


func _get_neutral_lines(_s_name: String, l_name: String, time_greeting: String, is_late: bool) -> Array[String]:
	var pool: Array[String] = [
		"Hey there, {listener}.",
		"How's it going?",
		"Nice weather today, don't you think?",
		"Back to work, I guess.",
		"{greeting}, {listener}. Getting much done today?",
		"Have you tried the coffee today? It's... something.",
		"Another day at the office, huh?",
		"I keep losing track of time. Is it really {time} already?",
		"The office is kind of quiet today, isn't it?",
		"Did you see the new thing on the whiteboard? Interesting stuff.",
		"I've been meaning to reorganize my desk. One of these days.",
		"Any exciting plans for after work, {listener}?",
		"I think someone left something in the microwave again.",
		"How long have you been working here, {listener}? Feels like forever sometimes.",
		"I wonder what's for lunch. Do you meal prep, {listener}?",
		"This chair is killing my back. Is yours comfortable?",
		"I read something interesting this morning but I already forgot what it was.",
		"Do you ever zone out and then realize twenty minutes have passed?",
		"The plant by the window is looking rough. Someone should water it.",
		"Oh hey, {listener}. Didn't see you there.",
		"I've been going back and forth on something. Nothing major, just life stuff.",
		"Is it just me or do weeks go faster the longer you work here?",
		"I'm trying to decide if I need more coffee or less coffee.",
		"That clock can't be right. There's no way it's {time}.",
		"Some days are just... days, you know? This is one of those.",
	]
	if is_late:
		pool.append("Working late again? We should probably both go home, {listener}.")
		pool.append("The office is kind of eerie this late. You're braver than I am, {listener}.")
	return pool
