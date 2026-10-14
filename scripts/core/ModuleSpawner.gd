class_name ModuleSpawner
extends Node

## Attaches obstacle / collectible / latch modules to segments.
## Pattern mix and density come from DifficultyDirector; no chunk prefabs.
## Latches use a controlled early sequence (not RNG) so Grapple is learnable.

const OBSTACLE_SCENE: PackedScene = preload("res://scenes/modules/ObstacleModule.tscn")
const TALL_OBSTACLE_SCENE: PackedScene = preload("res://scenes/modules/TallObstacleModule.tscn")
const OVERHEAD_OBSTACLE_SCENE: PackedScene = preload(
	"res://scenes/modules/OverheadObstacleModule.tscn"
)
const COIN_SCENE: PackedScene = preload("res://scenes/modules/CoinModule.tscn")
const LATCH_SCENE: PackedScene = preload("res://scenes/modules/LatchModule.tscn")

enum HazardPattern {
	LOW_CURB,
	TALL_CURB,
	OVERHEAD,
	DOUBLE_CURB,
}

var _difficulty: DifficultyDirector
## One-shot smoke helper: next populate_segment attaches a latch (then clears).
var _force_latch_on_next: bool = false


func setup(difficulty_director: DifficultyDirector) -> void:
	_difficulty = difficulty_director


## Smoke / debug: force a latch on the next populate_segment call.
func debug_force_latch_on_next() -> void:
	_force_latch_on_next = true


## Documented early latch indices (mirrors GameConfig.LATCH_SEGMENT_INDICES).
func get_latch_spawn_indices() -> Array[int]:
	return GameConfig.LATCH_SEGMENT_INDICES.duplicate()


func populate_segment(segment: Segment, segment_index: int) -> void:
	if segment == null:
		return

	var module_root: Node2D = segment.get_module_root()
	if module_root == null:
		push_error("ModuleSpawner: segment is missing ModuleRoot.")
		return

	## Safe start: no hazards while the player settles on the first slices.
	## Forced latch bypasses safe-start so smokes can inject without scrolling.
	if _force_latch_on_next:
		_force_latch_on_next = false
		_attach_latch(segment, module_root)
		return

	if segment_index < GameConfig.SAFE_START_SEGMENT_COUNT:
		return

	var stride: int = _get_hazard_stride()

	## Dedicated latch slot (non-hazard): never stack with curbs / overhead.
	if _should_attach_latch(segment_index, stride):
		_attach_latch(segment, module_root)
		## Optional grapple-lane coin beside the latch (not inside the diamond).
		if _should_attach_compat_coin(segment_index):
			_attach_compat_coin(
				segment,
				module_root,
				GameConfig.COIN_LANE_GRAPPLE,
				GameConfig.COIN_SLOT_RIGHT,
			)
		return

	var is_hazard_slot: bool = segment_index % stride == 0

	if is_hazard_slot:
		var pattern: HazardPattern = _pick_hazard_pattern(segment_index)
		_attach_hazard_pattern(segment, module_root, pattern)
		## Compatible coin on the clear path for this hazard — preserves density.
		if _should_attach_compat_coin(segment_index):
			_attach_compat_coin_for_hazard(segment, module_root, pattern, segment_index)
		return

	## Gap coins when stride leaves empty slices (stride > 1).
	if _can_coins() and _is_coin_gap_slot(segment_index, stride):
		_attach_coin_sequence(segment, module_root, segment_index)


func _get_hazard_stride() -> int:
	if _difficulty != null:
		return _difficulty.get_hazard_stride()
	return GameConfig.HAZARD_STRIDE_BASE


func _can_coins() -> bool:
	if _difficulty != null:
		return _difficulty.can_spawn_coin()
	return false


func _can_latch() -> bool:
	if GameConfig.FORCE_LATCH_SEQUENCE:
		return true
	if _difficulty != null:
		return _difficulty.can_spawn_latch()
	return GameConfig.LATCH_UNLOCK_LEVEL <= 0


