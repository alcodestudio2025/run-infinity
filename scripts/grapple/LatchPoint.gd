class_name LatchPoint
extends RefCounted

## World-space latch candidate. Modules / world data produce these;
## LatchSelector filters and ranks them. Not a scene node.

var id: StringName = &""
var position: Vector2 = Vector2.ZERO
## Optional metadata for future modules (e.g. perfect-zone radius).
var radius: float = 12.0
var source: Object = null


func _init(
	p_id: StringName = &"",
	p_position: Vector2 = Vector2.ZERO,
	p_radius: float = 12.0,
	p_source: Object = null,
) -> void:
	id = p_id
	position = p_position
	radius = p_radius
	source = p_source


func duplicate_point() -> LatchPoint:
	return LatchPoint.new(id, position, radius, source)
