class_name GrappleController
extends RefCounted

## Focused Grapple ability runtime (not a generic ability framework).
## Usable from tests; not auto-attached to the player scene in M5.0.
## Independent of TouchGestureRouter / jump-slide classification —
## host code calls request_air_ability() when an air-ability intent arrives.
##
## Path: res://scripts/grapple/GrappleController.gd

signal air_ability_requested
signal state_changed(from_phase: int, to_phase: int)
signal seek_failed
signal attached(latch: LatchPoint)
signal released(impulse: Vector2)
## Emitted when host should apply simulator pose while ATTACHED.
signal swing_pose_updated(position: Vector2, velocity: Vector2)

var _phase: int = GrappleState.Phase.IDLE
var _simulator: GrappleSimulator = NullGrappleSimulator.new()
var _latch_provider: LatchProvider = LatchProvider.new()
var _swing_params: GrappleSwingParams = GrappleSwingParams.from_config()
var _host: GrappleHostSnapshot = GrappleHostSnapshot.new()
var _active_latch: LatchPoint = null
var _seek_elapsed: float = 0.0
var _attach_elapsed: float = 0.0
var _release_elapsed: float = 0.0
var _pending_impulse: Vector2 = Vector2.ZERO
var _armed: bool = true


func set_simulator(simulator: GrappleSimulator) -> void:
	if simulator == null:
		_simulator = NullGrappleSimulator.new()
	else:
		_simulator = simulator


func get_simulator() -> GrappleSimulator:
	return _simulator


func set_latch_provider(provider: LatchProvider) -> void:
	_latch_provider = provider if provider != null else LatchProvider.new()


func get_latch_provider() -> LatchProvider:
	return _latch_provider


func set_swing_params(params: GrappleSwingParams) -> void:
	_swing_params = params if params != null else GrappleSwingParams.from_config()


func get_swing_params() -> GrappleSwingParams:
	return _swing_params


## Feed player pose/flags each frame (or before request / process).
func update_host(snapshot: GrappleHostSnapshot) -> void:
	if snapshot != null:
		_host = snapshot


func update_host_values(
	position: Vector2,
	velocity: Vector2,
	is_airborne: bool,
	is_alive: bool = true,
) -> void:
	_host = GrappleHostSnapshot.new(position, velocity, is_airborne, is_alive)


func get_phase() -> int:
	return _phase


func get_state_name() -> String:
	match _phase:
		GrappleState.Phase.IDLE:
			return "IDLE"
		GrappleState.Phase.SEEKING:
			return "SEEKING"
		GrappleState.Phase.ATTACHED:
			return "ATTACHED"
		GrappleState.Phase.RELEASED:
			return "RELEASED"
		_:
			return "UNKNOWN"


func get_active_latch() -> LatchPoint:
	return _active_latch


func is_busy() -> bool:
	return _phase != GrappleState.Phase.IDLE


func set_armed(armed: bool) -> void:
	_armed = armed


func is_armed() -> bool:
	return _armed


func can_request_air_ability() -> bool:
	if not _armed:
		return false
	if _phase != GrappleState.Phase.IDLE:
		return false
	if not _host.is_alive:
		return false
	return _host.is_airborne


## Air-ability request API — NOT jump/slide classification.
## Returns true if the request was accepted and seeking began.
func request_air_ability() -> bool:
	air_ability_requested.emit()
	if not can_request_air_ability():
		return false
	_begin_seeking()
	return true


func process(delta: float) -> void:
	var dt: float = maxf(delta, 0.0)
	match _phase:
		GrappleState.Phase.SEEKING:
			_process_seeking(dt)
		GrappleState.Phase.ATTACHED:
			_process_attached(dt)
		GrappleState.Phase.RELEASED:
			_process_released(dt)
		_:
			pass


## Force attach to a known latch (tests / future scripted hooks).
func force_attach(latch: LatchPoint) -> bool:
	if latch == null:
		return false
	if _phase != GrappleState.Phase.IDLE and _phase != GrappleState.Phase.SEEKING:
		return false
	_attach_to(latch)
	return true


