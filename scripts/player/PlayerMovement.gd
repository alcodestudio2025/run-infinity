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
var _drag_start_position: Vector2 = Vector2.ZERO
var _drag_active: bool = false

func setup(player: Player, config: PlayerConfig) -> void:
	_player = player
	_body = player
	_config = config
	_collision_shape = player.get_node("CollisionShape2D") as CollisionShape2D
	_sprite = player.get_node("Sprite2D") as Sprite2D
	_setup_hitbox_shape()
	_setup_sprite_visual()

func _physics_process(delta: float) -> void:
	if _body == null or _player == null or _config == null:
		return
	if not _player.is_alive() or not GameStateManager.is_playing():
		return
	_update_timers(delta)
	_update_slide()
	_handle_jump_input()
	_apply_gravity(delta)
	_body.velocity.y = minf(_body.velocity.y, _config.max_fall_speed)
	_body.move_and_slide()
	_refresh_coyote_time()
	_sync_player_state()

func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not _player.is_alive() or not GameStateManager.is_playing():
		return
	if event.is_action_pressed("ui_down"):
		_start_slide()
	if event.is_action_pressed("ui_accept"):
		_queue_jump_buffer()
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_handle_pointer_input(mouse_event.pressed, mouse_event.position)
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		_handle_pointer_input(touch_event.pressed, touch_event.position)

func _handle_pointer_input(pressed: bool, position: Vector2) -> void:
	if pressed:
		_drag_start_position = position
		_drag_active = true
		return
	if _drag_active and not _try_slide_from_drag(position):
		_queue_jump_buffer()
	_drag_active = false

func _try_slide_from_drag(end_position: Vector2) -> bool:
	var drag_delta: Vector2 = end_position - _drag_start_position
	if drag_delta.y < _config.slide_input_drag_threshold:
		return false
	if absf(drag_delta.y) <= absf(drag_delta.x):
		return false
	_start_slide()
	return true

func _handle_jump_input() -> void:
	if _is_sliding() or _jump_buffer_left <= 0.0:
		return
	if not _can_jump():
		return
	_perform_jump()

func _queue_jump_buffer() -> void:
	if not _is_sliding():
		_jump_buffer_left = _config.jump_buffer_time

func _can_jump() -> bool:
	return _body.is_on_floor() or _coyote_time_left > 0.0

func _perform_jump() -> void:
	_body.velocity.y = -_config.jump_velocity
	_coyote_time_left = 0.0
	_jump_buffer_left = 0.0
	_player.set_state(PlayerState.State.JUMPING)
	EventBus.player_jumped.emit()

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
	_drag_active = false
	_apply_hitbox(_config.standing_hitbox_size, _config.standing_hitbox_position)
	_apply_standing_visual()


func _apply_gravity(delta: float) -> void:
	if _body.is_on_floor() and _body.velocity.y > 0.0:
		_body.velocity.y = 0.0
		return
	_body.velocity.y += _config.gravity * delta

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
