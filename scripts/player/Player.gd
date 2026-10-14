class_name Player
extends CharacterBody2D

## Player root: state ownership and lifecycle only. No detailed physics.
## Visuals live on CharacterVisual — collision stays on CollisionShape2D.

@export var config: PlayerConfig = PlayerConfig.new()

@onready var _movement: PlayerMovement = $PlayerMovement
@onready var _visual: CharacterVisual = $CharacterVisual

var _state: PlayerState.State = PlayerState.State.IDLE


func _ready() -> void:
	collision_layer = Layers.to_mask(Layers.PLAYER)
	collision_mask = Layers.to_mask(Layers.WORLD)
	add_to_group(Tags.PLAYER)
	_movement.setup(self, config)
	apply_saved_character()


func set_state(new_state: PlayerState.State) -> void:
	var previous: PlayerState.State = _state
	if previous == new_state:
		return
	_state = new_state
	if _visual != null:
		_visual.on_player_state_changed(new_state, previous)


func get_state() -> PlayerState.State:
	return _state


func get_character_visual() -> CharacterVisual:
	return _visual


func apply_character(character_id: String) -> void:
	if _visual == null:
		_visual = get_node_or_null("CharacterVisual") as CharacterVisual
	if _visual == null:
		return
	_visual.apply_character(character_id)


func apply_saved_character() -> void:
	var save_manager := get_tree().root.get_node_or_null("SaveManager")
	var character_id: String = CharacterCatalog.DEFAULT_ID
	if save_manager != null and save_manager.has_method("get_selected_character_id"):
		character_id = str(save_manager.call("get_selected_character_id"))
	apply_character(character_id)


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
	apply_saved_character()
