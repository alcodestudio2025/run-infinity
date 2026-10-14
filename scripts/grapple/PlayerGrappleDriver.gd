class_name PlayerGrappleDriver
extends Node

## Live Grapple host owned by PlayerMovement.
## Feeds world poses into GrappleController, applies swing Y (+ small relative X),
## and converts release +X into a WorldVelocityController speed burst.
## Path: res://scripts/grapple/PlayerGrappleDriver.gd

## How long the forward release boost raises scroll speed (seconds).
const RELEASE_SPEED_BOOST_DURATION_SEC: float = 0.35
## Scale of swing arc X applied to the player (1 = full rope X; keep small).
const SWING_POSE_X_SCALE: float = 0.35

var _player: Player = null
var _body: CharacterBody2D = null
var _controller: GrappleController = null
var _simulator: DeterministicGrappleSimulator = null
var _latch_provider: TreeLatchProvider = null
var _velocity_controller: WorldVelocityController = null

var _pose_locked: bool = false
var _attach_player_x: float = 0.0
var _attach_rope_offset_x: float = 0.0
var _rope_line: Line2D = null


func setup(player: Player) -> void:
	_player = player
	_body = player
	_latch_provider = TreeLatchProvider.new()
	_latch_provider.set_tree_root(player)

	## Live: controller mode (scroll_speed=0). WorldScroller owns latch motion.
	var sim_config := GrappleSimConfig.new()
	sim_config.scroll_speed = 0.0
	_simulator = DeterministicGrappleSimulator.new(sim_config)

	_controller = GrappleController.new()
	_controller.set_simulator(_simulator)
	_controller.set_latch_provider(_latch_provider)
	_controller.set_swing_params(GrappleSwingParams.from_config())

	if not _controller.attached.is_connected(_on_attached):
		_controller.attached.connect(_on_attached)
	if not _controller.released.is_connected(_on_released):
		_controller.released.connect(_on_released)
	if not _controller.swing_pose_updated.is_connected(_on_swing_pose_updated):
		_controller.swing_pose_updated.connect(_on_swing_pose_updated)
	if not _controller.seek_failed.is_connected(_on_seek_failed):
		_controller.seek_failed.connect(_on_seek_failed)

	if not EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.connect(_on_player_died)
	if not EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.connect(_on_game_over)

	_ensure_rope_line()
	_resolve_velocity_controller()


func _exit_tree() -> void:
	if _controller != null:
		if _controller.attached.is_connected(_on_attached):
			_controller.attached.disconnect(_on_attached)
		if _controller.released.is_connected(_on_released):
			_controller.released.disconnect(_on_released)
		if _controller.swing_pose_updated.is_connected(_on_swing_pose_updated):
			_controller.swing_pose_updated.disconnect(_on_swing_pose_updated)
		if _controller.seek_failed.is_connected(_on_seek_failed):
			_controller.seek_failed.disconnect(_on_seek_failed)
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)
	if EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.disconnect(_on_game_over)


func get_controller() -> GrappleController:
	return _controller


func is_pose_locked() -> bool:
	return _pose_locked


func is_grappling() -> bool:
	if _controller == null:
		return false
	var phase: int = _controller.get_phase()
	return (
		phase == GrappleState.Phase.SEEKING
		or phase == GrappleState.Phase.ATTACHED
		or phase == GrappleState.Phase.RELEASED
		or _pose_locked
	)


func can_request_air_ability() -> bool:
	if _controller == null or _player == null:
		return false
	if not _player.is_alive() or not GameStateManager.is_playing():
		return false
	_sync_host()
	return _controller.can_request_air_ability()


func request_air_ability() -> bool:
	if _controller == null or _player == null:
		return false
	if not _player.is_alive() or not GameStateManager.is_playing():
		return false
	_sync_host()
	return _controller.request_air_ability()


func reset() -> void:
	_pose_locked = false
	_attach_player_x = 0.0
	_attach_rope_offset_x = 0.0
	if _controller != null:
		_controller.reset()
	_hide_rope()


func _physics_process(delta: float) -> void:
	if _player == null or _controller == null:
		return

	## Title / GAME_OVER / death: clear any stale seek and stop.
	if not _player.is_alive() or not GameStateManager.is_playing():
		if _controller.is_busy() or _pose_locked:
			reset()
		return

	_resolve_velocity_controller()
	_sync_host()
	_controller.process(delta)

	if _pose_locked and _controller.get_phase() == GrappleState.Phase.ATTACHED:
		_apply_swing_pose(
			_simulator.get_player_position(),
			_simulator.get_player_velocity(),
		)
		_update_rope_visual()
	elif _controller.get_phase() != GrappleState.Phase.ATTACHED:
		_hide_rope()