## Manual release (cancel). Auto-release is preferred in normal play.
func release_now() -> void:
	if _phase != GrappleState.Phase.ATTACHED:
		return
	_begin_release(_resolve_release_impulse())


## Death / restart — clear all Grapple state.
func reset() -> void:
	var previous: int = _phase
	_phase = GrappleState.Phase.IDLE
	_active_latch = null
	_seek_elapsed = 0.0
	_attach_elapsed = 0.0
	_release_elapsed = 0.0
	_pending_impulse = Vector2.ZERO
	_armed = true
	_simulator.reset()
	if previous != GrappleState.Phase.IDLE:
		state_changed.emit(previous, GrappleState.Phase.IDLE)


func get_pending_release_impulse() -> Vector2:
	return _pending_impulse


# -- Internals -----------------------------------------------------------------


func _set_phase(next: int) -> void:
	if next == _phase:
		return
	var previous: int = _phase
	_phase = next
	state_changed.emit(previous, next)


func _begin_seeking() -> void:
	_seek_elapsed = 0.0
	_active_latch = null
	_set_phase(GrappleState.Phase.SEEKING)
	if GrappleConfig.SEEK_SAME_FRAME:
		_try_select_latch()


func _process_seeking(delta: float) -> void:
	_seek_elapsed += delta
	if _try_select_latch():
		return
	if _seek_elapsed >= GrappleConfig.SEEK_TIMEOUT_SEC:
		seek_failed.emit()
		_set_phase(GrappleState.Phase.IDLE)


func _try_select_latch() -> bool:
	var candidates: Array[LatchPoint] = _latch_provider.collect_latches()
	var best: LatchPoint = LatchSelector.select_best(_host.position, candidates)
	if best == null:
		return false
	_attach_to(best)
	return true


func _attach_to(latch: LatchPoint) -> void:
	_active_latch = latch.duplicate_point()
	_attach_elapsed = 0.0
	var rope_length: float = _swing_params.rope_length
	if rope_length <= 0.0:
		rope_length = _host.position.distance_to(latch.position)
	var params: GrappleSwingParams = _copy_params_with_length(rope_length)
	_simulator.begin_swing(
		latch.position,
		_host.position,
		_host.velocity,
		params,
	)
	_set_phase(GrappleState.Phase.ATTACHED)
	attached.emit(_active_latch)


func _copy_params_with_length(rope_length: float) -> GrappleSwingParams:
	var params := GrappleSwingParams.from_config()
	params.rope_length = rope_length
	params.gravity = _swing_params.gravity
	params.damping = _swing_params.damping
	params.max_swing_angle = _swing_params.max_swing_angle
	params.release_angle = _swing_params.release_angle
	params.prefer_forward_release = _swing_params.prefer_forward_release
	params.max_duration_sec = _swing_params.max_duration_sec
	params.min_duration_sec = _swing_params.min_duration_sec
	return params


func _process_attached(delta: float) -> void:
	_attach_elapsed += delta
	_simulator.step(delta)
	swing_pose_updated.emit(_simulator.get_player_position(), _simulator.get_player_velocity())

	var past_min: bool = _attach_elapsed >= GrappleConfig.MIN_ATTACH_DURATION_SEC
	var hard_cap: bool = _attach_elapsed >= GrappleConfig.MAX_ATTACH_DURATION_SEC
	var sim_release: bool = past_min and _simulator.should_auto_release()
	if hard_cap or sim_release:
		_begin_release(_resolve_release_impulse())


func _resolve_release_impulse() -> Vector2:
	var impulse: Vector2 = _simulator.compute_release_impulse()
	if impulse == Vector2.ZERO:
		impulse = GrappleConfig.DEFAULT_RELEASE_IMPULSE
	return impulse


func _begin_release(impulse: Vector2) -> void:
	_pending_impulse = impulse
	_release_elapsed = 0.0
	_simulator.reset()
	_set_phase(GrappleState.Phase.RELEASED)
	released.emit(impulse)


func _process_released(delta: float) -> void:
	_release_elapsed += delta
	if _release_elapsed >= GrappleConfig.RELEASE_SETTLE_SEC:
		_active_latch = null
		_pending_impulse = Vector2.ZERO
		_set_phase(GrappleState.Phase.IDLE)
