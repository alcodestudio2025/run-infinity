class_name DeterministicGrappleSimulator
extends GrappleSimulator

## Deterministic fixed-dt Grapple swing + latch attach for headless smokes.
## Implements the GrappleSimulator contract used by GrappleController, and also
## exposes a standalone try_attach / sample API for pure sim tests (M5.0 Agent B).
## Not wired into live PlayerMovement.

const LatchQuery := preload("res://scripts/grapple/GrappleLatchQuery.gd")
const SimConfig := preload("res://scripts/grapple/GrappleSimConfig.gd")

enum Phase {
	IDLE,
	ATTACHED,
	RELEASED,
}

var config: RefCounted

var phase: int = Phase.IDLE
var player_pos: Vector2 = Vector2.ZERO
var player_vel: Vector2 = Vector2.ZERO

## Mutable latch positions in the same space as player_pos (scrolled each step).
var latch_positions: Array[Vector2] = []

var attached_latch_index: int = -1
var attached_latch_pos: Vector2 = Vector2.ZERO
var rope_length: float = 0.0
var start_angle: float = 0.0
var end_angle: float = 0.0
var swing_elapsed: float = 0.0

## Auto-release fires at most once per attach cycle.
var release_fired: bool = false
var release_count: int = 0
var last_release_velocity: Vector2 = Vector2.ZERO

var attach_attempts: int = 0
var attach_successes: int = 0
var attach_misses: int = 0

var sim_time: float = 0.0
var sim_steps: int = 0

## When true, step() advances free-flight after release (standalone sim mode).
## Controller mode resets via reset() immediately after release impulse.
var _standalone_mode: bool = true
var _params: GrappleSwingParams = GrappleSwingParams.from_config()


func _init(p_config: RefCounted = null) -> void:
	config = p_config if p_config != null else SimConfig.new()
	reset()


# -- GrappleSimulator contract (controller) ------------------------------------


func begin_swing(
	anchor: Vector2,
	player_position: Vector2,
	initial_velocity: Vector2,
	params: GrappleSwingParams,
) -> void:
	_standalone_mode = false
	_params = params if params != null else GrappleSwingParams.from_config()
	player_pos = player_position
	player_vel = initial_velocity
	latch_positions = [anchor]
	_begin_attach(0, anchor)
	## Override rope length / duration from swing params when provided.
	if _params.rope_length > 0.0:
		rope_length = _params.rope_length
		_place_on_rope(0.0)
	if _params.max_duration_sec > 0.0:
		config.set("swing_duration", clampf(_params.max_duration_sec, 0.35, 0.55))


func step(delta: float = -1.0) -> void:
	var step_dt: float = float(SimConfig.FIXED_DT) if delta < 0.0 else delta
	if step_dt <= 0.0:
		return

	match phase:
		Phase.IDLE:
			if _standalone_mode:
				_scroll_latches(step_dt)
		Phase.ATTACHED:
			if _standalone_mode:
				_scroll_latches(step_dt)
			else:
				## Controller owns world scroll; keep anchor fixed during swing.
				pass
			_step_swing(step_dt)
		Phase.RELEASED:
			if _standalone_mode:
				_scroll_latches(step_dt)
				_step_free(step_dt)

	sim_time += step_dt
	sim_steps += 1


func get_player_position() -> Vector2:
	return player_pos


func get_player_velocity() -> Vector2:
	return player_vel


func get_anchor_position() -> Vector2:
	return attached_latch_pos


func get_rope_angle() -> float:
	if phase != Phase.ATTACHED:
		return 0.0
	var offset: Vector2 = player_pos - attached_latch_pos
	return atan2(offset.x, offset.y)


func get_rope_length() -> float:
	return rope_length


func get_elapsed_sec() -> float:
	return swing_elapsed


func is_active() -> bool:
	return phase == Phase.ATTACHED


func should_auto_release() -> bool:
	if phase != Phase.ATTACHED:
		return false
	if release_fired:
		return true
	var min_dur: float = _params.min_duration_sec if not _standalone_mode else 0.0
	if swing_elapsed < min_dur:
		return false
	var duration: float = maxf(float(config.get("swing_duration")), 0.0001)
	return swing_elapsed >= duration


func compute_release_impulse() -> Vector2:
	if last_release_velocity != Vector2.ZERO:
		return last_release_velocity
	if phase != Phase.ATTACHED:
		return Vector2.ZERO
	## Preview launch without mutating phase (controller will call reset).
	var duration: float = maxf(float(config.get("swing_duration")), 0.0001)
	var u: float = clampf(swing_elapsed / duration, 0.0, 1.0)
	var angle: float = lerpf(start_angle, end_angle, _smoothstep(u))
	var u_sample: float = 0.92
	var deased: float = _smoothstep_derivative(u_sample)
	var omega: float = (end_angle - start_angle) * deased / duration
	var tangential: Vector2 = Vector2(-sin(angle), cos(angle)) * rope_length * omega
	var boost := Vector2(
		float(config.get("release_forward_boost")),
		-float(config.get("release_upward_boost")),
	)
	return tangential + boost


func reset() -> void:
	phase = Phase.IDLE
	player_pos = Vector2.ZERO
	player_vel = Vector2.ZERO
	latch_positions.clear()
	attached_latch_index = -1
	attached_latch_pos = Vector2.ZERO
	rope_length = 0.0
	start_angle = 0.0
	end_angle = 0.0
	swing_elapsed = 0.0
	release_fired = false
	release_count = 0
	last_release_velocity = Vector2.ZERO
	attach_attempts = 0
	attach_successes = 0
	attach_misses = 0
	sim_time = 0.0
	sim_steps = 0
	_standalone_mode = true
	_params = GrappleSwingParams.from_config()


