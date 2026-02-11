extends Node
## Autoload: serializes full world state to JSON. Auto-saves, manual save/load.

const SAVE_PATH := "user://ayle_save.json"
const AUTO_SAVE_INTERVAL_DAYS := 5

var _last_auto_save_day: int = 0


func _ready() -> void:
	EventBus.day_changed.connect(_on_day_changed)


func save_game() -> bool:
	var data := _serialize_world()
	var json_str := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Failed to open save file for writing")
		return false
	file.store_string(json_str)
	file.close()
	print("[SaveManager] Game saved to %s" % SAVE_PATH)
	EventBus.narrative_event.emit("Game saved.", [], 1.0)
	return true


func load_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("SaveManager: No save file found")
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("SaveManager: Failed to parse save file")
		return false
	var data: Dictionary = json.data
	_deserialize_world(data)
	print("[SaveManager] Game loaded from %s" % SAVE_PATH)
	EventBus.narrative_event.emit("Game loaded.", [], 1.0)
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _on_day_changed(day: int) -> void:
	if day - _last_auto_save_day >= AUTO_SAVE_INTERVAL_DAYS:
		_last_auto_save_day = day
		save_game()


func _serialize_world() -> Dictionary:
	var data := {
		"version": 1,
		"game_time": TimeManager.game_minutes,
		"speed_index": TimeManager.speed_index,
		"agents": [],
		"objects": [],
		"narrative_log": [],
	}

	# Serialize agents
	for agent in AgentManager.agents:
		var agent_data := {
			"name": agent.agent_name,
			"personality_file": agent.personality_file,
			"position": {"x": agent.position.x, "y": agent.position.y},
			"needs": {},
			"relationships": {},
			"memories": [],
			"health": null,
		}

		# Needs
		var needs_values: Dictionary = agent.needs.get_all_values()
		for need in needs_values:
			agent_data["needs"][NeedType.to_string_name(need)] = needs_values[need]

		# Relationships
		if agent.relationships:
			var rels: Dictionary = agent.relationships.get_all_relationships()
			for other_name in rels:
				var rel: RelationshipEntry = rels[other_name]
				agent_data["relationships"][other_name] = rel.to_dict()

		# Memories (save last 50, compact)
		var recent_mems: Array[MemoryEntry] = agent.memory.get_recent(50)
		for mem in recent_mems:
			agent_data["memories"].append(mem.to_dict())

		# Health
		if agent.health_state:
			agent_data["health"] = agent.health_state.to_dict()

		data["agents"].append(agent_data)

	# Serialize placed objects
	var world := get_tree().get_first_node_in_group("world")
	if world:
		for obj in world.get_all_objects():
			data["objects"].append({
				"type": obj.object_type,
				"display_name": obj.display_name,
				"position": {"x": obj.position.x, "y": obj.position.y},
			})

	return data


func _deserialize_world(data: Dictionary) -> void:
	# Restore game time
	TimeManager.game_minutes = data.get("game_time", 480.0)
	TimeManager.set_speed(data.get("speed_index", 1))

	# Restore agents (update existing ones rather than respawning)
	var agent_datas: Array = data.get("agents", [])
	for agent_data in agent_datas:
		var agent_name: String = agent_data.get("name", "")
		var agent := AgentManager.get_agent_by_name(agent_name)
		if not agent:
			continue  # Skip agents that don't exist in scene

		# Restore needs
		var needs_data: Dictionary = agent_data.get("needs", {})
		for need_key in needs_data:
			var need_type: NeedType.Type
			match need_key:
				"energy": need_type = NeedType.Type.ENERGY
				"hunger": need_type = NeedType.Type.HUNGER
				"social": need_type = NeedType.Type.SOCIAL
				"productivity": need_type = NeedType.Type.PRODUCTIVITY
				"health": need_type = NeedType.Type.HEALTH
				_: continue
			agent.needs.set_value(need_type, float(needs_data[need_key]))

		# Restore position
		var pos_data: Dictionary = agent_data.get("position", {})
		agent.position = Vector2(pos_data.get("x", agent.position.x), pos_data.get("y", agent.position.y))

		# Restore relationships
		var rels_data: Dictionary = agent_data.get("relationships", {})
		for other_name in rels_data:
			var rel_dict: Dictionary = rels_data[other_name]
			var rel := RelationshipEntry.from_dict(rel_dict)
			agent.relationships._relationships[other_name] = rel

		# Restore memories
		var mems_data: Array = agent_data.get("memories", [])
		agent.memory.memories.clear()
		for mem_dict in mems_data:
			var mem := MemoryEntry.from_dict(mem_dict)
			agent.memory.memories.append(mem)

		# Restore health
		var health_data = agent_data.get("health", null)
		if health_data is Dictionary:
			agent.health_state = HealthState.from_dict(health_data)
