class_name WorldVelocityController
extends Node

## Drives horizontal world scroll speed and run distance.
## Instantiated by GameScene; Grapple release may apply a capped speed burst.

var current_speed: float = 0.0
var target_speed: float = 0.0
var max_speed: float = GameConfig.MAX_WORLD_SPEED
## Ceiling for current_speed while a Grapple boost window is active.
var max_boost_speed: float = GameConfig.MAX_BOOST_WORLD_SPEED
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
	if not is_finite(speed):
		return
	target_speed = clampf(speed, 0.0, max_speed)


func add_speed_bonus(amount: float) -> void:
	if not is_finite(amount):
		return
	set_target_speed(target_speed + amount)


## Grapple release: convert forward impulse into a short scroll-speed burst.
## amount is px/s added to current_speed; decays back toward target over duration.
## Effective speed is hard-capped at max_boost_speed (never stacks past the ceiling).
func apply_speed_boost(amount: float, duration: float) -> void:
	if not is_finite(amount) or not is_finite(duration):
		return
	if amount <= 0.0 or duration <= 0.0:
		return
	var ceiling: float = maxf(max_boost_speed, max_speed)
	var before: float = current_speed
	current_speed = minf(current_speed + amount, ceiling)
	var applied: float = current_speed - before
	if applied <= 0.0:
		## Already at ceiling — still refresh decay window so feel stays snappy.
		_boost_time_left = maxf(_boost_time_left, duration)
		_boost_decay_per_sec = maxf(_boost_decay_per_sec, amount / duration)
		return
	_boost_time_left = duration
	_boost_decay_per_sec = applied / duration


func get_boost_time_left() -> float:
	return _boost_time_left


func is_boost_active() -> bool:
	return _boost_time_left > 0.0


func physics_update(delta: float) -> void:
	if not _is_running:
		return
	if not is_finite(delta) or delta <= 0.0:
		return

	var accel: float = acceleration
	if _boost_time_left > 0.0:
		_boost_time_left = maxf(_boost_time_left - delta, 0.0)
		## Pull down faster while the boost window is active so we don't stay overspeed.
		accel = maxf(acceleration, _boost_decay_per_sec)

	current_speed = _move_toward(current_speed, target_speed, accel * delta)
	current_speed = _sanitize_speed(current_speed)
	distance_travelled += current_speed * delta
	if not is_finite(distance_travelled) or distance_travelled < 0.0:
		distance_travelled = 0.0


func _clear_boost() -> void:
	_boost_time_left = 0.0
	_boost_decay_per_sec = 0.0


func _sanitize_speed(speed: float) -> float:
	if not is_finite(speed) or speed < 0.0:
		return 0.0
	var ceiling: float = max_boost_speed if _boost_time_left > 0.0 else max_speed
	ceiling = maxf(ceiling, max_speed)
	return minf(speed, ceiling)


func _move_toward(current: float, target: float, step: float) -> float:
	if current < target:
		return minf(current + step, target)
	if current > target:
		return maxf(current - step, target)
	return current
