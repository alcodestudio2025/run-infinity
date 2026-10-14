class_name HUD
extends CanvasLayer

## Minimal run HUD: score, distance, speed, best, and game-over prompt.

@onready var score_label: Label = $TopLeftContainer/Content/ScoreLabel
@onready var best_score_label: Label = $TopLeftContainer/Content/BestScoreLabel
@onready var distance_label: Label = $TopLeftContainer/Content/DistanceLabel
@onready var speed_label: Label = $TopLeftContainer/Content/SpeedLabel
@onready var difficulty_label: Label = $TopLeftContainer/Content/DifficultyLabel
@onready var state_label: Label = $TopLeftContainer/Content/StateLabel
@onready var jumps_label: Label = $TopLeftContainer/Content/JumpsLabel
@onready var game_over_label: Label = $GameOverCenter/GameOverLabel
@onready var new_best_label: Label = $GameOverCenter/NewBestLabel

var _jump_count: int = 0
## Best at run start — used for NEW BEST (SaveManager may already have updated high_score by show_game_over).
var _baseline_best: int = 0
var _displayed_best: int = 0


func _ready() -> void:
	if not EventBus.player_jumped.is_connected(_on_player_jumped):
		EventBus.player_jumped.connect(_on_player_jumped)
	_refresh_best_from_save(true)
	_hide_new_best()


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


func get_displayed_best_score() -> int:
	return _displayed_best


func is_new_best_visible() -> bool:
	return new_best_label != null and new_best_label.visible


func get_baseline_best_score() -> int:
	return _baseline_best


func show_running() -> void:
	if state_label != null:
		state_label.text = "State: RUN"
	if game_over_label != null:
		game_over_label.visible = false
		game_over_label.text = ""
	_hide_new_best()


func show_game_over(score: int, distance: float) -> void:
	update_score(score)
	update_distance(distance)
	# Display current persisted best (may already include this run after EventBus.game_over).
	_refresh_best_from_save(false)
	if state_label != null:
		state_label.text = "State: GAME OVER"

	var is_new_best: bool = score > _baseline_best
	if new_best_label != null:
		if is_new_best:
			new_best_label.text = "NEW BEST"
			new_best_label.visible = true
		else:
			_hide_new_best()

	if game_over_label != null:
		game_over_label.visible = true
		game_over_label.text = (
			"GAME OVER\nScore: %d  ·  Distance: %d m\nBest: %d\nTap / R / Space — Restart"
			% [score, int(distance), _displayed_best]
		)


func reset() -> void:
	_jump_count = 0
	_update_jumps()
	update_score(0)
	update_distance(0.0)
	update_speed(0.0)
	update_difficulty(0)
	_hide_new_best()
	_refresh_best_from_save(true)
	show_running()


func _read_save_high_score() -> int:
	var save_manager := _get_save_manager()
	if save_manager == null:
		return 0
	var save_data = save_manager.get("data")
	if save_data == null:
		return 0
	return int(save_data.get("high_score"))


func _get_save_manager() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var root := tree.root
	if root == null:
		return null
	return root.get_node_or_null("SaveManager")


func _refresh_best_from_save(update_baseline: bool) -> void:
	var high_score: int = _read_save_high_score()
	_displayed_best = high_score
	if update_baseline:
		_baseline_best = high_score
	if best_score_label != null:
		best_score_label.text = "Best: %d" % _displayed_best


func _hide_new_best() -> void:
	if new_best_label != null:
		new_best_label.visible = false
