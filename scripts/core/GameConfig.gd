class_name GameConfig
extends RefCounted

## Global tuning values for Run Infinity.
## All future gameplay constants must be added here.

# -- Display & timing ----------------------------------------------------------

const TARGET_FPS: int = 60
const VIEWPORT_WIDTH: float = 1920.0
const VIEWPORT_HEIGHT: float = 1080.0

# -- World movement ------------------------------------------------------------

const BASE_WORLD_SPEED: float = 280.0
const MAX_WORLD_SPEED: float = 720.0
const WORLD_ACCELERATION: float = 48.0

# -- Segment system (runner engine) --------------------------------------------

const SEGMENT_LENGTH: float = VIEWPORT_WIDTH
const SEGMENT_GROUND_HEIGHT: float = 40.0
const SEGMENT_ACTIVE_COUNT: int = 4
const SEGMENT_RECYCLE_MARGIN: float = 64.0
const MODULE_PLACEHOLDER_MAX_COUNT: int = 2
const MODULE_PLACEHOLDER_LOCAL_Y: float = -90.0

static func get_module_placeholder_local_x_ratios() -> Array[float]:
	return [-0.35, 0.35]


static func get_module_placeholder_local_position(
	slot_index: int,
	segment_length: float,
) -> Vector2:
	var ratios: Array[float] = get_module_placeholder_local_x_ratios()
	var ratio: float = ratios[slot_index % ratios.size()]
	return Vector2(segment_length * ratio, MODULE_PLACEHOLDER_LOCAL_Y)


const OBSTACLE_SIZE: Vector2 = Vector2(80.0, 120.0)
const OBSTACLE_LOCAL_X_RATIO: float = 0.15
const OBSTACLE_LOCAL_Y: float = -60.0
const OBSTACLE_COLOR: Color = Color(0.85, 0.2, 0.2, 1.0)


static func get_obstacle_local_position(segment_length: float) -> Vector2:
	return Vector2(segment_length * OBSTACLE_LOCAL_X_RATIO, OBSTACLE_LOCAL_Y)

# -- Layout (landscape reference: 1920x1080) -----------------------------------

## Vertical position of the ground surface in world space.
const GROUND_SURFACE_RATIO: float = 0.85
const GROUND_Y: float = VIEWPORT_HEIGHT * GROUND_SURFACE_RATIO

## Horizontal screen position ratio for the player (0.0 = left, 1.0 = right).
const PLAYER_SCREEN_RATIO: float = 0.28

## Distance from ground surface to player origin when standing.
const PLAYER_FEET_OFFSET: float = 32.0

## Camera world limits relative to the reference viewport.
const CAMERA_WORLD_WIDTH_MULTIPLIER: float = 2.0
const CAMERA_TOP_LIMIT: float = 0.0

# -- Player input grace windows (seconds) ------------------------------------

const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.10
const SLIDE_DURATION: float = 0.45
const SLIDE_INPUT_DRAG_THRESHOLD: float = 80.0

# -- Player collision ---------------------------------------------------------

const PLAYER_STANDING_HITBOX_SIZE: Vector2 = Vector2(48.0, 72.0)
const PLAYER_STANDING_HITBOX_POSITION: Vector2 = Vector2(0.0, -4.0)
const PLAYER_SLIDING_HITBOX_SIZE: Vector2 = Vector2(64.0, 38.0)
const PLAYER_SLIDING_HITBOX_POSITION: Vector2 = Vector2(0.0, 13.0)

# -- Player visuals (placeholder, no dedicated animation assets) ---------------

const PLAYER_SPRITE_SLIDING_SCALE: Vector2 = Vector2(0.48, 0.16)
const PLAYER_SPRITE_SLIDING_POSITION: Vector2 = Vector2(0.0, 22.0)

static func get_segment_ground_colors() -> Array[Color]:
	return [
		Color(0.32, 0.42, 0.30),
		Color(0.40, 0.50, 0.36),
		Color(0.36, 0.46, 0.32),
		Color(0.44, 0.54, 0.40),
	]

# -- Progression ---------------------------------------------------------------

const SWING_UNLOCK_DISTANCE: float = 500.0
const DIFFICULTY_DISTANCE_PER_LEVEL: float = 150.0
const DIFFICULTY_FACTOR_PER_LEVEL: float = 0.1
