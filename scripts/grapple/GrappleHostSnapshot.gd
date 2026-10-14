class_name GrappleHostSnapshot
extends RefCounted

## Per-frame host (player) snapshot fed into GrappleController.
## Keeps Grapple free of PlayerMovement / TouchGestureRouter coupling.

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var is_airborne: bool = false
var is_alive: bool = true


func _init(
	p_position: Vector2 = Vector2.ZERO,
	p_velocity: Vector2 = Vector2.ZERO,
	p_is_airborne: bool = false,
	p_is_alive: bool = true,
) -> void:
	position = p_position
	velocity = p_velocity
	is_airborne = p_is_airborne
	is_alive = p_is_alive
