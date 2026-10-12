class_name DifficultyDirector
extends Node

## Scales difficulty from travelled distance only.
## Does not reference chunks, player, or persistence systems.

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


func _calculate_difficulty_factor(level: int) -> float:
	return 1.0 + float(level) * GameConfig.DIFFICULTY_FACTOR_PER_LEVEL