func _should_attach_latch(segment_index: int, stride: int) -> bool:
	if not _can_latch():
		return false

	## Controlled early sequence always wins (dedicated latch slot, no hazard/coin).
	## Wins even if stride has shrunk so index % stride == 0 — teach beat > curb.
	if GameConfig.is_early_latch_segment(segment_index):
		return true

	## Continuing pattern after the teach list: every 2×stride at LATCH_GAP_OFFSET.
	## Never stack with a hazard slot (avoids mid-swing overhead kills).
	if stride <= 0 or segment_index % stride == 0:
		return false
	var last_early: int = GameConfig.LATCH_SEGMENT_INDICES[
		GameConfig.LATCH_SEGMENT_INDICES.size() - 1
	]
	if segment_index <= last_early:
		return false
	var period: int = stride * 2
	return segment_index % period == GameConfig.LATCH_GAP_OFFSET


func _is_coin_gap_slot(segment_index: int, stride: int) -> bool:
	## Gap coins need stride > 1 (stride 1 has no remainder slots).
	if stride <= 1:
		return false
	## Coins on non-hazard segments immediately after a hazard beat.
	return segment_index % stride == 1


func _should_attach_compat_coin(segment_index: int) -> bool:
	if not _can_coins():
		return false
	var period: int = maxi(GameConfig.COIN_COMPAT_PERIOD, 1)
	return segment_index % period == GameConfig.COIN_COMPAT_OFFSET


func _attach_hazard(
	segment: Segment,
	module_root: Node2D,
	segment_index: int,
) -> void:
	_attach_hazard_pattern(segment, module_root, _pick_hazard_pattern(segment_index))


func _attach_hazard_pattern(
	segment: Segment,
	module_root: Node2D,
	pattern: HazardPattern,
) -> void:
	match pattern:
		HazardPattern.TALL_CURB:
			_attach_tall_obstacle(segment, module_root)
		HazardPattern.OVERHEAD:
			_attach_overhead_obstacle(segment, module_root)
		HazardPattern.DOUBLE_CURB:
			_attach_double_curb(segment, module_root)
		_:
			_attach_low_curb(segment, module_root)


func _attach_compat_coin_for_hazard(
	segment: Segment,
	module_root: Node2D,
	pattern: HazardPattern,
	segment_index: int,
) -> void:
	## Lane + X chosen so the clear action still collects (never inside the hazard AABB).
	var lane: int = GameConfig.COIN_LANE_JUMP
	var slot: int = GameConfig.COIN_SLOT_RIGHT
	match pattern:
		HazardPattern.OVERHEAD:
			## Slide clear → ground lane, X clear of overhead anchor (0.22).
			lane = GameConfig.COIN_LANE_GROUND
			slot = (
				GameConfig.COIN_SLOT_LEFT
				if segment_index % 2 == 0
				else GameConfig.COIN_SLOT_RIGHT
			)
		HazardPattern.DOUBLE_CURB:
			## Jump between the pair (−0.28 / 0.28) at mid X.
			lane = GameConfig.COIN_LANE_JUMP
			slot = GameConfig.COIN_SLOT_MID
		HazardPattern.TALL_CURB:
			## Committed jump; place ahead/behind tall anchor (0.18).
			lane = GameConfig.COIN_LANE_JUMP
			slot = (
				GameConfig.COIN_SLOT_LEFT
				if segment_index % 2 == 0
				else GameConfig.COIN_SLOT_RIGHT
			)
		_:
			## Low curb: jump arc over curb (0.12) toward right slot.
			lane = GameConfig.COIN_LANE_JUMP
			slot = GameConfig.COIN_SLOT_RIGHT
	_attach_compat_coin(segment, module_root, lane, slot)


func _attach_compat_coin(
	segment: Segment,
	module_root: Node2D,
	lane_index: int,
	slot_index: int,
) -> void:
	_attach_coin_at_lane(segment, module_root, slot_index, lane_index)


