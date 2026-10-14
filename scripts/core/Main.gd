extends Node

## Application entry point. Boots global state, shows title, then starts the run.

const GAME_SCENE: PackedScene = preload("res://scenes/game/GameScene.tscn")
const TITLE_SCENE: PackedScene = preload("res://scenes/ui/TitleScreen.tscn")

@onready var _game_scene_container: Node = $GameSceneContainer

var _game_scene: Node = null
var _title_screen: TitleScreen = null


func _ready() -> void:
	Engine.max_fps = GameConfig.TARGET_FPS
	GameStateManager.transition_to(GameStateManager.GameState.BOOT)
	_load_game_scene()
	_show_title_menu()


func start_game() -> void:
	## Only valid from the title menu. Ignore PLAYING / GAME_OVER / other states
	## so stray calls cannot hide the title or re-enter begin_run mid-flow.
	if GameStateManager.current_state != GameStateManager.GameState.MAIN_MENU:
		return

	if _title_screen != null:
		_title_screen.set_visible_menu(false)

	if _game_scene != null and _game_scene.has_method("begin_run"):
		_game_scene.call("begin_run")

	GameStateManager.transition_to(GameStateManager.GameState.PLAYING)
	EventBus.game_started.emit()


func is_title_visible() -> bool:
	return _title_screen != null and _title_screen.visible


func _load_game_scene() -> void:
	var instance: Node = GAME_SCENE.instantiate()
	_game_scene_container.add_child(instance)
	_game_scene = instance
	## Prepared only — do not enter PLAYING until start_game().


func _show_title_menu() -> void:
	if _title_screen == null:
		_title_screen = TITLE_SCENE.instantiate() as TitleScreen
		add_child(_title_screen)
		if not _title_screen.play_pressed.is_connected(_on_title_play_pressed):
			_title_screen.play_pressed.connect(_on_title_play_pressed)

	GameStateManager.transition_to(GameStateManager.GameState.MAIN_MENU)
	_title_screen.refresh_best_score()
	_title_screen.set_visible_menu(true)


func _on_title_play_pressed() -> void:
	start_game()
