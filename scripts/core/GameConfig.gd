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

## Tuned for a ~30–60s run: accessible start, clearly rising pace, stable max.
const BASE_WORLD_SPEED: float = 340.0
const MAX_WORLD_SPEED: float = 620.0
## Hard ceiling while a Grapple release boost is active (distinct from progression max).
## Keeps repeated boosts from stacking into uncontrolled scroll speed.
const MAX_BOOST_WORLD_SPEED: float = 900.0
## How fast current_speed chases target_speed (px/s²). Higher = more perceptible ramp.
const WORLD_ACCELERATION: float = 220.0
## Distance to reach MAX_WORLD_SPEED along the ease curve (shorter = earlier peak).
const SPEED_RAMP_DISTANCE: float = 9000.0
## Ease exponent for speed curve (>1 = slower early rise, sharper late).
const SPEED_RAMP_EASE_POWER: float = 1.35


static func get_target_speed_for_distance(distance: float) -> float:
	var t: float = clampf(distance / SPEED_RAMP_DISTANCE, 0.0, 1.0)
	## Configurable ease-out: early pace readable, mid-run acceleration feels real.
	var p: float = maxf(SPEED_RAMP_EASE_POWER, 1.0)
	t = 1.0 - pow(1.0 - t, p)
	return lerpf(BASE_WORLD_SPEED, MAX_WORLD_SPEED, t)


## Minimum reaction window (seconds) at max progression speed for one segment gap.
static func min_reaction_window_sec() -> float:
	return SEGMENT_LENGTH / maxf(MAX_WORLD_SPEED, 1.0)

# -- Segment system (runner engine) --------------------------------------------

const SEGMENT_LENGTH: float = VIEWPORT_WIDTH
const SEGMENT_GROUND_HEIGHT: float = 40.0
const SEGMENT_ACTIVE_COUNT: int = 4
const SEGMENT_RECYCLE_MARGIN: float = 64.0
## First N segments spawn no obstacles so the player can settle and learn jump.
## Keep short so the first curb arrives while speed is still mid-ramp.
const SAFE_START_SEGMENT_COUNT: int = 2
const MODULE_PLACEHOLDER_MAX_COUNT: int = 2
const MODULE_PLACEHOLDER_LOCAL_Y: float = -90.0
## Early hazard slots forced to low curb (segment index inclusive).
const EARLY_LOW_CURB_SEGMENT_MAX: int = 5

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
const OBSTACLE_SIZE: Vector2 = Vector2(52.0, 36.0)
const OBSTACLE_LOCAL_X_RATIO: float = 0.12
const OBSTACLE_LOCAL_Y: float = -18.0
const OBSTACLE_COLOR: Color = Color(0.85, 0.2, 0.2, 1.0)
## Feet above standing origin by this much counts as jump-clear (floor check alone is flaky).
const JUMP_CLEAR_HEIGHT: float = 28.0

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

## Coin collectible — multiple readable lanes (ground / jump / Grapple arc).
const COIN_SIZE: Vector2 = Vector2(36.0, 36.0)
const COIN_LOCAL_Y: float = -130.0
const COIN_COLOR: Color = Color(0.95, 0.78, 0.15, 1.0)
## Flat bonus; sized so a teach sequence (~6–10 coins) is meaningful vs distance score.
const COIN_SCORE_VALUE: int = 300
const COIN_LOCAL_X_RATIOS: Array[float] = [-0.32, 0.05, 0.38]
## Lane Y relative to segment center (reachable: stand / jump / swing).
const COIN_LANE_GROUND_Y: float = -56.0
const COIN_LANE_JUMP_Y: float = -130.0
const COIN_LANE_GRAPPLE_Y: float = -210.0
## How many coins in a teach sequence on consecutive gap slots.
const COIN_SEQUENCE_LENGTH: int = 3
## Compatible coins on hazard/latch slices (keeps rewards when stride→1 kills gap slots).
## Period/offset are deterministic — no RNG. Does not remove hazards.
const COIN_COMPAT_PERIOD: int = 3
const COIN_COMPAT_OFFSET: int = 0
## Lane indices: 0 ground (slide), 1 jump, 2 grapple.
const COIN_LANE_GROUND: int = 0
const COIN_LANE_JUMP: int = 1
const COIN_LANE_GRAPPLE: int = 2
## X-slot indices into COIN_LOCAL_X_RATIOS for clearances vs obstacle anchors.
const COIN_SLOT_LEFT: int = 0 ## -0.32
const COIN_SLOT_MID: int = 1 ## 0.05
const COIN_SLOT_RIGHT: int = 2 ## 0.38

## Grapple latch (non-hazard): cyan diamond + amber ring, above jump-apex zone.
## Local Y is relative to segment center (ground_y + ground_height/2).
## -220 ≈ 220px above ground center (within 180–280 teachable band).
const LATCH_SIZE: Vector2 = Vector2(40.0, 40.0)
const LATCH_LOCAL_X_RATIO: float = 0.0
const LATCH_LOCAL_Y: float = -220.0
const LATCH_COLOR: Color = Color(0.12, 0.88, 0.92, 1.0)
const LATCH_RING_COLOR: Color = Color(1.0, 0.72, 0.18, 1.0)
const LATCH_POINT_RADIUS: float = 14.0
## Early controlled sequence: denser teach beat after SAFE_START.
## Prefer non-hazard slots at base stride 3 (avoid %3==0) so first curb stays on 3.
const LATCH_SEGMENT_INDICES: Array[int] = [4, 5, 8, 10, 11, 14]
## After the early list, spawn on stride gaps at this offset (≠ coin slot 1).
const LATCH_GAP_OFFSET: int = 2
## When true, early LATCH_SEGMENT_INDICES always spawn (ignore unlock gate).
const FORCE_LATCH_SEQUENCE: bool = true


