class_name Agent
extends CharacterBody2D
## An AI agent that navigates the office, fulfills needs, and interacts with objects.

@export var agent_name: String = "Agent"
@export var agent_color: Color = Color.CORNFLOWER_BLUE
@export var personality_file: String = ""

var personality: PersonalityProfile = null
var procedural_personality_data: Dictionary = {}  # Set before _ready for procedural agents
var state: AgentState.Type = AgentState.Type.IDLE:
	set(value):
		if state == value:
			return
		var old := state
		state = value
		EventBus.agent_state_changed.emit(self, old, state)

var current_target: Node2D = null
var current_action: ActionType.Type = ActionType.Type.IDLE
var health_state: HealthState = null
var is_dead: bool = false
var _interact_timer: float = 0.0
var _interact_duration: float = 0.0
var _idle_frames: Array[ImageTexture] = []
var _walk_frames: Array[ImageTexture] = []
var _anim_timer: float = 0.0
var _anim_frame: int = 0
var _speech_tween: Tween = null
var _footstep_timer: float = 0.0
var _selection_ring: Node2D = null
var _is_selected: bool = false
var _interaction_particles: CPUParticles2D = null
var _death_particles: CPUParticles2D = null

@onready var needs: AgentNeeds = $AgentNeeds
@onready var heuristic_brain: HeuristicBrain = $HeuristicBrain
@onready var smart_brain: AgentBrain = $AgentBrain
@onready var memory: AgentMemory = $AgentMemory
@onready var relationships: AgentRelationships = $AgentRelationships
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var label: Label = $NameLabel
@onready var thought_bubble: Label = $ThoughtBubble
@onready var speech_bubble: Label = $SpeechBubble
@onready var emotion_indicator: Label = $EmotionIndicator


func _ready() -> void:
	_load_personality()
	label.text = agent_name
	_setup_sprite()
	_setup_particles()
	_setup_selection_ring()
	memory.setup(agent_name)
	smart_brain.personality = personality
	smart_brain.thought_generated.connect(_on_thought)
	AgentManager.register(self)
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	nav_agent.navigation_finished.connect(_on_navigation_finished)
	memory.add_observation("%s arrives at the office and starts their day." % agent_name, 3.0)
	# Initialize health
	health_state = HealthState.new()
	health_state.randomize_lifespan()
	EventBus.day_changed.connect(_on_day_changed)
	EventBus.agent_selected.connect(_on_global_agent_selected)
	EventBus.agent_deselected.connect(_on_global_agent_deselected)


func _exit_tree() -> void:
	AgentManager.unregister(self)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	match state:
		AgentState.Type.IDLE:
			velocity = Vector2.ZERO
		AgentState.Type.WALKING:
			_process_walking(delta)
		AgentState.Type.INTERACTING:
			_process_interacting(delta)
	_animate(delta)
	_update_emotion_indicator()
	_update_need_warning()


func request_think() -> void:
	if is_dead:
		return
	if state == AgentState.Type.INTERACTING or state == AgentState.Type.TALKING:
		return
	if state == AgentState.Type.WALKING:
		return
	_make_decision()


func show_speech(text: String, duration: float = 3.0) -> void:
	speech_bubble.text = text
	speech_bubble.visible = true
	if _speech_tween and _speech_tween.is_valid():
		_speech_tween.kill()
	speech_bubble.modulate.a = 1.0
	_speech_tween = create_tween()
	_speech_tween.tween_interval(duration)
	_speech_tween.tween_property(speech_bubble, "modulate:a", 0.0, 0.5)
	_speech_tween.tween_callback(func() -> void:
		speech_bubble.visible = false
		speech_bubble.modulate.a = 1.0
	)


func enter_talking_state() -> void:
	state = AgentState.Type.TALKING
	velocity = Vector2.ZERO


func exit_talking_state() -> void:
	if state == AgentState.Type.TALKING:
		state = AgentState.Type.IDLE


func die(cause: String = "natural causes") -> void:
	if is_dead:
		return
	is_dead = true
	state = AgentState.Type.IDLE
	velocity = Vector2.ZERO
	# Death particles
	if _death_particles:
		_death_particles.emitting = true
	# Fade out sprite
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 2.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func() -> void:
		EventBus.agent_died.emit(agent_name, cause)
		EventBus.narrative_event.emit(
			"%s has passed away (%s)." % [agent_name, cause],
			[agent_name], 10.0
		)
		# Notify nearby agents for grief
		var nearby := AgentManager.get_agents_near(global_position, 300.0, self)
		for other in nearby:
			if other.has_method("witness_death"):
				other.witness_death(agent_name, cause)
		queue_free()
	)


