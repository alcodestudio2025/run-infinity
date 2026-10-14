extends SceneTree

## Headless M5.1 smoke: live Grapple via PlayerMovement + PlayerGrappleDriver.
## Loads Main/GameScene; spawns Tags.ANCHOR Node2D latches (no LatchModule required).
## Requires dedicated smoke userdata (scripts/ci/smoke_env.sh).
## Usage: source scripts/ci/smoke_env.sh && ri_smoke_env_setup && \
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m5_1_grapple_live_smoke.gd
##
## Autoload singletons / class_name globals are NOT used at parse time (-s launch).

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const Boot := preload("res://scripts/ci/smoke_boot_helpers.gd")
const GrappleStateScr := preload("res://scripts/grapple/GrappleState.gd")

const WARMUP_FRAMES: int = 90
const POST_START_FRAMES: int = 60
const GESTURE_SETTLE_FRAMES: int = 8
const STATE_MAIN_MENU: int = 1
const STATE_PLAYING: int = 2
const STATE_GAME_OVER: int = 4
const LABEL := "M5.1 grapple-live smoke"

## Mirror Tags.ANCHOR / GameConfig.GROUND_Y
const ANCHOR_GROUP := "anchor"
const GROUND_Y: float = 918.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Guard.require_isolated(self, LABEL):
		return

	var err: Error = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("%s: failed to load Main.tscn (%s)" % [LABEL, error_string(err)])
		quit(1)
		return

	await _wait_frames(WARMUP_FRAMES)

	var gsm: Node = root.get_node_or_null("GameStateManager")
	var event_bus: Node = root.get_node_or_null("EventBus")
	var main: Node = Boot.find_main(root)
	if gsm == null or event_bus == null or main == null:
		push_error("%s: Main/GSM/EventBus missing after warmup." % LABEL)
		quit(1)
		return

	# --- Case 9a: Title — no grapple activation ---
	if int(gsm.get("current_state")) != STATE_MAIN_MENU:
		push_error("%s: expected MAIN_MENU at boot." % LABEL)
		quit(1)
		return
	var game_scene: Node = _find_game_scene(main)
	if game_scene == null:
		push_error("%s: GameScene missing." % LABEL)
		quit(1)
		return
	var menu_player: Node = _find_player(game_scene)
	var menu_movement: Node = _find_movement(menu_player)
	if menu_movement != null and menu_movement.has_method("request_air_ability"):
		if bool(menu_movement.call("request_air_ability")):
			push_error("%s: C9 Title request_air_ability must fail." % LABEL)
			quit(1)
			return
	print("%s: C9a PASS (Title no air ability)" % LABEL)

	if not Boot.ensure_playing_from_title(root, LABEL):
		quit(1)
		return
	await _wait_frames(POST_START_FRAMES)

	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error("%s: expected PLAYING after start_game." % LABEL)
		quit(1)
		return

	var player: Node = _find_player(game_scene)
	var movement: Node = _find_movement(player)
	if player == null or movement == null:
		push_error("%s: Player/PlayerMovement missing." % LABEL)
		quit(1)
		return

	var driver: Node = _find_grapple_driver(movement)
	if driver == null:
		push_error("%s: PlayerGrappleDriver missing (Agent A wire-up)." % LABEL)
		quit(1)
		return

	var controller: RefCounted = null
	if driver.has_method("get_controller"):
		controller = driver.call("get_controller") as RefCounted
	if controller == null:
		push_error("%s: GrappleController missing on driver." % LABEL)
		quit(1)
		return

	_freeze_world(game_scene)
	await _wait_until_grounded(player, 120)

	var jump_count: Array = [0]
	var attach_count: Array = [0]
	var release_count: Array = [0]
	var slide_count: Array = [0]
	if event_bus.has_signal("player_jumped"):
		event_bus.player_jumped.connect(func() -> void: jump_count[0] = int(jump_count[0]) + 1)
	if event_bus.has_signal("player_attached_to_anchor"):
		event_bus.player_attached_to_anchor.connect(
			func(_p: Vector2) -> void: attach_count[0] = int(attach_count[0]) + 1
		)
	if event_bus.has_signal("player_released_from_anchor"):
		event_bus.player_released_from_anchor.connect(
			func(_v: Vector2, _perfect: bool) -> void: release_count[0] = int(release_count[0]) + 1
		)
	if event_bus.has_signal("player_slid"):
		event_bus.player_slid.connect(func() -> void: slide_count[0] = int(slide_count[0]) + 1)

	# --- Case 1: first tap / request_jump → one jump ---
	jump_count[0] = 0
	attach_count[0] = 0
	if not movement.has_method("request_jump"):
		push_error("%s: C1 request_jump missing." % LABEL)
		quit(1)
		return
	movement.call("request_jump")
	await _wait_frames(GESTURE_SETTLE_FRAMES)
	if int(jump_count[0]) != 1:
		push_error("%s: C1 expected exactly 1 jump got %d." % [LABEL, int(jump_count[0])])
		quit(1)
		return
	if int(attach_count[0]) != 0:
		push_error("%s: C1 first jump must not attach." % LABEL)
		quit(1)
		return
	if int(controller.call("get_phase")) != GrappleStateScr.Phase.IDLE:
		push_error("%s: C1 grapple must stay IDLE after ground jump." % LABEL)
		quit(1)
		return
	print("%s: C1 PASS (first jump ×1, no grapple)" % LABEL)

	# --- Case 3: airborne + no latch → no attach ---
	await _wait_frames(4)
	if bool(player.call("is_on_floor")):
		## Force airborne if we landed somehow.
		player.set("velocity", Vector2(0.0, -600.0))
		await _wait_frames(2)
	jump_count[0] = 0
	attach_count[0] = 0
	_clear_anchors(game_scene)
	var air_ok: bool = bool(movement.call("request_air_ability"))
	## Seek may accept then fail, or reject — must not attach.
	await _wait_frames(12)
	if int(attach_count[0]) != 0:
		push_error("%s: C3 no-latch must not attach." % LABEL)
		quit(1)
		return
	if int(controller.call("get_phase")) == GrappleStateScr.Phase.ATTACHED:
		push_error("%s: C3 phase must not be ATTACHED without latch." % LABEL)
		quit(1)
		return
	print("%s: C3 PASS (no latch → no attach, accepted=%s)" % [LABEL, air_ok])

	# --- Case 4: behind / OOR reject ---
	await _wait_until_airborne_or_jump(player, movement, 90)
	_clear_anchors(game_scene)
	var behind: Node2D = _spawn_anchor(
		game_scene,
		Vector2(float(player.global_position.x) - 80.0, float(player.global_position.y) - 120.0),
	)
	var oor: Node2D = _spawn_anchor(
		game_scene,
		Vector2(float(player.global_position.x) + 900.0, float(player.global_position.y) - 200.0),
	)
	attach_count[0] = 0
	movement.call("request_air_ability")
	await _wait_frames(16)
	if int(attach_count[0]) != 0 or int(controller.call("get_phase")) == GrappleStateScr.Phase.ATTACHED:
		push_error("%s: C4 behind/OOR must reject." % LABEL)
		quit(1)
		return
	_free_node(behind)
	_free_node(oor)
	print("%s: C4 PASS (behind/OOR reject)" % LABEL)

	# --- Case 2: second air tap → attach when latch present ---
	await _wait_until_grounded(player, 180)
	jump_count[0] = 0
	attach_count[0] = 0
	release_count[0] = 0
	movement.call("request_jump")
	await _wait_frames(4)
	if int(jump_count[0]) < 1:
		push_error("%s: C2 setup jump failed." % LABEL)
		quit(1)
		return
	_clear_anchors(game_scene)
	var good_latch: Node2D = _spawn_anchor(
		game_scene,
		Vector2(float(player.global_position.x) + 160.0, float(player.global_position.y) - 180.0),
	)
	await _wait_frames(2)
	jump_count[0] = 0
	var attached_now: bool = bool(movement.call("request_air_ability"))
	await _wait_frames(8)
	if not attached_now and int(attach_count[0]) == 0:
		## Seek same-frame may return true; also accept EventBus attach.
		push_error("%s: C2 expected air ability attach with latch ahead/above." % LABEL)
		quit(1)
		return
	if int(jump_count[0]) != 0:
		push_error("%s: C2 air ability must NOT also jump (got jumps=%d)." % [LABEL, int(jump_count[0])])
		quit(1)
		return
	if int(attach_count[0]) < 1 and int(controller.call("get_phase")) != GrappleStateScr.Phase.ATTACHED:
		push_error("%s: C2 expected ATTACHED / player_attached_to_anchor." % LABEL)
		quit(1)
		return
	print("%s: C2 PASS (air tap → attach, no jump)" % LABEL)

	# --- Case 5: auto-release once ---
	var safety: int = 90
	var saw_release := false
	while safety > 0:
		await _wait_frames(1)
		safety -= 1
		if int(release_count[0]) >= 1:
			saw_release = true
			break
		var phase: int = int(controller.call("get_phase"))
		if phase == GrappleStateScr.Phase.IDLE and int(release_count[0]) >= 1:
			saw_release = true
			break
	if not saw_release:
		push_error("%s: C5 expected auto-release within swing window." % LABEL)
		quit(1)
		return
	await _wait_frames(20)
	if int(release_count[0]) != 1:
		push_error("%s: C5 auto-release must fire once got %d." % [LABEL, int(release_count[0])])
		quit(1)
		return
	_free_node(good_latch)
	print("%s: C5 PASS (auto-release ×1)" % LABEL)

	# --- Case 8: swipe down → slide not grapple ---
	await _wait_until_grounded(player, 180)
	_clear_anchors(game_scene)
	slide_count[0] = 0
	attach_count[0] = 0
	var live_router: Object = _find_touch_router(player)
	if live_router == null:
		push_error("%s: C8 TouchGestureRouter missing." % LABEL)
		quit(1)
		return
	if live_router.has_method("set_enabled"):
		live_router.call("set_enabled", true)
	var vp: Vector2 = Vector2(1280, 720)
	if live_router is Node and (live_router as Node).get_viewport() != null:
		vp = (live_router as Node).get_viewport().get_visible_rect().size
	var swipe_px: float = 80.0
	if live_router.has_method("get_swipe_threshold_px"):
		swipe_px = float(live_router.call("get_swipe_threshold_px", vp))
	var s0 := Vector2(300, 200)
	var s1 := Vector2(300, 200 + swipe_px + 20.0)
	live_router.call("begin_touch", 0, s0)
	live_router.call("update_touch", 0, s1)
	var gesture: String = str(live_router.call("end_touch", 0, s1))
	await _wait_frames(GESTURE_SETTLE_FRAMES)
	if gesture != "slide":
		push_error("%s: C8 expected slide gesture got %s." % [LABEL, gesture])
		quit(1)
		return
	if int(slide_count[0]) < 1:
		push_error("%s: C8 swipe must slide (player_slid=%d)." % [LABEL, int(slide_count[0])])
		quit(1)
		return
	if int(attach_count[0]) != 0:
		push_error("%s: C8 slide must not grapple." % LABEL)
		quit(1)
		return
	print("%s: C8 PASS (swipe down → slide, not grapple)" % LABEL)

	# --- Case 6: death during grapple → GO + reset ---
	await _wait_until_standing(player, 120)
	_clear_anchors(game_scene)
	movement.call("request_jump")
	await _wait_frames(4)
	var death_latch: Node2D = _spawn_anchor(
		game_scene,
		Vector2(float(player.global_position.x) + 150.0, float(player.global_position.y) - 170.0),
	)
	await _wait_frames(2)
	movement.call("request_air_ability")
	await _wait_frames(6)
	if int(controller.call("get_phase")) != GrappleStateScr.Phase.ATTACHED:
		## Force attach if seek raced
		if controller.has_method("force_attach"):
			var LatchPointScr = load("res://scripts/grapple/LatchPoint.gd")
			var lp = LatchPointScr.new(
				&"force",
				death_latch.global_position,
				12.0,
				death_latch,
			)
			controller.call("force_attach", lp)
			await _wait_frames(2)
	if int(controller.call("get_phase")) != GrappleStateScr.Phase.ATTACHED:
		push_error("%s: C6 setup failed to attach before death." % LABEL)
		quit(1)
		return
	player.call("kill")
	await _wait_frames(20)
	if int(gsm.get("current_state")) != STATE_GAME_OVER:
		push_error("%s: C6 expected GAME_OVER after kill." % LABEL)
		quit(1)
		return
	if int(controller.call("get_phase")) != GrappleStateScr.Phase.IDLE:
		push_error("%s: C6 death must reset grapple to IDLE." % LABEL)
		quit(1)
		return
	if bool(driver.call("is_grappling")):
		push_error("%s: C6 driver must not report grappling after death." % LABEL)
		quit(1)
		return
	_free_node(death_latch)
	print("%s: C6 PASS (death during grapple → GO + reset)" % LABEL)

	# --- Case 9b: GAME_OVER no activation ---
	if movement.has_method("request_air_ability") and bool(movement.call("request_air_ability")):
		push_error("%s: C9b GAME_OVER must not accept air ability." % LABEL)
		quit(1)
		return
	print("%s: C9b PASS (GAME_OVER no air ability)" % LABEL)

	# --- Case 7: restart clear ---
	if not game_scene.has_method("restart_run"):
		push_error("%s: C7 restart_run missing." % LABEL)
		quit(1)
		return
	game_scene.call("restart_run")
	await _wait_frames(POST_START_FRAMES)
	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error("%s: C7 expected PLAYING after restart." % LABEL)
		quit(1)
		return
	player = _find_player(game_scene)
	movement = _find_movement(player)
	driver = _find_grapple_driver(movement)
	controller = driver.call("get_controller") as RefCounted if driver != null else null
	if controller == null:
		push_error("%s: C7 controller missing after restart." % LABEL)
		quit(1)
		return
	if int(controller.call("get_phase")) != GrappleStateScr.Phase.IDLE:
		push_error("%s: C7 restart must leave grapple IDLE." % LABEL)
		quit(1)
		return
	if bool(driver.call("is_pose_locked")):
		push_error("%s: C7 pose must not stay locked after restart." % LABEL)
		quit(1)
		return
	print("%s: C7 PASS (restart clears grapple)" % LABEL)

	print("M5.1 grapple-live smoke PASS")
	quit(0)


