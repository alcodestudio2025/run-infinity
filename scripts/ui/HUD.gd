class_name HUD
extends CanvasLayer

## Minimal run HUD: score, distance, speed, and game-over prompt.

@onready var score_label: Label = $TopLeftContainer/Content/ScoreLabel
@onready var distance_label: Label = $TopLeftContainer/Content/DistanceLabel
@onready var speed_label: Label = $TopLeftContainer/Content/SpeedLabel
@onready var difficulty_label: Label = $TopLeftContainer/Content/DifficultyLabel
@onready var state_label: Label = $TopLeftContainer/Content/StateLabel
@onready var jumps_label: Label = $TopLeftContainer/Content/JumpsLabel
@onready var game_over_label: Label = $GameOverCenter/GameOverLabel

var _jump_count: int = 0


func _ready() -> void:
	if not EventBus.player_jumped.is_connected(_on_player_jumped):
		EventBus.player_jumped.connect(_on_player_jumped)


func _exit_tree() -> void:
	if EventBus.player_jumped.is_connected(_on_player_jumped):
		EventBus.player_jumped.disconnect(_on_player_jumped)


func _on_player_jumped() -> void:
	_jump_count += 1
	_update_jumps()


func _update_jumps() -> void:
	if jumps_label != null:
		jumps_label.text = "Jumps: %d" % _jump_count


func update_score(score: int) -> void:
	if score_label != null:
		score_label.text = "Score: %d" % score


func update_distance(distance: float) -> void:
	if distance_label != null:
		distance_label.text = "Distance: %d m" % int(distance)


func update_speed(speed: float) -> void:
	if speed_label != null:
		speed_label.text = "Speed: %d" % int(speed)


func update_difficulty(level: int) -> void:
	if difficulty_label != null:
		difficulty_label.text = "Difficulty: %d" % maxi(level, 0)


func show_running() -> void:
	if state_label != null:
		state_label.text = "State: RUN"
	if game_over_label != null:
		game_over_label.visible = false
		game_over_label.text = ""


func show_game_over(score: int, distance: float) -> void:
	update_score(score)
	update_distance(distance)
	if state_label != null:
		state_label.text = "State: GAME OVER"
	if game_over_label != null:
		game_over_label.visible = true
		game_over_label.text = (
			"GAME OVER\nScore: %d  ·  Distance: %d m\nTap / R / Space — Restart"
			% [score, int(distance)]
		)


func reset() -> void:
	_jump_count = 0
	_update_jumps()
	update_score(0)
	update_distance(0.0)
	update_speed(0.0)
	update_difficulty(0)
	show_running()
