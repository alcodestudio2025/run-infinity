class_name LatchModule
extends SegmentModule

## Grapple latch (visual prototype): joins Tags.ANCHOR while active.
## Agent A collects via get_tree().get_nodes_in_group(Tags.ANCHOR) and
## is_latch_valid() / get_latch_global_position() / to_latch_point().
## Rope Line2D is owned by PlayerGrappleDriver (Agent A), not this module.

@onready var visual: Polygon2D = $Visual
@onready var ring: Polygon2D = $Ring
@onready var latch_point: Marker2D = $LatchPoint

var _default_local_position: Vector2 = Vector2.ZERO
var _is_active: bool = false


func _ready() -> void:
	_apply_visual()
	## Group membership is gated by activate/deactivate so recycled modules
	## never remain valid anchors after Segment.reset_segment().
	if _is_active:
		_join_anchor_group()


func setup(context: Dictionary = {}) -> void:
	if context.has("local_position"):
		_default_local_position = context["local_position"] as Vector2
		position = _default_local_position


func activate() -> void:
	_is_active = true
	visible = true
	position = _default_local_position
	_set_visual_visible(true)
	_join_anchor_group()


func deactivate() -> void:
	_is_active = false
	_leave_anchor_group()
	_set_visual_visible(false)
	visible = false


func reset() -> void:
	deactivate()
	position = Vector2.ZERO
	_default_local_position = Vector2.ZERO


## True only while active, in-tree, and still in Tags.ANCHOR.
## Safe for callers that held a reference across segment recycle.
func is_latch_valid() -> bool:
	if not _is_active:
		return false
	if not is_inside_tree():
		return false
	return is_in_group(Tags.ANCHOR)


func get_latch_global_position() -> Vector2:
	if latch_point != null and is_instance_valid(latch_point):
		return latch_point.global_position
	return global_position


## Convenience for Agent A's LatchProvider / LatchSelector pipeline.
func to_latch_point() -> LatchPoint:
	return LatchPoint.new(
		&"latch_module",
		get_latch_global_position(),
		GameConfig.LATCH_POINT_RADIUS,
		self,
	)


func _join_anchor_group() -> void:
	if not is_in_group(Tags.ANCHOR):
		add_to_group(Tags.ANCHOR)


func _leave_anchor_group() -> void:
	if is_in_group(Tags.ANCHOR):
		remove_from_group(Tags.ANCHOR)


func _apply_visual() -> void:
	## Cyan diamond + larger amber ring so latches read apart from coins/obstacles.
	var half: Vector2 = GameConfig.LATCH_SIZE * 0.5
	var ring_half: Vector2 = half + Vector2(8.0, 8.0)

	if ring != null:
		ring.color = GameConfig.LATCH_RING_COLOR
		ring.polygon = PackedVector2Array([
			Vector2(0.0, -ring_half.y),
			Vector2(ring_half.x, 0.0),
			Vector2(0.0, ring_half.y),
			Vector2(-ring_half.x, 0.0),
		])

	if visual != null:
		visual.color = GameConfig.LATCH_COLOR
		visual.polygon = PackedVector2Array([
			Vector2(0.0, -half.y),
			Vector2(half.x, 0.0),
			Vector2(0.0, half.y),
			Vector2(-half.x, 0.0),
		])

	if latch_point != null:
		latch_point.position = Vector2.ZERO


func _set_visual_visible(is_visible: bool) -> void:
	if visual != null:
		visual.visible = is_visible
	if ring != null:
		ring.visible = is_visible
