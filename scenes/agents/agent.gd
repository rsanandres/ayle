class_name Agent
extends CharacterBody2D
## An AI agent that navigates the office, fulfills needs, and interacts with objects.

@export var agent_name: String = "Agent"
@export var agent_color: Color = Color.CORNFLOWER_BLUE

var state: AgentState.Type = AgentState.Type.IDLE:
	set(value):
		if state == value:
			return
		var old := state
		state = value
		EventBus.agent_state_changed.emit(self, old, state)
		_on_state_changed(old, state)

var current_target: Node2D = null
var current_action: ActionType.Type = ActionType.Type.IDLE
var _path: PackedVector2Array = []
var _path_index: int = 0
var _interact_timer: float = 0.0
var _interact_duration: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO

@onready var needs: AgentNeeds = $AgentNeeds
@onready var brain: HeuristicBrain = $HeuristicBrain
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var label: Label = $NameLabel


func _ready() -> void:
	label.text = agent_name
	_setup_sprite()
	AgentManager.register(self)
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	nav_agent.navigation_finished.connect(_on_navigation_finished)


func _exit_tree() -> void:
	AgentManager.unregister(self)


func _physics_process(delta: float) -> void:
	match state:
		AgentState.Type.IDLE:
			_process_idle(delta)
		AgentState.Type.WALKING:
			_process_walking(delta)
		AgentState.Type.INTERACTING:
			_process_interacting(delta)


func request_think() -> void:
	if state == AgentState.Type.INTERACTING:
		return  # Don't interrupt interactions
	if state == AgentState.Type.WALKING:
		return  # Let them finish walking first
	_make_decision()


func _make_decision() -> void:
	state = AgentState.Type.DECIDING
	var nearby_objects := _get_nearby_objects()
	var nearby_agents := AgentManager.get_agents_near(global_position, 200.0, self)
	var decision: Dictionary = brain.decide(needs, nearby_objects, nearby_agents)
	_execute_decision(decision)


func _execute_decision(decision: Dictionary) -> void:
	current_action = decision.get("action", ActionType.Type.IDLE)
	current_target = decision.get("target", null)

	match current_action:
		ActionType.Type.IDLE:
			state = AgentState.Type.IDLE
		ActionType.Type.WANDER:
			_start_wander()
		ActionType.Type.GO_TO_OBJECT:
			if current_target:
				_navigate_to(current_target.global_position)
				EventBus.agent_action_started.emit(self, current_action, current_target)
			else:
				state = AgentState.Type.IDLE
		ActionType.Type.TALK_TO_AGENT:
			if current_target:
				_navigate_to(current_target.global_position)
				EventBus.agent_action_started.emit(self, current_action, current_target)
			else:
				state = AgentState.Type.IDLE


func _start_wander() -> void:
	var wander_offset := Vector2(randf_range(-80, 80), randf_range(-80, 80))
	_wander_target = global_position + wander_offset
	_navigate_to(_wander_target)


func _navigate_to(target_pos: Vector2) -> void:
	nav_agent.target_position = target_pos
	state = AgentState.Type.WALKING


func _process_idle(_delta: float) -> void:
	velocity = Vector2.ZERO


func _process_walking(_delta: float) -> void:
	if nav_agent.is_navigation_finished():
		_on_navigation_finished()
		return

	var next_pos := nav_agent.get_next_path_position()
	var direction := global_position.direction_to(next_pos)
	velocity = direction * Config.AGENT_MOVE_SPEED
	move_and_slide()

	# Flip sprite based on direction
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0


func _process_interacting(delta: float) -> void:
	_interact_timer += delta * TimeManager.current_speed
	if _interact_timer >= _interact_duration:
		_finish_interaction()


func _on_navigation_finished() -> void:
	velocity = Vector2.ZERO
	if current_action == ActionType.Type.GO_TO_OBJECT and current_target:
		_start_interaction()
	elif current_action == ActionType.Type.TALK_TO_AGENT and current_target:
		# Phase 4: real conversations. For now, just restore social need.
		needs.restore(NeedType.Type.SOCIAL, 15.0)
		EventBus.agent_action_completed.emit(self, current_action, current_target)
		current_target = null
		state = AgentState.Type.IDLE
	else:
		state = AgentState.Type.IDLE


func _start_interaction() -> void:
	if not current_target or not current_target.has_method("occupy"):
		state = AgentState.Type.IDLE
		return

	if not current_target.is_available():
		# Object is busy, go idle and re-decide next tick
		state = AgentState.Type.IDLE
		return

	current_target.occupy(self)
	_interact_duration = current_target.get_interaction_duration()
	_interact_timer = 0.0
	state = AgentState.Type.INTERACTING
	EventBus.object_occupied.emit(current_target, self)


func _finish_interaction() -> void:
	if current_target and current_target.has_method("release"):
		# Apply need effects
		var effects: Dictionary = current_target.get_need_effects()
		for need_type in effects:
			needs.restore(need_type, effects[need_type])
		current_target.release(self)
		EventBus.object_freed.emit(current_target, self)
		EventBus.agent_action_completed.emit(self, current_action, current_target)
	current_target = null
	state = AgentState.Type.IDLE


func _get_nearby_objects() -> Array:
	var objects: Array = []
	var bodies := interaction_area.get_overlapping_bodies()
	for body in bodies:
		if body is InteractableObject:
			objects.append(body)
	# Also find objects further away via the world
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("get_all_objects"):
		for obj in world.get_all_objects():
			if obj not in objects:
				objects.append(obj)
	return objects


func _on_state_changed(_old: AgentState.Type, _new: AgentState.Type) -> void:
	pass


func _setup_sprite() -> void:
	# Create a simple colored rectangle as placeholder sprite
	var img := Image.create(12, 16, false, Image.FORMAT_RGBA8)
	img.fill(agent_color)
	# Head (lighter)
	var head_color := agent_color.lightened(0.3)
	for x in range(2, 10):
		for y in range(0, 6):
			img.set_pixel(x, y, head_color)
	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex


func _on_input_event(viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		EventBus.agent_selected.emit(self)
		viewport.set_input_as_handled()