func _pick_hazard_pattern(segment_index: int) -> HazardPattern:
	## Deterministic mix from segment index + unlock gates (stable for smoke).
	var level: int = 0
	if _difficulty != null:
		level = _difficulty.current_level

	## Early run stays readable: only low curbs until the player learns the jump.
	## After EARLY_LOW_CURB, allow overhead/tall so SLIDE/JUMP variety appears soon.
	if segment_index <= GameConfig.EARLY_LOW_CURB_SEGMENT_MAX:
		return HazardPattern.LOW_CURB

	var roll: int = segment_index % GameConfig.HAZARD_PATTERN_MOD
	if (
		_difficulty != null
		and _difficulty.can_spawn_double_curb()
		and roll == GameConfig.DOUBLE_PATTERN_ROLL
	):
		return HazardPattern.DOUBLE_CURB
	if (
		_difficulty != null
		and _difficulty.can_spawn_overhead()
		and roll in GameConfig.OVERHEAD_PATTERN_ROLLS
	):
		return HazardPattern.OVERHEAD
	if (
		_difficulty != null
		and _difficulty.can_spawn_tall()
		and roll in GameConfig.TALL_PATTERN_ROLLS
	):
		return HazardPattern.TALL_CURB

	## Mild level bias toward taller threats without RNG.
	if level >= GameConfig.TALL_OBSTACLE_UNLOCK_LEVEL and roll == 4:
		return HazardPattern.TALL_CURB

	return HazardPattern.LOW_CURB


func _attach_low_curb(segment: Segment, module_root: Node2D) -> void:
	var module: ObstacleModule = OBSTACLE_SCENE.instantiate() as ObstacleModule
	if module == null:
		push_error("ModuleSpawner: failed to instantiate ObstacleModule.")
		return

	var local_position: Vector2 = GameConfig.get_obstacle_local_position(
		segment.get_length()
	)
	module_root.add_child(module)
	module.setup({"local_position": local_position})
	module.activate()


func _attach_tall_obstacle(segment: Segment, module_root: Node2D) -> void:
	var module: TallObstacleModule = TALL_OBSTACLE_SCENE.instantiate() as TallObstacleModule
	if module == null:
		push_error("ModuleSpawner: failed to instantiate TallObstacleModule.")
		return

	var local_position: Vector2 = GameConfig.get_tall_obstacle_local_position(
		segment.get_length()
	)
	module_root.add_child(module)
	module.setup({"local_position": local_position})
	module.activate()


func _attach_overhead_obstacle(segment: Segment, module_root: Node2D) -> void:
	var module: OverheadObstacleModule = (
		OVERHEAD_OBSTACLE_SCENE.instantiate() as OverheadObstacleModule
	)
	if module == null:
		push_error("ModuleSpawner: failed to instantiate OverheadObstacleModule.")
		return

	var local_position: Vector2 = GameConfig.get_overhead_obstacle_local_position(
		segment.get_length()
	)
	module_root.add_child(module)
	module.setup({"local_position": local_position})
	module.activate()


func _attach_double_curb(segment: Segment, module_root: Node2D) -> void:
	var positions: Array[Vector2] = GameConfig.get_double_curb_local_positions(
		segment.get_length()
	)
	for local_position: Vector2 in positions:
		var module: ObstacleModule = OBSTACLE_SCENE.instantiate() as ObstacleModule
		if module == null:
			push_error("ModuleSpawner: failed to instantiate ObstacleModule (double).")
			continue
		module_root.add_child(module)
		module.setup({"local_position": local_position})
		module.activate()


func _attach_latch(segment: Segment, module_root: Node2D) -> void:
	var module: LatchModule = LATCH_SCENE.instantiate() as LatchModule
	if module == null:
		push_error("ModuleSpawner: failed to instantiate LatchModule.")
		return

	var local_position: Vector2 = GameConfig.get_latch_local_position(
		segment.get_length()
	)
	module_root.add_child(module)
	module.setup({"local_position": local_position})
	module.activate()