func _spawn_anchor(game_scene: Node, world_pos: Vector2) -> Node2D:
	var anchor := Node2D.new()
	anchor.name = "SmokeAnchor"
	anchor.add_to_group(ANCHOR_GROUP)
	var parent: Node = game_scene.get_node_or_null("World")
	if parent == null:
		parent = game_scene
	parent.add_child(anchor)
	anchor.global_position = world_pos
	return anchor


func _clear_anchors(game_scene: Node) -> void:
	var tree: SceneTree = game_scene.get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(ANCHOR_GROUP):
		if node != null and is_instance_valid(node):
			node.queue_free()
	## Allow frees to apply.
	# caller should await frames after clear when needed


func _free_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()


func _freeze_world(game_scene: Node) -> void:
	var velocity: Node = game_scene.get_node_or_null("WorldVelocityController")
	if velocity != null:
		if velocity.has_method("set_target_speed"):
			velocity.call("set_target_speed", 0.0)
		velocity.set("current_speed", 0.0)
		velocity.set("target_speed", 0.0)
	var scroller: Node = game_scene.get_node_or_null("WorldScroller")
	if scroller != null and scroller.has_method("stop"):
		scroller.call("stop")


func _wait_frames(n: int) -> void:
	for _i in range(maxi(n, 0)):
		await physics_frame


