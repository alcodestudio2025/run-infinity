class_name PlayerMovement
extends Node

## Movement component: gravity, jump, coyote time, jump buffer, and slide.

var _player: Player
var _body: CharacterBody2D
var _config: PlayerConfig
var _collision_shape: CollisionShape2D
var _hitbox_shape: RectangleShape2D
var _sprite: Sprite2D
var _default_sprite_scale: Vector2 = Vector2.ONE
var _default_sprite_position: Vector2 = Vector2.ZERO
var _coyote_time_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _slide_time_left: float = 0.0
var _slide_active: bool = false
var _touch_router: TouchGestureRouter
var _touch_router_enabled: bool = false

func setup(player: Player, config: PlayerConfig) -> void:
	_player = player
	_body = player
	_config = config
	_collision_shape = player.get_node("CollisionShape2D") as CollisionShape2D
	_sprite = player.get_node("Sprite2D") as Sprite2D
	_setup_hitbox_shape()
	_setup_sprite_visual()
	_setup_touch_router()

func _physics_process(delta: float) -> void:
	if _body == null or _player == null or _config == null:
		return
	_sync_touch_router_enabled()
	if not _player.is_alive() or not GameStateManager.is_playing():
		return

	## Clamp huge deltas (llvmpipe / hitch) so coyote + jump buffer stay usable.
	var step: float = minf(delta, 0.05)
	_poll_action_input()
	_update_timers(step)
	_update_slide()
	_handle_jump_input()
	_apply_gravity(step)
	_body.move_and_slide()
	_refresh_coyote_time()
	_sync_player_state()


func _poll_action_input() -> void:
	## Physics-frame polling is more reliable than event delivery alone under load.
	if Input.is_action_just_pressed("ui_down"):
		_start_slide()
	if (
		Input.is_action_just_pressed("ui_accept")
		or Input.is_action_just_pressed("ui_up")
	):
		_queue_jump_buffer()


func _unhandled_input(event: InputEvent) -> void:
	if _player == null:
		return

	_sync_touch_router_enabled()

	## Keyboard only while alive + PLAYING; polling remains the reliability path.
	if _player.is_alive() and GameStateManager.is_playing():
		if event.is_action_pressed("ui_down") or _is_slide_key(event):
			_start_slide()
			return

		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_up") or _is_jump_key(event):
			_queue_jump_buffer()
			return

	## Pointer gestures via router (_unhandled_input so UI Controls can consume PLAY).
	if _touch_router != null and _touch_router.handle_input_event(event):
		get_viewport().set_input_as_handled()


func _is_jump_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode in [KEY_SPACE, KEY_W, KEY_UP, KEY_Z]


func _is_slide_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode in [KEY_S, KEY_DOWN, KEY_C]


func _setup_touch_router() -> void:
	if _touch_router != null:
		return
	_touch_router = TouchGestureRouter.new()
	_touch_router.name = "TouchGestureRouter"
	add_child(_touch_router)
	_touch_router.jump_requested.connect(_on_touch_jump_requested)
	_touch_router.slide_requested.connect(_on_touch_slide_requested)
	_touch_router_enabled = false
	_touch_router.set_enabled(false)
	_sync_touch_router_enabled()


func _sync_touch_router_enabled() -> void:
	if _touch_router == null:
		return
	var should_enable: bool = (
		_player != null
		and _player.is_alive()
		and GameStateManager.is_playing()
	)
	if should_enable and not _touch_router_enabled:
		_touch_router.reset()
	_touch_router.set_enabled(should_enable)
	_touch_router_enabled = should_enable


func _on_touch_jump_requested() -> void:
	## Apply immediately when legal so touch jump is not deferred to the next
	## physics frame (release→buffer→_physics_process was a perceptible lag).
	if _player == null or not _player.is_alive() or not GameStateManager.is_playing():
		return
	if _is_sliding():
		return
	if _can_jump():
		_perform_jump()
	else:
		_queue_jump_buffer()


func _on_touch_slide_requested() -> void:
	if _player == null or not _player.is_alive() or not GameStateManager.is_playing():
		return
	_start_slide()

func _handle_jump_input() -> void:
	if _is_sliding() or _jump_buffer_left <= 0.0:
		return
	if not _can_jump():
		return
	_perform_jump()

func request_jump() -> void:
	_queue_jump_buffer()


func request_slide() -> void:
	_start_slide()


