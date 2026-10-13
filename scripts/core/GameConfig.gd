class_name GameConfig
extends RefCounted

## Global tuning values for Run Infinity.
## All future gameplay constants must be added here.

# -- Display & timing ----------------------------------------------------------

const TARGET_FPS: int = 60
const VIEWPORT_WIDTH: float = 1920.0
const VIEWPORT_HEIGHT: float = 1080.0

## When true, GameState / run lifecycle prints appear in Output.
const DEBUG_LOG: bool = false

# -- World movement ------------------------------------------------------------

## Tuned for a ~30–60s run: start at base, ease toward max over distance.
const BASE_WORLD_SPEED: float = 340.0
const MAX_WORLD_SPEED: float = 620.0
## How fast current_speed chases target_speed (px/s²).
const WORLD_ACCELERATION: float = 180.0
## Distance at which target speed reaches MAX_WORLD_SPEED.
const SPEED_RAMP_DISTANCE: float = 9000.0


static func get_target_speed_for_distance(distance: float) -> float:
	var t: float = clampf(distance / SPEED_RAMP_DISTANCE, 0.0, 1.0)
	## Ease-out so early pace stays readable.
	t = 1.0 - (1.0 - t) * (1.0 - t)
	return lerpf(BASE_WORLD_SPEED, MAX_WORLD_SPEED, t)

# -- Segment system (runner engine) --------------------------------------------

const SEGMENT_LENGTH: float = VIEWPORT_WIDTH
const SEGMENT_GROUND_HEIGHT: float = 40.0
const SEGMENT_ACTIVE_COUNT: int = 4
const SEGMENT_RECYCLE_MARGIN: float = 64.0
## First N segments spawn no obstacles so the player can settle and learn jump.
const SAFE_START_SEGMENT_COUNT: int = 4
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


## Low curb-style hazard: easy to clear, still punishes standing into it.
const OBSTACLE_SIZE: Vector2 = Vector2(70.0, 48.0)
const OBSTACLE_LOCAL_X_RATIO: float = 0.20
const OBSTACLE_LOCAL_Y: float = -24.0
const OBSTACLE_COLOR: Color = Color(0.85, 0.2, 0.2, 1.0)

## Tall curb: same footing, needs a committed jump.
const TALL_OBSTACLE_SIZE: Vector2 = Vector2(64.0, 96.0)
const TALL_OBSTACLE_LOCAL_X_RATIO: float = 0.18
const TALL_OBSTACLE_LOCAL_Y: float = -48.0
const TALL_OBSTACLE_COLOR: Color = Color(0.78, 0.28, 0.12, 1.0)

## Overhead bar: standing hits it; slide duck clears by geometry.
const OVERHEAD_OBSTACLE_SIZE: Vector2 = Vector2(140.0, 52.0)
const OVERHEAD_OBSTACLE_LOCAL_X_RATIO: float = 0.22
const OVERHEAD_OBSTACLE_LOCAL_Y: float = -96.0
const OVERHEAD_OBSTACLE_COLOR: Color = Color(0.55, 0.15, 0.55, 1.0)

## Double curb spacing inside one segment (local x ratios).
const DOUBLE_CURB_LOCAL_X_RATIOS: Array[float] = [-0.28, 0.28]

## Coin collectible.
const COIN_SIZE: Vector2 = Vector2(36.0, 36.0)
const COIN_LOCAL_Y: float = -110.0
const COIN_COLOR: Color = Color(0.95, 0.78, 0.15, 1.0)
const COIN_SCORE_VALUE: int = 250
const COIN_LOCAL_X_RATIOS: Array[float] = [-0.15, 0.0, 0.35]


static func get_obstacle_local_position(segment_length: float) -> Vector2:
	return Vector2(segment_length * OBSTACLE_LOCAL_X_RATIO, OBSTACLE_LOCAL_Y)


static func get_tall_obstacle_local_position(segment_length: float) -> Vector2:
	return Vector2(segment_length * TALL_OBSTACLE_LOCAL_X_RATIO, TALL_OBSTACLE_LOCAL_Y)


static func get_overhead_obstacle_local_position(segment_length: float) -> Vector2:
	return Vector2(segment_length * OVERHEAD_OBSTACLE_LOCAL_X_RATIO, OVERHEAD_OBSTACLE_LOCAL_Y)


static func get_coin_local_position(segment_length: float, slot_index: int = 0) -> Vector2:
	var ratios: Array[float] = COIN_LOCAL_X_RATIOS
	var ratio: float = ratios[slot_index % ratios.size()]
	return Vector2(segment_length * ratio, COIN_LOCAL_Y)


static func get_double_curb_local_positions(segment_length: float) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for ratio: float in DOUBLE_CURB_LOCAL_X_RATIOS:
		positions.append(Vector2(segment_length * ratio, OBSTACLE_LOCAL_Y))
	return positions

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

# -- Player movement (jump feel) -----------------------------------------------

## High, readable arc with lots of clearance over curb obstacles.
const PLAYER_GRAVITY: float = 1500.0
const PLAYER_JUMP_VELOCITY: float = 980.0
const PLAYER_MAX_FALL_SPEED: float = 1400.0

# -- Player input grace windows (seconds) ------------------------------------

## Generous windows so slow/cloud FPS (large deltas) still feel fair.
const COYOTE_TIME: float = 0.22
const JUMP_BUFFER: float = 0.20
const SLIDE_DURATION: float = 0.40
const SLIDE_INPUT_DRAG_THRESHOLD: float = 72.0

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
## ~3–4s per level at base speed so module mix evolves over a 30–60s run.
const DIFFICULTY_DISTANCE_PER_LEVEL: float = 1400.0
const DIFFICULTY_FACTOR_PER_LEVEL: float = 0.10

## Hazard segment stride shrinks with level (3 → 2 → 1).
const HAZARD_STRIDE_BASE: int = 3
const HAZARD_STRIDE_MIN: int = 1
const TALL_OBSTACLE_UNLOCK_LEVEL: int = 2
const OVERHEAD_OBSTACLE_UNLOCK_LEVEL: int = 4
const DOUBLE_CURB_UNLOCK_LEVEL: int = 6
const COIN_SPAWN_START_LEVEL: int = 1

# -- Scoring -------------------------------------------------------------------

## Score is distance scaled; coins add a flat bonus via GameScene.
const SCORE_PER_DISTANCE: float = 1.0


static func distance_to_score(distance: float) -> int:
	return int(floor(maxf(distance, 0.0) * SCORE_PER_DISTANCE))