func _attach_coin_sequence(segment: Segment, module_root: Node2D, segment_index: int) -> void:
	## One primary coin per gap segment; lane rotates so runs show ground/jump/grapple arcs.
	## Sequence feel: consecutive gaps use consecutive lanes / x slots.
	var lane: int = segment_index % 3
	var slot: int = segment_index % GameConfig.COIN_LOCAL_X_RATIOS.size()
	_attach_coin_at_lane(segment, module_root, slot, lane)

	## Occasional second coin on the same segment (jump+ground pair) — never on overhead.
	if segment_index % 5 == 0:
		var alt_lane: int = (lane + 1) % 3
		var alt_slot: int = (slot + 1) % GameConfig.COIN_LOCAL_X_RATIOS.size()
		_attach_coin_at_lane(segment, module_root, alt_slot, alt_lane)


func _attach_coin_at_lane(
	segment: Segment,
	module_root: Node2D,
	slot_index: int,
	lane_index: int,
) -> void:
	var module: CoinModule = COIN_SCENE.instantiate() as CoinModule
	if module == null:
		push_error("ModuleSpawner: failed to instantiate CoinModule.")
		return

	var lane_y: float = GameConfig.get_coin_lane_y(lane_index)
	var local_position: Vector2 = GameConfig.get_coin_local_position_for_lane(
		segment.get_length(),
		slot_index,
		lane_y,
	)
	module_root.add_child(module)
	module.setup({
		"local_position": local_position,
		"value": GameConfig.COIN_SCORE_VALUE,
	})
	module.activate()


## Smoke helper: classify what populate_segment would attach (no scene required).
## Primary kind only — use debug_segment_has_coin for co-placed rewards.
func debug_classify_segment(segment_index: int, stride: int = -1) -> StringName:
	if segment_index < GameConfig.SAFE_START_SEGMENT_COUNT:
		return &"safe"
	var use_stride: int = stride if stride > 0 else _get_hazard_stride()
	if _should_attach_latch(segment_index, use_stride):
		return &"latch"
	if segment_index % use_stride == 0:
		var pattern: HazardPattern = _pick_hazard_pattern(segment_index)
		match pattern:
			HazardPattern.OVERHEAD:
				return &"overhead"
			HazardPattern.TALL_CURB:
				return &"tall"
			HazardPattern.DOUBLE_CURB:
				return &"double"
			_:
				return &"low"
	if _can_coins() and _is_coin_gap_slot(segment_index, use_stride):
		return &"coin"
	return &"empty"


## True when a gap coin or compatible co-placed coin would spawn.
func debug_segment_has_coin(segment_index: int, stride: int = -1) -> bool:
	if segment_index < GameConfig.SAFE_START_SEGMENT_COUNT:
		return false
	if not _can_coins():
		return false
	var use_stride: int = stride if stride > 0 else _get_hazard_stride()
	if _should_attach_latch(segment_index, use_stride):
		return _should_attach_compat_coin(segment_index)
	if segment_index % use_stride == 0:
		return _should_attach_compat_coin(segment_index)
	return _is_coin_gap_slot(segment_index, use_stride)


## Lane for co-placed / gap coin (−1 if none). 0 ground, 1 jump, 2 grapple.
func debug_segment_coin_lane(segment_index: int, stride: int = -1) -> int:
	if not debug_segment_has_coin(segment_index, stride):
		return -1
	var use_stride: int = stride if stride > 0 else _get_hazard_stride()
	if _should_attach_latch(segment_index, use_stride):
		return GameConfig.COIN_LANE_GRAPPLE
	if segment_index % use_stride == 0:
		var pattern: HazardPattern = _pick_hazard_pattern(segment_index)
		match pattern:
			HazardPattern.OVERHEAD:
				return GameConfig.COIN_LANE_GROUND
			HazardPattern.DOUBLE_CURB:
				return GameConfig.COIN_LANE_JUMP
			HazardPattern.TALL_CURB:
				return GameConfig.COIN_LANE_JUMP
			_:
				return GameConfig.COIN_LANE_JUMP
	## Gap sequence rotates lanes.
	return segment_index % 3
