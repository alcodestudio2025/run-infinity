class_name RunLoop
extends Node

## Physics tick bridge between run state and world/difficulty systems.
## Holds no gameplay logic; only forwards updates while a run is active.

var _velocity_controller: WorldVelocityController
var _difficulty_director: DifficultyDirector
var _is_active: bool = true


func setup(
	velocity_controller: WorldVelocityController,
	difficulty_director: DifficultyDirector,
) -> void:
	_velocity_controller = velocity_controller
	_difficulty_director = difficulty_director
	_is_active = true


func stop() -> void:
	_is_active = false


func start() -> void:
	_is_active = true


func _physics_process(delta: float) -> void:
	if not _is_active or not GameStateManager.is_playing():
		return

	if _velocity_controller == null or _difficulty_director == null:
		return

	_difficulty_director.update_difficulty(_velocity_controller.distance_travelled)
	_velocity_controller.set_target_speed(
		GameConfig.get_target_speed_for_distance(_velocity_controller.distance_travelled)
	)
	_velocity_controller.physics_update(delta)