# -- Standalone sim API (smokes) -----------------------------------------------


func reset_after_death(spawn_pos: Vector2 = Vector2.ZERO) -> void:
	reset()
	player_pos = spawn_pos


func set_player_state(pos: Vector2, vel: Vector2 = Vector2.ZERO) -> void:
	player_pos = pos
	player_vel = vel


func set_latches(positions: Array) -> void:
	latch_positions.clear()
	for p in positions:
		latch_positions.append(p as Vector2)


func add_latch(pos: Vector2) -> void:
	latch_positions.append(pos)


func try_attach() -> bool:
	_standalone_mode = true
	attach_attempts += 1
	if phase == Phase.ATTACHED:
		attach_misses += 1
		return false

	var result: Dictionary = LatchQuery.find_best_latch(player_pos, latch_positions, config)
	if not bool(result.get("ok", false)):
		attach_misses += 1
		return false

	_begin_attach(int(result["index"]), result["position"] as Vector2)
	attach_successes += 1
	return true


func step_n(n: int, dt: float = -1.0) -> void:
	for _i in range(maxi(n, 0)):
		step(dt)


func sample() -> Dictionary:
	return {
		"phase": phase,
		"player_pos": player_pos,
		"player_vel": player_vel,
		"attached_latch_index": attached_latch_index,
		"attached_latch_pos": attached_latch_pos,
		"rope_length": rope_length,
		"start_angle": start_angle,
		"end_angle": end_angle,
		"swing_elapsed": swing_elapsed,
		"release_fired": release_fired,
		"release_count": release_count,
		"last_release_velocity": last_release_velocity,
		"attach_attempts": attach_attempts,
		"attach_successes": attach_successes,
		"attach_misses": attach_misses,
		"sim_time": sim_time,
		"sim_steps": sim_steps,
		"latch_count": latch_positions.size(),
		"latch_positions": latch_positions.duplicate(),
	}


func is_idle() -> bool:
	return phase == Phase.IDLE


func is_attached() -> bool:
	return phase == Phase.ATTACHED


func is_released() -> bool:
	return phase == Phase.RELEASED


# -- Internals -----------------------------------------------------------------


func _begin_attach(index: int, latch_pos: Vector2) -> void:
	phase = Phase.ATTACHED
	attached_latch_index = index
	attached_latch_pos = latch_pos
	rope_length = player_pos.distance_to(latch_pos)
	if rope_length < 0.001:
		rope_length = float(config.get("min_attach_radius"))
	start_angle = atan2(player_pos.y - latch_pos.y, player_pos.x - latch_pos.x)
	end_angle = start_angle + float(config.get("swing_arc_radians"))
	swing_elapsed = 0.0
	release_fired = false
	player_vel = Vector2.ZERO
	_place_on_rope(0.0)


func _scroll_latches(dt: float) -> void:
	var dx: float = float(config.get("scroll_speed")) * dt
	if dx == 0.0:
		return
	for i in range(latch_positions.size()):
		latch_positions[i] = latch_positions[i] + Vector2(-dx, 0.0)
	if phase == Phase.ATTACHED and attached_latch_index >= 0 and attached_latch_index < latch_positions.size():
		attached_latch_pos = latch_positions[attached_latch_index]


func _step_swing(dt: float) -> void:
	var duration: float = maxf(float(config.get("swing_duration")), 0.0001)
	swing_elapsed = minf(swing_elapsed + dt, duration)
	var u: float = clampf(swing_elapsed / duration, 0.0, 1.0)
	_place_on_rope(u)

	if swing_elapsed >= duration and not release_fired:
		_auto_release(u)


func _place_on_rope(u: float) -> void:
	var eased: float = _smoothstep(u)
	var angle: float = lerpf(start_angle, end_angle, eased)
	player_pos = attached_latch_pos + Vector2(cos(angle), sin(angle)) * rope_length
	var duration: float = maxf(float(config.get("swing_duration")), 0.0001)
	var du_dt: float = 1.0 / duration
	var deased_du: float = _smoothstep_derivative(u)
	var omega: float = (end_angle - start_angle) * deased_du * du_dt
	player_vel = Vector2(-sin(angle), cos(angle)) * rope_length * omega


func _auto_release(u: float) -> void:
	release_fired = true
	release_count += 1
	phase = Phase.RELEASED

	var angle: float = lerpf(start_angle, end_angle, _smoothstep(u))
	var duration: float = maxf(float(config.get("swing_duration")), 0.0001)
	var u_sample: float = 0.92
	var deased: float = _smoothstep_derivative(u_sample)
	var omega: float = (end_angle - start_angle) * deased / duration
	var tangential: Vector2 = Vector2(-sin(angle), cos(angle)) * rope_length * omega
	var boost := Vector2(
		float(config.get("release_forward_boost")),
		-float(config.get("release_upward_boost")),
	)
	last_release_velocity = tangential + boost
	player_vel = last_release_velocity
	attached_latch_index = -1


func _step_free(dt: float) -> void:
	var gravity: float = float(config.get("gravity"))
	if gravity != 0.0:
		player_vel.y += gravity * dt
		var max_fall: float = float(config.get("max_fall_speed"))
		if player_vel.y > max_fall:
			player_vel.y = max_fall
	player_pos += player_vel * dt


static func _smoothstep(u: float) -> float:
	var t: float = clampf(u, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _smoothstep_derivative(u: float) -> float:
	var t: float = clampf(u, 0.0, 1.0)
	return 6.0 * t * (1.0 - t)
