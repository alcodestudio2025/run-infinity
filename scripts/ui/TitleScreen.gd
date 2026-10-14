class_name TitleScreen
extends CanvasLayer

## Landscape title / main menu. Reads best score from SaveManager only (no writes).

signal play_pressed

@onready var title_label: Label = $CenterRoot/Content/TitleLabel
@onready var best_score_label: Label = $CenterRoot/Content/BestScoreLabel
@onready var play_button: Button = $CenterRoot/Content/PlayButton
@onready var hint_label: Label = $CenterRoot/Content/HintLabel

var _displayed_best: int = 0


func _ready() -> void:
	layer = maxi(layer, 20)
	if play_button != null and not play_button.pressed.is_connected(_on_play_button_pressed):
		play_button.pressed.connect(_on_play_button_pressed)
	refresh_best_score()
	set_visible_menu(true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		_emit_play()
		get_viewport().set_input_as_handled()


func get_displayed_best_score() -> int:
	return _displayed_best


func refresh_best_score() -> void:
	_displayed_best = _read_save_high_score()
	if best_score_label != null:
		best_score_label.text = "Best: %d" % _displayed_best


func set_visible_menu(show: bool) -> void:
	visible = show
	if show:
		refresh_best_score()
		if play_button != null:
			play_button.grab_focus()


func _on_play_button_pressed() -> void:
	_emit_play()


func _emit_play() -> void:
	if not visible:
		return
	play_pressed.emit()


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
