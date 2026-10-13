class_name PlayerConfig
extends Resource

## Tunable movement values for the player.
## Defaults align with global GameConfig where applicable.

@export var gravity: float = GameConfig.PLAYER_GRAVITY
@export var jump_velocity: float = GameConfig.PLAYER_JUMP_VELOCITY
@export var max_fall_speed: float = GameConfig.PLAYER_MAX_FALL_SPEED
## Defaults track GameConfig; resources created at runtime pick these up.
@export var coyote_time: float = 0.26
@export var jump_buffer_time: float = 0.24
@export var slide_duration: float = 0.45
@export var slide_input_drag_threshold: float = 64.0
@export var ground_y: float = GameConfig.GROUND_Y
@export var ideal_screen_ratio: float = GameConfig.PLAYER_SCREEN_RATIO
@export var standing_hitbox_size: Vector2 = GameConfig.PLAYER_STANDING_HITBOX_SIZE
@export var standing_hitbox_position: Vector2 = GameConfig.PLAYER_STANDING_HITBOX_POSITION
@export var sliding_hitbox_size: Vector2 = GameConfig.PLAYER_SLIDING_HITBOX_SIZE
@export var sliding_hitbox_position: Vector2 = GameConfig.PLAYER_SLIDING_HITBOX_POSITION
@export var sliding_sprite_scale: Vector2 = GameConfig.PLAYER_SPRITE_SLIDING_SCALE
@export var sliding_sprite_position: Vector2 = GameConfig.PLAYER_SPRITE_SLIDING_POSITION
