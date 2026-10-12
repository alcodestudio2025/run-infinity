class_name WorldVelocityController
extends Node

## Drives horizontal world scroll speed and run distance.
## Instantiated by GameScene; not wired to gameplay systems yet.

var current_speed: float = 0.0
var target_speed: float = 0.0
var max_speed: float = GameConfig.MAX_WORLD_SPEED
var acceleration: float = GameConfig.WORLD_ACCELERATION
var distance_travelled: float = 0.0

var _is_running: bool = false


func start_run() -> void:
	_is_running = true
	target_speed = GameConfig.BASE_WORLD_SPEED


func stop_run() -> void:
	_is_running = false
	target_speed = 0.0
	current_speed = 0.0


func reset() -> void:
	_is_running = false
	current_speed = 0.0
	target_speed = 0.0
	distance_travelled = 0.0


func set_target_speed(speed: float) -> void:
	target_speed = clampf(speed, 0.0, max_speed)


func add_speed_bonus(amount: float) -> void:
	set_target_speed(target_speed + amount)


func physics_update(delta: float) -> void:
	if not _is_running:
		return

	current_speed = _move_toward(current_speed, target_speed, acceleration * delta)
	distance_travelled += current_speed * delta


func _move_toward(current: float, target: float, step: float) -> float:
	if current < target:
		return minf(current + step, target)
	if current > target:
		return maxf(current - step, target)
	return current