func _wait_until_grounded(player: Node, max_frames: int) -> bool:
	for _i in range(max_frames):
		if player != null and bool(player.call("is_on_floor")):
			return true
		await physics_frame
	return player != null and bool(player.call("is_on_floor"))


func _wait_until_standing(player: Node, max_frames: int) -> void:
	await _wait_until_grounded(player, max_frames)
	await _wait_frames(6)


func _wait_until_airborne_or_jump(player: Node, movement: Node, max_frames: int) -> void:
	if player != null and not bool(player.call("is_on_floor")):
		return
	if movement != null and movement.has_method("request_jump"):
		movement.call("request_jump")
	for _i in range(max_frames):
		if player != null and not bool(player.call("is_on_floor")):
			return
		await physics_frame


func _find_game_scene(main: Node) -> Node:
	var container: Node = main.get_node_or_null("GameSceneContainer")
	if container != null and container.get_child_count() > 0:
		return container.get_child(0)
	return main.get_node_or_null("GameScene")


func _find_player(game_scene: Node) -> Node:
	if game_scene == null:
		return null
	var root_player: Node = game_scene.get_node_or_null("PlayerRoot")
	if root_player != null:
		for child: Node in root_player.get_children():
			if child.has_method("is_alive") and child.has_method("kill"):
				return child
	return game_scene.find_child("Player", true, false)


func _find_movement(player: Node) -> Node:
	if player == null:
		return null
	return player.get_node_or_null("PlayerMovement")


func _find_grapple_driver(movement: Node) -> Node:
	if movement == null:
		return null
	var named: Node = movement.get_node_or_null("PlayerGrappleDriver")
	if named != null:
		return named
	if movement.has_method("get_grapple_driver"):
		return movement.call("get_grapple_driver") as Node
	for child: Node in movement.get_children():
		if child.has_method("request_air_ability") and child.has_method("get_controller"):
			return child
	return null


func _find_touch_router(player: Node) -> Object:
	if player == null:
		return null
	var movement: Node = _find_movement(player)
	if movement != null:
		var named: Node = movement.get_node_or_null("TouchGestureRouter")
		if named != null:
			return named
		for child: Node in movement.get_children():
			if child.has_signal("jump_requested"):
				return child
	return null
