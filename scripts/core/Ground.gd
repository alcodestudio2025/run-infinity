class_name Ground
extends StaticBody2D

## Procedural-width ground platform for testing and chunk foundation.
## No gameplay logic; size is configured via setup().

const GROUND_THICKNESS: float = 40.0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = Layers.to_mask(Layers.WORLD)
	collision_mask = 0


func setup(width: float, ground_y: float) -> void:
	var safe_width: float = maxf(width, 1.0)
	_apply_collision(safe_width)
	_apply_visual(safe_width)
	position = Vector2(safe_width * 0.5, ground_y + GROUND_THICKNESS * 0.5)


func _apply_collision(width: float) -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, GROUND_THICKNESS)
	_collision_shape.shape = shape
	_collision_shape.position = Vector2.ZERO


func _apply_visual(width: float) -> void:
	if _visual.texture == null:
		return

	var texture_size: Vector2 = _visual.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	_visual.scale = Vector2(
		width / texture_size.x,
		GROUND_THICKNESS / texture_size.y,
	)
	_visual.position = Vector2.ZERO


func set_visual_visible(is_visible: bool) -> void:
	if _visual != null:
		_visual.visible = is_visible
