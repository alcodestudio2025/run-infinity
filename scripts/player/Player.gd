class_name Player
extends CharacterBody2D

## Player root: state ownership and lifecycle only. No detailed physics.

@export var config: PlayerConfig = PlayerConfig.new()

@onready var _movement: PlayerMovement = $PlayerMovement

var _state: PlayerState.State = PlayerState.State.IDLE


func _ready() -> void:
	collision_layer = Layers.to_mask(Layers.PLAYER)
	collision_mask = Layers.to_mask(Layers.WORLD)
	add_to_group(Tags.PLAYER)
	_movement.setup(self, config)


func set_state(new_state: PlayerState.State) -> void:
	_state = new_state


func get_state() -> PlayerState.State:
	return _state


func is_alive() -> bool:
	return _state != PlayerState.State.DEAD and _state != PlayerState.State.HIT


func kill() -> void:
	if _state == PlayerState.State.DEAD:
		return

	set_state(PlayerState.State.DEAD)
	velocity = Vector2.ZERO
	EventBus.player_died.emit()


func respawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	set_state(PlayerState.State.RUNNING)
	_movement.reset_to_standing()
