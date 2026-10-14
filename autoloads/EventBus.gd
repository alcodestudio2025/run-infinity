extends Node

signal game_started
signal game_paused
signal game_resumed
signal game_over(final_score: int, distance: float)
signal player_died
signal player_jumped
signal player_double_jumped
signal player_slid
signal player_landed
signal player_collected_coin(value: int)
signal player_hit_obstacle
signal difficulty_increased(level: int)
signal score_changed(score: int)
signal score_multiplier_changed(multiplier: float)
signal player_attached_to_anchor(anchor_position: Vector2)
signal player_released_from_anchor(launch_velocity: Vector2, is_perfect: bool)
## Air JUMP with no valid latch: empty cast VFX only (trajectory unchanged).
signal player_grapple_missed
signal swing_combo_updated(count: int, multiplier: float, combo_name: String)
signal swing_perfect_zone_active