func witness_death(dead_name: String, cause: String) -> void:
	memory.add_memory(
		MemoryEntry.MemoryType.OBSERVATION,
		"%s witnessed %s passing away from %s. This is deeply sad." % [agent_name, dead_name, cause],
		10.0, PackedStringArray([dead_name])
	)
	memory.memories[-1].emotion = "grief"
	memory.memories[-1].sentiment = -0.9
	memory.memories[-1].decay_protected = true
	needs.restore(NeedType.Type.SOCIAL, -30.0)


func _make_decision() -> void:
	state = AgentState.Type.DECIDING
	var nearby_objects := _get_nearby_objects()
	var nearby_agents := AgentManager.get_agents_near(global_position, 200.0, self)
	var decision: Dictionary = smart_brain.decide(needs, nearby_objects, nearby_agents)
	if decision.get("waiting_for_llm", false):
		state = AgentState.Type.IDLE
		return
	_execute_decision(decision)


func _execute_decision(decision: Dictionary) -> void:
	current_action = decision.get("action", ActionType.Type.IDLE)
	current_target = decision.get("target", null)

	match current_action:
		ActionType.Type.IDLE:
			state = AgentState.Type.IDLE
		ActionType.Type.WANDER:
			_start_wander()
			memory.add_action("%s decides to wander around the office." % agent_name, 1.0)
		ActionType.Type.GO_TO_OBJECT:
			if current_target:
				_navigate_to(current_target.global_position)
				memory.add_action("%s heads to the %s." % [agent_name, current_target.display_name], 2.0)
				EventBus.agent_action_started.emit(self, current_action, current_target)
			else:
				state = AgentState.Type.IDLE
		ActionType.Type.TALK_TO_AGENT:
			if current_target:
				_navigate_to(current_target.global_position)
				memory.add_action("%s goes to talk to %s." % [agent_name, current_target.agent_name], 3.0)
				EventBus.agent_action_started.emit(self, current_action, current_target)
			else:
				state = AgentState.Type.IDLE
		ActionType.Type.CONFESS_FEELINGS:
			if current_target:
				_navigate_to(current_target.global_position)
				memory.add_action("%s gathers courage to confess feelings to %s." % [agent_name, current_target.agent_name], 7.0)
				EventBus.agent_action_started.emit(self, current_action, current_target)
			else:
				state = AgentState.Type.IDLE


func _start_wander() -> void:
	var wander_offset := Vector2(randf_range(-80, 80), randf_range(-80, 80))
	_navigate_to(global_position + wander_offset)


func _navigate_to(target_pos: Vector2) -> void:
	nav_agent.target_position = target_pos
	state = AgentState.Type.WALKING