static func get_obstacle_local_position(segment_length: float) -> Vector2:
	return Vector2(segment_length * OBSTACLE_LOCAL_X_RATIO, OBSTACLE_LOCAL_Y)


static func get_tall_obstacle_local_position(segment_length: float) -> Vector2:
	return Vector2(segment_length * TALL_OBSTACLE_LOCAL_X_RATIO, TALL_OBSTACLE_LOCAL_Y)


static func get_overhead_obstacle_local_position(segment_length: float) -> Vector2:
	return Vector2(segment_length * OVERHEAD_OBSTACLE_LOCAL_X_RATIO, OVERHEAD_OBSTACLE_LOCAL_Y)


static func get_coin_local_position(segment_length: float, slot_index: int = 0) -> Vector2:
	return get_coin_local_position_for_lane(segment_length, slot_index, COIN_LANE_JUMP_Y)


static func get_coin_lane_y(lane_index: int) -> float:
	match lane_index % 3:
		0:
			return COIN_LANE_GROUND_Y
		1:
			return COIN_LANE_JUMP_Y
		_:
			return COIN_LANE_GRAPPLE_Y


static func get_coin_local_position_for_lane(
	segment_length: float,
	slot_index: int,
	lane_y: float,
) -> Vector2:
	var ratios: Array[float] = COIN_LOCAL_X_RATIOS
	var ratio: float = ratios[slot_index % ratios.size()]
	return Vector2(segment_length * ratio, lane_y)


static func get_latch_local_position(segment_length: float) -> Vector2:
	return Vector2(segment_length * LATCH_LOCAL_X_RATIO, LATCH_LOCAL_Y)


static func get_double_curb_local_positions(segment_length: float) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for ratio: float in DOUBLE_CURB_LOCAL_X_RATIOS:
		positions.append(Vector2(segment_length * ratio, OBSTACLE_LOCAL_Y))
	return positions


static func is_early_latch_segment(segment_index: int) -> bool:
	return segment_index in LATCH_SEGMENT_INDICES


## First hazard segment index at base stride (used by smokes / docs).
static func get_first_hazard_segment_index() -> int:
	var index: int = SAFE_START_SEGMENT_COUNT
	while index % HAZARD_STRIDE_BASE != 0:
		index += 1
	return index


## Approximate scroll distance when the player meets the first low curb.
static func estimate_first_hazard_distance() -> float:
	var index: int = get_first_hazard_segment_index()
	var center_x: float = float(index) * SEGMENT_LENGTH + SEGMENT_LENGTH * 0.5
	var obstacle_x: float = center_x + SEGMENT_LENGTH * OBSTACLE_LOCAL_X_RATIO
	var player_x: float = VIEWPORT_WIDTH * PLAYER_SCREEN_RATIO
	return maxf(obstacle_x - player_x, 0.0)


static func get_player_standing_y() -> float:
	return GROUND_Y - PLAYER_FEET_OFFSET


## True when the player is high enough (or not on floor) to clear a ground curb.
static func is_jump_clearing_curb(player: Node2D) -> bool:
	if player == null:
		return false
	if player is CharacterBody2D and not (player as CharacterBody2D).is_on_floor():
		return true
	var standing_y: float = get_player_standing_y()
	return player.global_position.y <= standing_y - JUMP_CLEAR_HEIGHT

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
const PLAYER_GRAVITY: float = 1350.0
## Applied only while falling (velocity.y > 0) so ascent stays similar.
const PLAYER_FALL_GRAVITY_MULT: float = 1.55
const PLAYER_JUMP_VELOCITY: float = 1050.0
const PLAYER_MAX_FALL_SPEED: float = 1600.0
## Empty Grapple miss cast visual duration (seconds); physics unchanged.
const GRAPPLE_MISS_CAST_SEC: float = 0.22

# -- Player input grace windows (seconds) ------------------------------------

## Generous windows so slow/cloud FPS (large deltas) still feel fair.
const COYOTE_TIME: float = 0.26
const JUMP_BUFFER: float = 0.24
const SLIDE_DURATION: float = 0.45
const SLIDE_INPUT_DRAG_THRESHOLD: float = 64.0

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
## ~3s per level at mid speed so module mix evolves over a 30–60s run.
const DIFFICULTY_DISTANCE_PER_LEVEL: float = 1200.0
const DIFFICULTY_FACTOR_PER_LEVEL: float = 0.12

## Hazard segment stride shrinks with level (3 → 2 → 1).
const HAZARD_STRIDE_BASE: int = 3
const HAZARD_STRIDE_MIN: int = 1
## Levels per stride shrink step (DifficultyDirector).
const HAZARD_STRIDE_SHRINK_LEVELS: int = 2
const TALL_OBSTACLE_UNLOCK_LEVEL: int = 1
const OVERHEAD_OBSTACLE_UNLOCK_LEVEL: int = 1
const DOUBLE_CURB_UNLOCK_LEVEL: int = 4
const COIN_SPAWN_START_LEVEL: int = 0
## Latches teach Grapple early; level 0 so the controlled sequence is reachable.
const LATCH_UNLOCK_LEVEL: int = 0
const HAZARD_PATTERN_MOD: int = 10
const OVERHEAD_PATTERN_ROLLS: Array[int] = [1, 3, 6, 8]
const TALL_PATTERN_ROLLS: Array[int] = [2, 5, 9]
const DOUBLE_PATTERN_ROLL: int = 7

# -- Scoring -------------------------------------------------------------------

## Score is distance scaled; coins add a flat bonus via GameScene.
const SCORE_PER_DISTANCE: float = 1.0


static func distance_to_score(distance: float) -> int:
	return int(floor(maxf(distance, 0.0) * SCORE_PER_DISTANCE))
