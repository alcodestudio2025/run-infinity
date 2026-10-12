class_name CameraRig
extends Node2D

## Camera container with optional follow, zoom, and shake.
## Does not depend on Player or gameplay systems.

const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.0

@export var follow_offset: Vector2 = Vector2.ZERO
@export var smoothing_speed: float = 8.0

@onready var _camera: Camera2D = $Camera2D

var _follow_target: Node2D
var _screen_anchor_ratio: float = 0.5
var _use_screen_anchor: bool = false
var _default_position: Vector2 = Vector2.ZERO
var _default_zoom: Vector2 = Vector2.ONE
var _target_zoom: float = 1.0
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_elapsed: float = 0.0


func _ready() -> void:
	_default_position = global_position
	_default_zoom = _camera.zoom
	_target_zoom = _camera.zoom.x
	_camera.make_current()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = smoothing_speed


func _physics_process(delta: float) -> void:
	_update_follow(delta)
	_update_shake(delta)


func set_follow_target(target: Node2D) -> void:
	_follow_target = target


func clear_follow_target() -> void:
	_follow_target = null


func set_screen_anchor_ratio(ratio: float) -> void:
	_screen_anchor_ratio = clampf(ratio, 0.0, 1.0)
	_use_screen_anchor = true


func setup_limits(viewport_size: Vector2, ground_y: float) -> void:
	_camera.limit_left = 0
	_camera.limit_right = int(viewport_size.x * GameConfig.CAMERA_WORLD_WIDTH_MULTIPLIER)
	_camera.limit_top = int(GameConfig.CAMERA_TOP_LIMIT)
	_camera.limit_bottom = int(ground_y + Ground.GROUND_THICKNESS)
	_camera.limit_smoothed = true


func set_zoom_level(value: float) -> void:
	_target_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	_camera.zoom = Vector2.ONE * _target_zoom


func shake(intensity: float, duration: float) -> void:
	_shake_intensity = maxf(intensity, 0.0)
	_shake_duration = maxf(duration, 0.0)
	_shake_elapsed = 0.0


func reset_camera() -> void:
	global_position = _default_position
	_camera.offset = Vector2.ZERO
	_target_zoom = clampf(_default_zoom.x, MIN_ZOOM, MAX_ZOOM)
	_camera.zoom = Vector2.ONE * _target_zoom
	_shake_intensity = 0.0
	_shake_duration = 0.0
	_shake_elapsed = 0.0


func _update_follow(delta: float) -> void:
	if _follow_target == null or not is_instance_valid(_follow_target):
		return

	var target_position: Vector2 = _follow_target.global_position + follow_offset

	if _use_screen_anchor:
		var viewport_width: float = get_viewport().get_visible_rect().size.x
		target_position.x -= viewport_width * (_screen_anchor_ratio - 0.5)

	var weight: float = clampf(smoothing_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(target_position, weight)


func _update_shake(delta: float) -> void:
	if _shake_duration <= 0.0 or _shake_elapsed >= _shake_duration:
		_camera.offset = Vector2.ZERO
		return

	_shake_elapsed += delta
	var decay: float = 1.0 - clampf(_shake_elapsed / _shake_duration, 0.0, 1.0)
	var amount: float = _shake_intensity * decay
	_camera.offset = Vector2(
		randf_range(-amount, amount),
		randf_range(-amount, amount),
	)