func _process_walking(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		_on_navigation_finished()
		return
	var next_pos := nav_agent.get_next_path_position()
	var direction := global_position.direction_to(next_pos)
	velocity = direction * Config.AGENT_MOVE_SPEED
	move_and_slide()
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

	# Footstep SFX
	_footstep_timer += delta
	if _footstep_timer >= AudioManager.FOOTSTEP_INTERVAL:
		_footstep_timer = 0.0
		var sfx_name := "footstep_1" if randi() % 2 == 0 else "footstep_2"
		AudioManager.play_sfx(sfx_name, -12.0)


func _process_interacting(delta: float) -> void:
	_interact_timer += delta * TimeManager.current_speed
	if _interact_timer >= _interact_duration:
		_finish_interaction()


func _on_navigation_finished() -> void:
	velocity = Vector2.ZERO
	if current_action == ActionType.Type.GO_TO_OBJECT and current_target:
		_start_interaction()
	elif current_action == ActionType.Type.TALK_TO_AGENT and current_target:
		if current_target and not current_target.is_dead:
			ConversationManager.start_conversation(self, current_target)
		else:
			needs.restore(NeedType.Type.SOCIAL, 15.0)
			state = AgentState.Type.IDLE
	elif current_action == ActionType.Type.CONFESS_FEELINGS and current_target:
		if current_target and not current_target.is_dead:
			ConversationManager.start_confession(self, current_target)
		else:
			state = AgentState.Type.IDLE
	else:
		state = AgentState.Type.IDLE


func _start_interaction() -> void:
	if not current_target or not current_target.has_method("occupy"):
		state = AgentState.Type.IDLE
		return
	if not current_target.is_available():
		memory.add_observation("%s found the %s was occupied." % [agent_name, current_target.display_name], 1.0)
		state = AgentState.Type.IDLE
		return
	current_target.occupy(self)
	_interact_duration = current_target.get_interaction_duration()
	_interact_timer = 0.0
	state = AgentState.Type.INTERACTING
	EventBus.object_occupied.emit(current_target, self)
	# Interaction sparkles
	if _interaction_particles:
		_interaction_particles.emitting = true


func _finish_interaction() -> void:
	if current_target and current_target.has_method("release"):
		var effects: Dictionary = current_target.get_need_effects()
		for need in effects:
			needs.restore(need, effects[need])
		memory.add_action(
			"%s finished using the %s." % [agent_name, current_target.display_name], 2.0
		)
		current_target.release(self)
		EventBus.object_freed.emit(current_target, self)
		EventBus.agent_action_completed.emit(self, current_action, current_target)
	if _interaction_particles:
		_interaction_particles.emitting = false
	current_target = null
	state = AgentState.Type.IDLE


func _get_nearby_objects() -> Array:
	var objects: Array = []
	var bodies := interaction_area.get_overlapping_bodies()
	for body in bodies:
		if body is InteractableObject:
			objects.append(body)
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("get_all_objects"):
		for obj in world.get_all_objects():
			if obj not in objects:
				objects.append(obj)
	return objects


func _load_personality() -> void:
	if personality_file == "__procedural__" and not procedural_personality_data.is_empty():
		personality = PersonalityProfile.from_dict(procedural_personality_data)
	elif personality_file != "" and personality_file != "__procedural__":
		var path := "res://resources/personalities/%s.json" % personality_file
		personality = PersonalityProfile.load_from_json(path)
	else:
		return
	if personality:
		agent_name = personality.agent_name
		agent_color = personality.color
		_apply_personality_decay_rates()


func _apply_personality_decay_rates() -> void:
	for need_key in personality.need_decay_multipliers:
		var need_enum: NeedType.Type
		match need_key:
			"energy": need_enum = NeedType.Type.ENERGY
			"hunger": need_enum = NeedType.Type.HUNGER
			"social": need_enum = NeedType.Type.SOCIAL
			"productivity": need_enum = NeedType.Type.PRODUCTIVITY
			_: continue
		var base_rate: float = Config.NEED_DECAY_BASE.get(need_enum, 0.1)
		var multiplier: float = personality.need_decay_multipliers[need_key]
		needs.set_decay_rate(need_enum, base_rate * multiplier)


func _on_thought(thought: String) -> void:
	thought_bubble.text = thought
	thought_bubble.visible = true
	EventBus.narrative_event.emit(
		"%s thinks: \"%s\"" % [agent_name, thought],
		[agent_name], 2.0
	)
	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(thought_bubble, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func() -> void:
		thought_bubble.visible = false
		thought_bubble.modulate.a = 1.0
	)


func _setup_sprite() -> void:
	match personality_file:
		"alice": _set_sprite_frames(SpriteFactory.create_alice())
		"bob": _set_sprite_frames(SpriteFactory.create_bob())
		"clara": _set_sprite_frames(SpriteFactory.create_clara())
		"dave": _set_sprite_frames(SpriteFactory.create_dave())
		"emma": _set_sprite_frames(SpriteFactory.create_emma())
		_:
			if personality:
				_set_sprite_frames(SpriteFactory.create_from_color(personality.color))
			else:
				_set_sprite_frames(SpriteFactory.create_character(
					Color(agent_color), Color(agent_color.darkened(0.3)), Palette.WOOD_DARK))
	if not _idle_frames.is_empty():
		sprite.texture = _idle_frames[0]


func _set_sprite_frames(all_frames: Array[ImageTexture]) -> void:
	# SpriteFactory now returns [idle_0, idle_1, walk_0, walk_1, walk_2, walk_3]
	if all_frames.size() >= 6:
		_idle_frames = [all_frames[0], all_frames[1]]
		_walk_frames = [all_frames[2], all_frames[3], all_frames[4], all_frames[5]]
	elif all_frames.size() >= 2:
		_idle_frames = [all_frames[0], all_frames[1]]
		_walk_frames = [all_frames[0], all_frames[1]]  # Fallback to idle
	elif all_frames.size() == 1:
		_idle_frames = [all_frames[0]]
		_walk_frames = [all_frames[0]]


func _animate(delta: float) -> void:
	_anim_timer += delta
	if state == AgentState.Type.WALKING and _walk_frames.size() >= 2:
		# Walk animation: faster cycle
		if _anim_timer >= 0.2:
			_anim_timer -= 0.2
			_anim_frame = (_anim_frame + 1) % _walk_frames.size()
			sprite.texture = _walk_frames[_anim_frame]
	elif _idle_frames.size() >= 2:
		# Idle bob: slower cycle
		if _anim_timer >= 0.8:
			_anim_timer -= 0.8
			_anim_frame = (_anim_frame + 1) % _idle_frames.size()
			sprite.texture = _idle_frames[_anim_frame]


func _setup_particles() -> void:
	# Interaction sparkles
	_interaction_particles = CPUParticles2D.new()
	_interaction_particles.emitting = false
	_interaction_particles.amount = 6
	_interaction_particles.lifetime = 0.6
	_interaction_particles.one_shot = false
	_interaction_particles.explosiveness = 0.3
	_interaction_particles.direction = Vector2(0, -1)
	_interaction_particles.spread = 60.0
	_interaction_particles.initial_velocity_min = 10.0
	_interaction_particles.initial_velocity_max = 25.0
	_interaction_particles.gravity = Vector2(0, 20)
	_interaction_particles.scale_amount_min = 0.5
	_interaction_particles.scale_amount_max = 1.0
	_interaction_particles.color = Color(1.0, 0.9, 0.4, 0.8)
	_interaction_particles.position = Vector2(0, -8)
	add_child(_interaction_particles)

	# Death particles
	_death_particles = CPUParticles2D.new()
	_death_particles.emitting = false
	_death_particles.amount = 12
	_death_particles.lifetime = 2.0
	_death_particles.one_shot = true
	_death_particles.explosiveness = 0.8
	_death_particles.direction = Vector2(0, -1)
	_death_particles.spread = 180.0
	_death_particles.initial_velocity_min = 5.0
	_death_particles.initial_velocity_max = 15.0
	_death_particles.gravity = Vector2(0, -5)
	_death_particles.scale_amount_min = 0.5
	_death_particles.scale_amount_max = 1.5
	_death_particles.color = Color(0.3, 0.3, 0.4, 0.6)
	add_child(_death_particles)


func _setup_selection_ring() -> void:
	_selection_ring = Node2D.new()
	_selection_ring.visible = false
	_selection_ring.z_index = -1
	add_child(_selection_ring)
	_selection_ring.draw.connect(_draw_selection_ring)


func _draw_selection_ring() -> void:
	if _selection_ring:
		var pulse := 0.6 + sin(Time.get_ticks_msec() * 0.005) * 0.2
		_selection_ring.draw_arc(Vector2(0, 2), 10.0, 0, TAU, 24, Color(1.0, 0.9, 0.3, pulse), 1.0)


func _on_global_agent_selected(agent: Node2D) -> void:
	_is_selected = (agent == self)
	_selection_ring.visible = _is_selected


func _on_global_agent_deselected() -> void:
	_is_selected = false
	_selection_ring.visible = false


func _update_need_warning() -> void:
	# Flash name label red when any need is critical
	var any_critical := false
	var all_values: Dictionary = needs.get_all_values()
	for need in all_values:
		if need == NeedType.Type.HEALTH:
			continue
		var val: float = all_values[need]
		if val < Config.NEED_CRITICAL_THRESHOLD:
			any_critical = true
			break

	if any_critical:
		var pulse := 0.5 + sin(Time.get_ticks_msec() * 0.008) * 0.5
		label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, pulse))
	else:
		label.remove_theme_color_override("font_color")


