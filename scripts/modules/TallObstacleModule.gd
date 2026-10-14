class_name TallObstacleModule
extends SegmentModule

## Tall curb hazard: jump clear; standing contact kills.

@onready var visual: Polygon2D = $Visual
@onready var hit_area: Area2D = $HitArea
@onready var collision_shape: CollisionShape2D = $HitArea/CollisionShape2D

var _default_local_position: Vector2 = Vector2.ZERO
var _is_active: bool = false
var _has_triggered: bool = false


func _ready() -> void:
	add_to_group(Tags.OBSTACLE)
	_configure_hit_area()
	_apply_visual()
	_apply_collision_shape()


func setup(context: Dictionary = {}) -> void:
	if context.has("local_position"):
		_default_local_position = context["local_position"] as Vector2
		position = _default_local_position


func activate() -> void:
	_is_active = true
	_has_triggered = false
	visible = true
	position = _default_local_position
	_set_visual_visible(true)
	_set_monitoring(true)


func deactivate() -> void:
	_is_active = false
	_set_monitoring(false)
	_set_visual_visible(false)
	visible = false


func reset() -> void:
	deactivate()
	_has_triggered = false
	position = Vector2.ZERO
	_default_local_position = Vector2.ZERO


func _configure_hit_area() -> void:
	if hit_area == null:
		push_error("TallObstacleModule: missing HitArea node.")
		return
	hit_area.collision_layer = Layers.to_mask(Layers.OBSTACLE)
	hit_area.collision_mask = Layers.to_mask(Layers.PLAYER)
	hit_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	resolve_body_overlap(body)


## Public entry for Grapple path queries (teleport poses must not tunnel silently).
func resolve_body_overlap(body: Node2D) -> void:
	if not _is_active or _has_triggered:
		return

	var player: Player = _resolve_player(body)
	if player == null or not player.is_alive():
		return

	## Same jump-clear rule as low curb (height + airborne).
	if GameConfig.is_jump_clearing_curb(player):
		return

	_has_triggered = true
	EventBus.player_hit_obstacle.emit()
	player.kill()


func _resolve_player(body: Node2D) -> Player:
	if body is Player:
		return body as Player
	if body.is_in_group(Tags.PLAYER):
		return body as Player
	return null


func _apply_visual() -> void:
	if visual == null:
		return

	var half_size: Vector2 = GameConfig.TALL_OBSTACLE_SIZE * 0.5
	visual.color = GameConfig.TALL_OBSTACLE_COLOR
	visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])


func _apply_collision_shape() -> void:
	if collision_shape == null:
		return

	var shape := RectangleShape2D.new()
	shape.size = GameConfig.TALL_OBSTACLE_SIZE
	collision_shape.shape = shape


func _set_visual_visible(is_visible: bool) -> void:
	if visual != null:
		visual.visible = is_visible


func _set_monitoring(enabled: bool) -> void:
	if hit_area != null:
		hit_area.monitoring = enabled
