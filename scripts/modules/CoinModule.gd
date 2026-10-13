class_name CoinModule
extends SegmentModule

## Collectible coin: awards score bonus on player overlap, then despawns.

@onready var visual: Polygon2D = $Visual
@onready var hit_area: Area2D = $HitArea
@onready var collision_shape: CollisionShape2D = $HitArea/CollisionShape2D

var _default_local_position: Vector2 = Vector2.ZERO
var _value: int = GameConfig.COIN_SCORE_VALUE
var _is_active: bool = false
var _has_collected: bool = false


func _ready() -> void:
	add_to_group(Tags.COIN)
	_configure_hit_area()
	_apply_visual()
	_apply_collision_shape()


func setup(context: Dictionary = {}) -> void:
	if context.has("local_position"):
		_default_local_position = context["local_position"] as Vector2
		position = _default_local_position
	if context.has("value"):
		_value = int(context["value"])


func activate() -> void:
	_is_active = true
	_has_collected = false
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
	_has_collected = false
	_value = GameConfig.COIN_SCORE_VALUE
	position = Vector2.ZERO
	_default_local_position = Vector2.ZERO


func _configure_hit_area() -> void:
	if hit_area == null:
		push_error("CoinModule: missing HitArea node.")
		return
	hit_area.collision_layer = Layers.to_mask(Layers.COLLECTIBLE)
	hit_area.collision_mask = Layers.to_mask(Layers.PLAYER)
	hit_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not _is_active or _has_collected:
		return

	var player: Player = _resolve_player(body)
	if player == null or not player.is_alive():
		return

	_has_collected = true
	EventBus.player_collected_coin.emit(_value)
	deactivate()


func _resolve_player(body: Node2D) -> Player:
	if body is Player:
		return body as Player
	if body.is_in_group(Tags.PLAYER):
		return body as Player
	return null


func _apply_visual() -> void:
	if visual == null:
		return

	var half_size: Vector2 = GameConfig.COIN_SIZE * 0.5
	visual.color = GameConfig.COIN_COLOR
	## Simple diamond so coins read differently from curb rectangles.
	visual.polygon = PackedVector2Array([
		Vector2(0.0, -half_size.y),
		Vector2(half_size.x, 0.0),
		Vector2(0.0, half_size.y),
		Vector2(-half_size.x, 0.0),
	])


func _apply_collision_shape() -> void:
	if collision_shape == null:
		return

	var shape := RectangleShape2D.new()
	shape.size = GameConfig.COIN_SIZE
	collision_shape.shape = shape


func _set_visual_visible(is_visible: bool) -> void:
	if visual != null:
		visual.visible = is_visible


func _set_monitoring(enabled: bool) -> void:
	if hit_area == null:
		return
	## body_entered cannot toggle monitoring inline — defer the change.
	hit_area.set_deferred("monitoring", enabled)