func _update_emotion_indicator() -> void:
	if not health_state:
		return
	var indicator_text := ""
	if health_state.life_stage == LifeStage.Type.DYING:
		indicator_text = "..."
	elif state == AgentState.Type.TALKING:
		indicator_text = "..."
	elif needs.get_value(NeedType.Type.ENERGY) < 15.0:
		indicator_text = "zzz"
	elif needs.get_value(NeedType.Type.SOCIAL) < 15.0:
		indicator_text = "..."

	if indicator_text != "":
		emotion_indicator.text = indicator_text
		emotion_indicator.visible = true
	else:
		emotion_indicator.visible = false


func _on_day_changed(day: int) -> void:
	if is_dead or not health_state:
		return
	health_state.advance_day()
	if health_state.health <= 0.0 or health_state.life_stage == LifeStage.Type.DEAD:
		die("old age")
	if health_state.life_stage == LifeStage.Type.SENIOR:
		needs.set_decay_rate(NeedType.Type.ENERGY, Config.NEED_DECAY_BASE.get(NeedType.Type.ENERGY, 0.15) * 1.5)
	if not health_state.conditions.is_empty():
		for condition in health_state.conditions:
			EventBus.agent_sick.emit(agent_name, condition)


func _on_input_event(viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		EventBus.agent_selected.emit(self)
		viewport.set_input_as_handled()


func _process(_delta: float) -> void:
	# Redraw selection ring for pulse animation
	if _is_selected and _selection_ring:
		_selection_ring.queue_redraw()
