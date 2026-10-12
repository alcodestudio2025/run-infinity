class_name ModulePlaceholder
extends SegmentModule

## Visual-only module used to validate the module pipeline.

@onready var visual: Polygon2D = $Visual

var _default_local_position: Vector2 = Vector2.ZERO


func setup(context: Dictionary = {}) -> void:
	if context.has("local_position"):
		_default_local_position = context["local_position"] as Vector2
		position = _default_local_position
	_set_visual_visible(true)


func activate() -> void:
	visible = true
	position = _default_local_position
	_set_visual_visible(true)


func deactivate() -> void:
	visible = false
	_set_visual_visible(false)


func reset() -> void:
	visible = false
	position = Vector2.ZERO
	_default_local_position = Vector2.ZERO
	_set_visual_visible(false)


func _set_visual_visible(is_visible: bool) -> void:
	if visual != null:
		visual.visible = is_visible
