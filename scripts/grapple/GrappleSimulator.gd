class_name GrappleSimulator
extends RefCounted

## Deterministic swing / oscillation math interface.
## Agent B owns the real implementation (step/query). This base is the contract
## GrappleController expects — override methods; do not put policy/FSM here.
##
## Path: res://scripts/grapple/GrappleSimulator.gd
## Cherry-pick friendly: Agent B can replace or subclass without touching the controller.


func begin_swing(
	_anchor: Vector2,
	_player_position: Vector2,
	_initial_velocity: Vector2,
	_params: GrappleSwingParams,
) -> void:
	pass


func step(_delta: float) -> void:
	pass


func get_player_position() -> Vector2:
	return Vector2.ZERO


func get_player_velocity() -> Vector2:
	return Vector2.ZERO


func get_anchor_position() -> Vector2:
	return Vector2.ZERO


func get_rope_angle() -> float:
	## Radians from vertical; 0 = hanging straight down. Sign: + = forward (run dir).
	return 0.0


func get_rope_length() -> float:
	return 0.0


func get_elapsed_sec() -> float:
	return 0.0


func is_active() -> bool:
	return false


## Simulator-side release hint (angle / timing). Controller also enforces hard caps.
func should_auto_release() -> bool:
	return false


func compute_release_impulse() -> Vector2:
	return Vector2.ZERO


func reset() -> void:
	pass
