extends Node
## Global configuration.

# Needs
const NEED_MAX := 100.0
const NEED_CRITICAL_THRESHOLD := 20.0
const NEED_DECAY_BASE := {
	NeedType.Type.ENERGY: 0.15,       # per game minute
	NeedType.Type.HUNGER: 0.1,
	NeedType.Type.SOCIAL: 0.08,
	NeedType.Type.PRODUCTIVITY: 0.12,
}

# Agent
const AGENT_MOVE_SPEED := 60.0  # pixels per second
const AGENT_THINK_INTERVAL := 2.0  # real seconds between think ticks (round-robin)

# Tiles
const TILE_SIZE := 16

# Camera
const CAMERA_ZOOM_MIN := 1.0
const CAMERA_ZOOM_MAX := 5.0
const CAMERA_ZOOM_STEP := 0.25
const CAMERA_PAN_SPEED := 300.0
