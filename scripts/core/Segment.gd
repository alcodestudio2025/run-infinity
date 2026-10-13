class_name Segment
extends Node2D

## Terrain-only world slice. Modules are attached externally via ModuleRoot.

@onready var ground_visual: Node2D = $GroundVisual
@onready var ground_polygon: Polygon2D = $GroundVisual/GroundPolygon
@onready var module_root: Node2D = $ModuleRoot
@onready var decoration_root: Node2D = $DecorationRoot
@onready var debug_root: Node2D = $DebugRoot

var _length: float = GameConfig.SEGMENT_LENGTH
var _ground_y: float = GameConfig.GROUND_Y
var _ground_height: float = GameConfig.SEGMENT_GROUND_HEIGHT
var _pending_color_index: int = 0
var _has_pending_visual: bool = false


func _ready() -> void:
	if not _validate_required_nodes():
		return
	if _has_pending_visual:
		_apply_ground_visual(_pending_color_index)


func configure(length: float, ground_y: float, color_index: int = 0) -> void:
	_length = maxf(length, 1.0)
	_ground_y = ground_y
	_pending_color_index = color_index
	_has_pending_visual = true
	_try_apply_ground_visual()


func get_length() -> float:
	return _length


func get_module_root() -> Node2D:
	return module_root


func get_decoration_root() -> Node2D:
	return decoration_root


func get_debug_root() -> Node2D:
	return debug_root


func reset_segment() -> void:
	_reset_modules(module_root)
	_reset_modules(decoration_root)
	_reset_modules(debug_root)


func _try_apply_ground_visual() -> void:
	if not _has_pending_visual:
		return
	if not is_node_ready():
		call_deferred("_try_apply_ground_visual")
		return
	if not _validate_required_nodes():
		return
	_apply_ground_visual(_pending_color_index)


func _apply_ground_visual(color_index: int) -> void:
	if ground_polygon == null or ground_visual == null:
		push_error("Segment: cannot apply ground visual because required nodes are missing.")
		return

	var colors: Array[Color] = GameConfig.get_segment_ground_colors()
	var half_width: float = _length * 0.5
	var half_height: float = _ground_height * 0.5

	ground_polygon.color = colors[color_index % colors.size()]
	ground_polygon.polygon = PackedVector2Array([
		Vector2(-half_width, -half_height),
		Vector2(half_width, -half_height),
		Vector2(half_width, half_height),
		Vector2(-half_width, half_height),
	])
	ground_visual.position = Vector2.ZERO
	_has_pending_visual = false


func _validate_required_nodes() -> bool:
	var is_valid: bool = true

	if ground_visual == null:
		push_error("Segment: missing required node 'GroundVisual'.")
		is_valid = false
	if ground_polygon == null:
		push_error("Segment: missing required node 'GroundVisual/GroundPolygon'.")
		is_valid = false
	if module_root == null:
		push_error("Segment: missing required node 'ModuleRoot'.")
		is_valid = false
	if decoration_root == null:
		push_error("Segment: missing required node 'DecorationRoot'.")
		is_valid = false
	if debug_root == null:
		push_error("Segment: missing required node 'DebugRoot'.")
		is_valid = false

	return is_valid


func _reset_modules(root: Node2D) -> void:
	if root == null:
		return

	## Free immediately: recycle can re-acquire the same segment in one frame.
	## queue_free would leave stale modules as siblings until end-of-frame.
	for child: Node in root.get_children():
		if child is SegmentModule:
			(child as SegmentModule).deactivate()
			(child as SegmentModule).reset()
		root.remove_child(child)
		child.free()
