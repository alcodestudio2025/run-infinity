class_name PlayerConfig
extends Resource

## Tunable movement values for the player.
## Defaults align with global GameConfig where applicable.

@export var gravity: float = 1800.0
@export var jump_velocity: float = 620.0
@export var max_fall_speed: float = 1200.0
@export var coyote_time: float = GameConfig.COYOTE_TIME
@export var jump_buffer_time: float = GameConfig.JUMP_BUFFER
@export var slide_duration: float = GameConfig.SLIDE_DURATION
@export var slide_input_drag_threshold: float = GameConfig.SLIDE_INPUT_DRAG_THRESHOLD
@export var ground_y: float = GameConfig.GROUND_Y
@export var ideal_screen_ratio: float = GameConfig.PLAYER_SCREEN_RATIO
@export var standing_hitbox_size: Vector2 = GameConfig.PLAYER_STANDING_HITBOX_SIZE
@export var standing_hitbox_position: Vector2 = GameConfig.PLAYER_STANDING_HITBOX_POSITION
@export var sliding_hitbox_size: Vector2 = GameConfig.PLAYER_SLIDING_HITBOX_SIZE
@export var sliding_hitbox_position: Vector2 = GameConfig.PLAYER_SLIDING_HITBOX_POSITION
@export var sliding_sprite_scale: Vector2 = GameConfig.PLAYER_SPRITE_SLIDING_SCALE
@export var sliding_sprite_position: Vector2 = GameConfig.PLAYER_SPRITE_SLIDING_POSITION
