extends Node
## Steam integration via GodotSteam GDExtension. Graceful no-op without Steam.

var is_steam_available: bool = false
var steam_id: int = 0
var _steam: Object = null  # Steam singleton reference


func _ready() -> void:
	_init_steam()


func _init_steam() -> void:
	# Check if GodotSteam is available
	if not Engine.has_singleton("Steam"):
		print("[SteamManager] Steam not available (no GodotSteam)")
		return

	_steam = Engine.get_singleton("Steam")
	if not _steam:
		return

	# Initialize Steam
	var init_result: Dictionary = _steam.steamInit()
	if init_result.get("status", 0) != 1:
		push_warning("[SteamManager] Steam init failed: %s" % str(init_result))
		return

	is_steam_available = true
	steam_id = _steam.getSteamID()
	print("[SteamManager] Steam initialized. User ID: %d" % steam_id)

	# Set up rich presence
	_update_rich_presence()


func _process(_delta: float) -> void:
	if is_steam_available and _steam:
		_steam.run_callbacks()


func set_achievement(achievement_id: String) -> void:
	if not is_steam_available or not _steam:
		return
	_steam.setAchievement(achievement_id)
	_steam.storeStats()
	print("[SteamManager] Achievement set: %s" % achievement_id)


func clear_achievement(achievement_id: String) -> void:
	if not is_steam_available or not _steam:
		return
	_steam.clearAchievement(achievement_id)
	_steam.storeStats()


func update_rich_presence_game(day: int, agent_count: int, storyline_count: int) -> void:
	if not is_steam_available or not _steam:
		return
	_steam.setRichPresence("steam_display", "#StatusFull")
	_steam.setRichPresence("day", str(day))
	_steam.setRichPresence("agents", str(agent_count))
	_steam.setRichPresence("storylines", str(storyline_count))


func _update_rich_presence() -> void:
	if not is_steam_available or not _steam:
		return
	_steam.setRichPresence("steam_display", "#StatusInMenu")
