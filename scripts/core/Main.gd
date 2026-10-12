extends Node

## Application entry point. Boots global state and loads the run scene.

const GAME_SCENE: PackedScene = preload("res://scenes/game/GameScene.tscn")

@onready var _game_scene_container: Node = $GameSceneContainer


func _ready() -> void:
	Engine.max_fps = GameConfig.TARGET_FPS
	GameStateManager.transition_to(GameStateManager.GameState.BOOT)
	_load_game_scene()


func _load_game_scene() -> void:
	var instance: Node = GAME_SCENE.instantiate()
	_game_scene_container.add_child(instance)
	GameStateManager.transition_to(GameStateManager.GameState.PLAYING)
