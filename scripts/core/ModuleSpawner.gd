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
		return

	var is_hazard_slot: bool = segment_index % stride == 0

	if is_hazard_slot:
		_attach_hazard(segment, module_root, segment_index)
		return

	## Coins only on gap segments — never stacked on the same slice as a hazard.
	if _can_coins() and _is_coin_gap_slot(segment_index, stride):
		_attach_coin(segment, module_root, segment_index % 3)


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

	## Continuing pattern after the teach list: stride + LATCH_GAP_OFFSET gaps.
	## Never stack with a hazard slot (avoids mid-swing overhead kills).
	if stride <= 0 or segment_index % stride == 0:
		return false
	var last_early: int = GameConfig.LATCH_SEGMENT_INDICES[
		GameConfig.LATCH_SEGMENT_INDICES.size() - 1
	]
	if segment_index <= last_early:
		return false
	return segment_index % stride == GameConfig.LATCH_GAP_OFFSET


func _is_coin_gap_slot(segment_index: int, stride: int) -> bool:
	## Coins on non-hazard segments, not adjacent to the previous hazard slot.
	if segment_index % stride == 1:
		return true
	return false


func _attach_hazard(
	segment: Segment,
	module_root: Node2D,
	segment_index: int,
) -> void:
	var pattern: HazardPattern = _pick_hazard_pattern(segment_index)
	match pattern:
		HazardPattern.TALL_CURB:
			_attach_tall_obstacle(segment, module_root)
		HazardPattern.OVERHEAD:
			_attach_overhead_obstacle(segment, module_root)
		HazardPattern.DOUBLE_CURB:
			_attach_double_curb(segment, module_root)
		_:
			_attach_low_curb(segment, module_root)


func _pick_hazard_pattern(segment_index: int) -> HazardPattern:
	## Deterministic mix from segment index + unlock gates (stable for smoke).
	var level: int = 0
	if _difficulty != null:
		level = _difficulty.current_level

	## Early run stays readable: only low curbs until the player learns the jump.
	if segment_index <= GameConfig.EARLY_LOW_CURB_SEGMENT_MAX:
		return HazardPattern.LOW_CURB

	var roll: int = segment_index % 10
	if (
		_difficulty != null
		and _difficulty.can_spawn_double_curb()
		and roll == 7
	):
		return HazardPattern.DOUBLE_CURB
	if (
		_difficulty != null
		and _difficulty.can_spawn_overhead()
		and roll in [3, 8]
	):
		return HazardPattern.OVERHEAD
	if (
		_difficulty != null
		and _difficulty.can_spawn_tall()
		and roll in [2, 5, 9]
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


func _attach_coin(segment: Segment, module_root: Node2D, slot_index: int) -> void:
	var module: CoinModule = COIN_SCENE.instantiate() as CoinModule
	if module == null:
		push_error("ModuleSpawner: failed to instantiate CoinModule.")
		return

	var local_position: Vector2 = GameConfig.get_coin_local_position(
		segment.get_length(),
		slot_index,
	)
	module_root.add_child(module)
	module.setup({
		"local_position": local_position,
		"value": GameConfig.COIN_SCORE_VALUE,
	})
	module.activate()
