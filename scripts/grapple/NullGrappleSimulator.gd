class_name NullGrappleSimulator
extends GrappleSimulator

## Minimal placeholder simulator so GrappleController can be tested without
## Agent B's deterministic integrator. Advances a timer and releases on max duration.
## NOT for live gameplay feel — replace with Agent B's implementation.

var _active: bool = false
var _anchor: Vector2 = Vector2.ZERO
var _player_pos: Vector2 = Vector2.ZERO
var _player_vel: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _params: GrappleSwingParams = GrappleSwingParams.from_config()
var _rope_length: float = 0.0


func begin_swing(
	anchor: Vector2,
	player_position: Vector2,
	initial_velocity: Vector2,
	params: GrappleSwingParams,
) -> void:
	_active = true
	_anchor = anchor
	_player_pos = player_position
	_player_vel = initial_velocity
	_elapsed = 0.0
	_params = params if params != null else GrappleSwingParams.from_config()
	_rope_length = _params.rope_length
	if _rope_length <= 0.0:
		_rope_length = anchor.distance_to(player_position)


func step(delta: float) -> void:
	if not _active:
		return
	_elapsed += maxf(delta, 0.0)
	## Tiny kinematic drift so queries are non-static; real arc is Agent B's job.
	_player_vel.y += _params.gravity * delta * 0.15
	_player_pos += _player_vel * delta * 0.05
	var offset: Vector2 = _player_pos - _anchor
	if offset.length() > 0.001:
		_player_pos = _anchor + offset.normalized() * _rope_length


func get_player_position() -> Vector2:
	return _player_pos


func get_player_velocity() -> Vector2:
	return _player_vel


func get_anchor_position() -> Vector2:
	return _anchor


func get_rope_angle() -> float:
	if not _active:
		return 0.0
	var offset: Vector2 = _player_pos - _anchor
	## Angle from downward vertical (+X = forward).
	return atan2(offset.x, offset.y)


func get_rope_length() -> float:
	return _rope_length


func get_elapsed_sec() -> float:
	return _elapsed


func is_active() -> bool:
	return _active


func should_auto_release() -> bool:
	if not _active:
		return false
	if _elapsed < _params.min_duration_sec:
		return false
	return _elapsed >= _params.max_duration_sec


func compute_release_impulse() -> Vector2:
	if not _active:
		return Vector2.ZERO
	var impulse: Vector2 = _player_vel * 0.25 + GrappleConfig.DEFAULT_RELEASE_IMPULSE
	return impulse


func reset() -> void:
	_active = false
	_anchor = Vector2.ZERO
	_player_pos = Vector2.ZERO
	_player_vel = Vector2.ZERO
	_elapsed = 0.0
	_rope_length = 0.0
	_params = GrappleSwingParams.from_config()
