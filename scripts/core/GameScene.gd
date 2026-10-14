extends Node2D

## Run scene composition root.
## Contains World, CameraRig, and placeholder Player/UI roots only.
## Persistence stays in SaveManager via EventBus (no direct save writes here).
## Must not reference ads, analytics, economy, shop, or leaderboard.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/HUD.tscn")

@onready var _velocity_controller: WorldVelocityController = $WorldVelocityController
@onready var _difficulty_director: DifficultyDirector = $DifficultyDirector
@onready var _run_loop: RunLoop = $RunLoop
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _player_root: Node2D = $PlayerRoot
@onready var _ui_root: CanvasLayer = $UIRoot
@onready var _ground: Ground = $World/GameplayRoot/Ground
@onready var _world: World = $World
@onready var _segment_manager: SegmentManager = $SegmentManager
@onready var _module_spawner: ModuleSpawner = $ModuleSpawner
@onready var _world_scroller: WorldScroller = $WorldScroller

var _player: Player
var _hud: HUD
var _game_over_handled: bool = false
var _bonus_score: int = 0
var _run_begun: bool = false


func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_collected_coin.connect(_on_player_collected_coin)
	_run_loop.setup(_velocity_controller, _difficulty_director)
	_run_loop.stop()
	_setup_ground()
	_setup_segment_pipeline()
	_setup_camera()
	_setup_hud()
	_spawn_player()
	## Prepared for MAIN_MENU — scrolling / scoring start in begin_run().


func begin_run() -> void:
	if _run_begun:
		return

	_run_begun = true
	_run_loop.start()
	_velocity_controller.start_run()
	_world_scroller.start()
	if _hud != null:
		_hud.visible = true
	_log_debug("RUN STARTED")


func is_run_active() -> bool:
	return _run_begun


func _physics_process(_delta: float) -> void:
	if _hud == null or not GameStateManager.is_playing():
		return

	var distance: float = _velocity_controller.distance_travelled
	var score: int = _compute_score(distance)
	_hud.update_distance(distance)
	_hud.update_score(score)
	_hud.update_speed(_velocity_controller.current_speed)
	_hud.update_difficulty(_difficulty_director.current_level)
	_hud.show_running()


func _exit_tree() -> void:
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)
	if EventBus.player_collected_coin.is_connected(_on_player_collected_coin):
		EventBus.player_collected_coin.disconnect(_on_player_collected_coin)


func _unhandled_input(event: InputEvent) -> void:
	if GameStateManager.current_state != GameStateManager.GameState.GAME_OVER:
		return

	if event.is_action_pressed("ui_accept"):
		restart_run()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
			restart_run()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			restart_run()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			restart_run()
			get_viewport().set_input_as_handled()


func restart_run() -> void:
	if GameStateManager.current_state != GameStateManager.GameState.GAME_OVER:
		return

	_game_over_handled = false
	_bonus_score = 0

	_velocity_controller.reset()
	_difficulty_director.reset()
	_world_scroller.reset()

	if _player != null:
		_player.respawn(_get_spawn_position())

	if _hud != null:
		_hud.visible = true
		_hud.reset()

	_run_begun = true
	_run_loop.start()
	GameStateManager.transition_to(GameStateManager.GameState.PLAYING)
	_velocity_controller.start_run()
	_world_scroller.start()
	_log_debug("RUN RESTARTED")


func _on_player_died() -> void:
	if _game_over_handled:
		return

	_game_over_handled = true

	var distance: float = _velocity_controller.distance_travelled
	var final_score: int = _compute_score(distance)

	_velocity_controller.stop_run()
	_world_scroller.stop()
	_run_loop.stop()
	GameStateManager.transition_to(GameStateManager.GameState.GAME_OVER)
	EventBus.game_over.emit(final_score, distance)
	if _hud != null:
		_hud.show_game_over(final_score, distance)
	_log_debug("GAME OVER - Score: %d - Distance: %0.1f" % [final_score, distance])


func _on_player_collected_coin(value: int) -> void:
	_bonus_score += maxi(value, 0)
	EventBus.score_changed.emit(_compute_score(_velocity_controller.distance_travelled))


func _compute_score(distance: float) -> int:
	return GameConfig.distance_to_score(distance) + _bonus_score


func _setup_ground() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_ground.setup(
		viewport_size.x * GameConfig.CAMERA_WORLD_WIDTH_MULTIPLIER,
		GameConfig.GROUND_Y,
	)
	_ground.set_visual_visible(false)


func _setup_segment_pipeline() -> void:
	_module_spawner.setup(_difficulty_director)
	_segment_manager.setup(_world, _module_spawner)
	_world_scroller.setup(_world, _velocity_controller, _segment_manager)
	## Do not start scrolling until begin_run() / restart_run().


func _setup_camera() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_camera_rig.set_screen_anchor_ratio(GameConfig.PLAYER_SCREEN_RATIO)
	_camera_rig.setup_limits(viewport_size, GameConfig.GROUND_Y)


func _setup_hud() -> void:
	if _hud != null:
		return

	_hud = HUD_SCENE.instantiate() as HUD
	_ui_root.add_child(_hud)
	_hud.reset()
	## Stay under title until begin_run(); TitleScreen layer is ≥ 20.
	_hud.visible = false


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_player.global_position = _get_spawn_position()
	_player_root.add_child(_player)
	_camera_rig.set_follow_target(_player)


func _get_spawn_position() -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(
		viewport_size.x * GameConfig.PLAYER_SCREEN_RATIO,
		GameConfig.GROUND_Y - GameConfig.PLAYER_FEET_OFFSET,
	)


func _log_debug(message: String) -> void:
	if GameConfig.DEBUG_LOG:
		print_debug(message)
