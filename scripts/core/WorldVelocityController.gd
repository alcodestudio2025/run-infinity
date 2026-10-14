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
## Temporary forward burst from Grapple release (+X → scroll, not player velocity).
var _boost_time_left: float = 0.0
var _boost_decay_per_sec: float = 0.0


func start_run() -> void:
	_is_running = true
	target_speed = GameConfig.BASE_WORLD_SPEED
	## Snap to base so the first seconds feel like a real run, not a crawl.
	current_speed = GameConfig.BASE_WORLD_SPEED
	_clear_boost()


func stop_run() -> void:
	_is_running = false
	target_speed = 0.0
	current_speed = 0.0
	_clear_boost()


func reset() -> void:
	_is_running = false
	current_speed = 0.0
	target_speed = 0.0
	distance_travelled = 0.0
	_clear_boost()


func set_target_speed(speed: float) -> void:
	target_speed = clampf(speed, 0.0, max_speed)


func add_speed_bonus(amount: float) -> void:
	set_target_speed(target_speed + amount)


## Grapple release: convert forward impulse into a short scroll-speed burst.
## amount is px/s added to current_speed; decays back toward target over duration.
func apply_speed_boost(amount: float, duration: float) -> void:
	if amount <= 0.0 or duration <= 0.0:
		return
	current_speed += amount
	_boost_time_left = duration
	_boost_decay_per_sec = amount / duration


func physics_update(delta: float) -> void:
	if not _is_running:
		return

	var accel: float = acceleration
	if _boost_time_left > 0.0:
		_boost_time_left = maxf(_boost_time_left - delta, 0.0)
		## Pull down faster while the boost window is active so we don't stay overspeed.
		accel = maxf(acceleration, _boost_decay_per_sec)

	current_speed = _move_toward(current_speed, target_speed, accel * delta)
	distance_travelled += current_speed * delta


func _clear_boost() -> void:
	_boost_time_left = 0.0
	_boost_decay_per_sec = 0.0


func _move_toward(current: float, target: float, step: float) -> float:
	if current < target:
		return minf(current + step, target)
	if current > target:
		return maxf(current - step, target)
	return current
