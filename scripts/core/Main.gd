extends Node

## Application entry point. Boots global state, shows title, then character select, then run.

const GAME_SCENE: PackedScene = preload("res://scenes/game/GameScene.tscn")
const TITLE_SCENE: PackedScene = preload("res://scenes/ui/TitleScreen.tscn")
const CHARACTER_SELECT_SCENE: PackedScene = preload("res://scenes/ui/CharacterSelectionScreen.tscn")

@onready var _game_scene_container: Node = $GameSceneContainer

var _game_scene: Node = null
var _title_screen: TitleScreen = null
var _character_select: CharacterSelectionScreen = null


func _ready() -> void:
	Engine.max_fps = GameConfig.TARGET_FPS
	GameStateManager.transition_to(GameStateManager.GameState.BOOT)
	_load_game_scene()
	_show_title_menu()


func start_game() -> void:
	## Only valid from the title menu. Ignore PLAYING / GAME_OVER / other states
	## so stray calls cannot hide the title or re-enter begin_run mid-flow.
	## Smokes may call this directly (skipping character select UI).
	if GameStateManager.current_state != GameStateManager.GameState.MAIN_MENU:
		return

	if _title_screen != null:
		_title_screen.set_visible_menu(false)
	if _character_select != null:
		_character_select.set_visible_menu(false)

	_apply_saved_character_to_player()

	if _game_scene != null and _game_scene.has_method("begin_run"):
		_game_scene.call("begin_run")

	GameStateManager.transition_to(GameStateManager.GameState.PLAYING)
	EventBus.game_started.emit()


func is_title_visible() -> bool:
	return _title_screen != null and _title_screen.visible


func is_character_select_visible() -> bool:
	return _character_select != null and _character_select.visible


func _load_game_scene() -> void:
	var instance: Node = GAME_SCENE.instantiate()
	_game_scene_container.add_child(instance)
	_game_scene = instance
	## Prepared only — do not enter PLAYING until start_game().


func _show_title_menu() -> void:
	if _character_select != null:
		_character_select.set_visible_menu(false)

	if _title_screen == null:
		_title_screen = TITLE_SCENE.instantiate() as TitleScreen
		add_child(_title_screen)
		if not _title_screen.play_pressed.is_connected(_on_title_play_pressed):
			_title_screen.play_pressed.connect(_on_title_play_pressed)

	GameStateManager.transition_to(GameStateManager.GameState.MAIN_MENU)
	_title_screen.refresh_best_score()
	_title_screen.set_visible_menu(true)


func _show_character_select() -> void:
	if _title_screen != null:
		_title_screen.set_visible_menu(false)

	if _character_select == null:
		_character_select = CHARACTER_SELECT_SCENE.instantiate() as CharacterSelectionScreen
		add_child(_character_select)
		if not _character_select.character_confirmed.is_connected(_on_character_confirmed):
			_character_select.character_confirmed.connect(_on_character_confirmed)
		if not _character_select.back_pressed.is_connected(_on_character_select_back):
			_character_select.back_pressed.connect(_on_character_select_back)

	## Stay in MAIN_MENU so start_game() contract remains valid.
	GameStateManager.transition_to(GameStateManager.GameState.MAIN_MENU)
	_character_select.set_visible_menu(true)


func _on_title_play_pressed() -> void:
	_show_character_select()


func _on_character_confirmed(character_id: String) -> void:
	## Selection screen already persisted; apply + start run.
	_apply_character_to_player(character_id)
	start_game()


func _on_character_select_back() -> void:
	_show_title_menu()


func _apply_saved_character_to_player() -> void:
	var character_id: String = CharacterCatalog.DEFAULT_ID
	if SaveManager != null and SaveManager.has_method("get_selected_character_id"):
		character_id = SaveManager.get_selected_character_id()
	_apply_character_to_player(character_id)


func _apply_character_to_player(character_id: String) -> void:
	if _game_scene == null:
		return
	var player_root: Node = _game_scene.get_node_or_null("PlayerRoot")
	if player_root == null or player_root.get_child_count() == 0:
		return
	var player: Node = player_root.get_child(0)
	if player != null and player.has_method("apply_character"):
		player.call("apply_character", character_id)