func _sync_host() -> void:
	if _body == null or _controller == null:
		return
	var airborne: bool = not _body.is_on_floor()
	_controller.update_host_values(
		_body.global_position,
		_body.velocity,
		airborne,
		_player.is_alive(),
	)


func _on_attached(latch: LatchPoint) -> void:
	_pose_locked = true
	_attach_player_x = _body.global_position.x
	var latch_pos: Vector2 = latch.position if latch != null else _simulator.get_anchor_position()
	var sim_pos: Vector2 = _simulator.get_player_position()
	_attach_rope_offset_x = sim_pos.x - latch_pos.x
	## Cancel vertical velocity; pose owns Y while attached.
	_body.velocity = Vector2.ZERO
	if _player != null:
		_player.set_state(PlayerState.State.SWINGING)
	EventBus.player_attached_to_anchor.emit(latch_pos)
	_update_rope_visual()


func _on_released(impulse: Vector2) -> void:
	_pose_locked = false
	_hide_rope()
	_apply_release_impulse(impulse)
	if _player != null and _player.is_alive():
		_player.set_state(PlayerState.State.LAUNCHED)
	EventBus.player_released_from_anchor.emit(impulse, false)


func _on_swing_pose_updated(position: Vector2, velocity: Vector2) -> void:
	if not _pose_locked:
		return
	_apply_swing_pose(position, velocity)


func _on_seek_failed() -> void:
	_pose_locked = false
	_hide_rope()


func _on_player_died() -> void:
	reset()


func _on_game_over(_final_score: int, _distance: float) -> void:
	reset()


func _apply_swing_pose(sim_position: Vector2, _sim_velocity: Vector2) -> void:
	if _body == null or _simulator == null:
		return
	var latch_pos: Vector2 = _simulator.get_anchor_position()
	var rope_offset: Vector2 = sim_position - latch_pos
	## Y from world latch + rope (latch Y does not scroll).
	_body.global_position.y = latch_pos.y + rope_offset.y
	## Small relative X for arc feel — do NOT add world scroll as +X velocity.
	var arc_dx: float = (rope_offset.x - _attach_rope_offset_x) * SWING_POSE_X_SCALE
	_body.global_position.x = _attach_player_x + arc_dx
	_body.velocity = Vector2.ZERO


func _apply_release_impulse(impulse: Vector2) -> void:
	if _body == null:
		return
	## Player owns vertical launch; forward (+X) becomes a short world speed burst.
	_body.velocity.y = impulse.y
	_body.velocity.x = 0.0
	var boost_x: float = maxf(impulse.x, 0.0)
	if boost_x > 0.0:
		_resolve_velocity_controller()
		if _velocity_controller != null:
			_velocity_controller.apply_speed_boost(boost_x, RELEASE_SPEED_BOOST_DURATION_SEC)


func _resolve_velocity_controller() -> void:
	if _velocity_controller != null and is_instance_valid(_velocity_controller):
		return
	if _player == null:
		return
	var node: Node = _player.get_parent()
	while node != null:
		var found: Node = node.get_node_or_null("WorldVelocityController")
		if found is WorldVelocityController:
			_velocity_controller = found as WorldVelocityController
			return
		node = node.get_parent()


func _ensure_rope_line() -> void:
	if _rope_line != null or _player == null:
		return
	_rope_line = Line2D.new()
	_rope_line.name = "GrappleRopePlaceholder"
	_rope_line.width = 2.0
	_rope_line.default_color = Color(0.85, 0.85, 0.9, 0.65)
	_rope_line.z_index = 8
	_rope_line.visible = false
	_player.add_child(_rope_line)


func _update_rope_visual() -> void:
	if _rope_line == null or _simulator == null or not _pose_locked:
		return
	var latch_world: Vector2 = _simulator.get_anchor_position()
	## Prefer live node position when the latch still exists in the tree.
	var active: LatchPoint = _controller.get_active_latch() if _controller != null else null
	if active != null and active.source is Node2D and is_instance_valid(active.source):
		latch_world = (active.source as Node2D).global_position
	_rope_line.clear_points()
	_rope_line.add_point(_player.to_local(latch_world))
	_rope_line.add_point(Vector2.ZERO)
	_rope_line.visible = true


func _hide_rope() -> void:
	if _rope_line != null:
		_rope_line.visible = false
		_rope_line.clear_points()