func _queue_jump_buffer() -> void:
	if not _is_sliding():
		_jump_buffer_left = _config.jump_buffer_time

func _can_jump() -> bool:
	return _body.is_on_floor() or _coyote_time_left > 0.0

func _perform_jump() -> void:
	## Prefer GameConfig so runtime tuning always wins over stale Resource defaults.
	_body.velocity.y = -GameConfig.PLAYER_JUMP_VELOCITY
	_coyote_time_left = 0.0
	_jump_buffer_left = 0.0
	_player.set_state(PlayerState.State.JUMPING)
	EventBus.player_jumped.emit()
	if GameConfig.DEBUG_LOG:
		print_debug("JUMP at y=%0.1f" % _body.global_position.y)

func _start_slide() -> void:
	if not _can_slide():
		return
	_slide_time_left = _config.slide_duration
	_slide_active = true
	_jump_buffer_left = 0.0
	_apply_hitbox(_config.sliding_hitbox_size, _config.sliding_hitbox_position)
	_apply_sliding_visual()
	_player.set_state(PlayerState.State.SLIDING)
	EventBus.player_slid.emit()

func _can_slide() -> bool:
	return _body.is_on_floor() and not _is_sliding() and _player.is_alive()

func _update_slide() -> void:
	if not _is_sliding():
		return
	if _slide_time_left > 0.0:
		_player.set_state(PlayerState.State.SLIDING)
		return
	_apply_hitbox(_config.standing_hitbox_size, _config.standing_hitbox_position)
	_apply_standing_visual()
	_slide_active = false

func _is_sliding() -> bool:
	return _slide_active


func reset_to_standing() -> void:
	_coyote_time_left = 0.0
	_jump_buffer_left = 0.0
	_slide_time_left = 0.0
	_slide_active = false
	if _touch_router != null:
		_touch_router.reset()
	_apply_hitbox(_config.standing_hitbox_size, _config.standing_hitbox_position)
	_apply_standing_visual()


func _apply_gravity(delta: float) -> void:
	if _body.is_on_floor() and _body.velocity.y > 0.0:
		_body.velocity.y = 0.0
		return
	_body.velocity.y += GameConfig.PLAYER_GRAVITY * delta
	_body.velocity.y = minf(_body.velocity.y, GameConfig.PLAYER_MAX_FALL_SPEED)

func _update_timers(delta: float) -> void:
	if _coyote_time_left > 0.0:
		_coyote_time_left = maxf(_coyote_time_left - delta, 0.0)
	if _jump_buffer_left > 0.0:
		_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
	if _slide_time_left > 0.0:
		_slide_time_left = maxf(_slide_time_left - delta, 0.0)

func _refresh_coyote_time() -> void:
	if _body.is_on_floor():
		_coyote_time_left = _config.coyote_time

func _sync_player_state() -> void:
	if not _player.is_alive() or _is_sliding():
		return
	if _body.is_on_floor():
		_player.set_state(PlayerState.State.RUNNING)
		return
	if _body.velocity.y < 0.0:
		_player.set_state(PlayerState.State.JUMPING)
		return
	_player.set_state(PlayerState.State.FALLING)

func _setup_hitbox_shape() -> void:
	if _collision_shape == null:
		return
	_hitbox_shape = _collision_shape.shape as RectangleShape2D
	if _hitbox_shape == null:
		_hitbox_shape = RectangleShape2D.new()
		_collision_shape.shape = _hitbox_shape
	else:
		_hitbox_shape = _hitbox_shape.duplicate() as RectangleShape2D
		_collision_shape.shape = _hitbox_shape
	_apply_hitbox(_config.standing_hitbox_size, _config.standing_hitbox_position)

func _apply_hitbox(size: Vector2, position: Vector2) -> void:
	if _collision_shape == null or _hitbox_shape == null:
		return
	_hitbox_shape.size = size
	_collision_shape.position = position


func _setup_sprite_visual() -> void:
	if _sprite == null:
		return
	_default_sprite_scale = _sprite.scale
	_default_sprite_position = _sprite.position
	_apply_standing_visual()


func _apply_sliding_visual() -> void:
	if _sprite == null:
		return
	_sprite.scale = _config.sliding_sprite_scale
	_sprite.position = _config.sliding_sprite_position


func _apply_standing_visual() -> void:
	if _sprite == null:
		return
	_sprite.scale = _default_sprite_scale
	_sprite.position = _default_sprite_position
