extends Node
## Global configuration.

# Needs
const NEED_MAX := 100.0
const NEED_CRITICAL_THRESHOLD := 20.0
var NEED_DECAY_BASE := {
	NeedType.Type.ENERGY: 0.15,
	NeedType.Type.HUNGER: 0.1,
	NeedType.Type.SOCIAL: 0.08,
	NeedType.Type.PRODUCTIVITY: 0.12,
	NeedType.Type.HEALTH: 0.02,
}

# Agent
const AGENT_MOVE_SPEED := 40.0  # pixels per second (slower for desktop feel)
const AGENT_THINK_INTERVAL := 5.0  # real seconds between think ticks (slower = less LLM load)
const MAX_AGENTS_DESKTOP := 3  # fewer agents in desktop mode

# Health & Aging
const AGENT_LIFESPAN_MIN := 80  # game-days
const AGENT_LIFESPAN_MAX := 120
const HEALTH_DECAY_BASE := 0.02  # per game-minute when senior

# Tiles
const TILE_SIZE := 16

# Camera
const CAMERA_ZOOM_MIN := 1.0
const CAMERA_ZOOM_MAX := 5.0
const CAMERA_ZOOM_STEP := 0.25
const CAMERA_PAN_SPEED := 300.0

# Desktop mode
const DESKTOP_WINDOW_WIDTH := 480
const DESKTOP_WINDOW_HEIGHT := 320
const DESKTOP_OFFICE_WIDTH := 460
const DESKTOP_OFFICE_HEIGHT := 280

# Conversation
const CONVERSATION_TURNS := 4  # exchanges per conversation
const CONVERSATION_LINE_DURATION := 3.0  # seconds to show each speech bubble
