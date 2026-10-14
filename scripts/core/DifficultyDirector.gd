class_name DifficultyDirector
extends Node

## Scales difficulty from travelled distance only.
## Exposes spawn-facing helpers for ModuleSpawner (stride + unlock tiers).

var current_level: int = 0
var difficulty_factor: float = 1.0
var distance: float = 0.0


func reset() -> void:
	current_level = 0
	difficulty_factor = 1.0
	distance = 0.0


func update_difficulty(new_distance: float) -> void:
	distance = maxf(new_distance, 0.0)

	var new_level: int = int(
		floor(distance / GameConfig.DIFFICULTY_DISTANCE_PER_LEVEL)
	)
	difficulty_factor = _calculate_difficulty_factor(new_level)

	if new_level == current_level:
		return

	current_level = new_level
	EventBus.difficulty_increased.emit(current_level)


func get_hazard_stride() -> int:
	## Shrinks every HAZARD_STRIDE_SHRINK_LEVELS (default 2): 3 → 2 → 1.
	var step: int = maxi(GameConfig.HAZARD_STRIDE_SHRINK_LEVELS, 1)
	var shrink: int = current_level / step
	return maxi(
		GameConfig.HAZARD_STRIDE_MIN,
		GameConfig.HAZARD_STRIDE_BASE - shrink,
	)


func can_spawn_tall() -> bool:
	return current_level >= GameConfig.TALL_OBSTACLE_UNLOCK_LEVEL


func can_spawn_overhead() -> bool:
	return current_level >= GameConfig.OVERHEAD_OBSTACLE_UNLOCK_LEVEL


func can_spawn_double_curb() -> bool:
	return current_level >= GameConfig.DOUBLE_CURB_UNLOCK_LEVEL


func can_spawn_coin() -> bool:
	return current_level >= GameConfig.COIN_SPAWN_START_LEVEL


func can_spawn_latch() -> bool:
	return current_level >= GameConfig.LATCH_UNLOCK_LEVEL


func _calculate_difficulty_factor(level: int) -> float:
	return 1.0 + float(level) * GameConfig.DIFFICULTY_FACTOR_PER_LEVEL
