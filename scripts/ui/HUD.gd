class_name HUD
extends CanvasLayer

## Minimal run HUD: score, distance, and game-over prompt.

@onready var score_label: Label = $TopLeftContainer/Content/ScoreLabel
@onready var distance_label: Label = $TopLeftContainer/Content/DistanceLabel
@onready var state_label: Label = $TopLeftContainer/Content/StateLabel


func update_score(score: int) -> void:
	if score_label != null:
		score_label.text = "Score: %d" % score


func update_distance(distance: float) -> void:
	if distance_label != null:
		distance_label.text = "Distance: %d" % int(distance)


func show_game_over(score: int, distance: float) -> void:
	update_score(score)
	update_distance(distance)
	if state_label != null:
		state_label.text = "GAME OVER\nScore: %d\nPremi R o Spazio per ripartire" % score


func reset() -> void:
	update_score(0)
	update_distance(0.0)
	if state_label != null:
		state_label.text = ""
