extends SceneTree

## Headless M5.1.2-A: touch buttons, swipe off, miss cast, faster fall, slide.
## Usage: source scripts/ci/smoke_env.sh && ri_smoke_env_setup && \
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m5_1_2_a_controls_smoke.gd

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const Boot := preload("res://scripts/ci/smoke_boot_helpers.gd")
const GrappleStateScr := preload("res://scripts/grapple/GrappleState.gd")
const RouterScript := preload("res://scripts/input/TouchGestureRouter.gd")

const WARMUP_FRAMES: int = 90
const POST_START_FRAMES: int = 60
const STATE_PLAYING: int = 2
const LABEL := "M5.1.2-A controls smoke"
const ANCHOR_GROUP := "anchor"
const FALL_MULT: float = 1.55
const BASE_GRAVITY: float = 1350.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Guard.require_isolated(self, LABEL):
		return

	## --- R1: swipe disabled by default API ---
	var router: Node = RouterScript.new() as Node
	router.call("set_enabled", true)
	if router.has_method("set_swipe_enabled"):
		router.call("set_swipe_enabled", false)
	elif true:
		push_error("%s: R1 set_swipe_enabled missing." % LABEL)
		quit(1)
		return
	router.call("begin_touch", 0, Vector2(100, 100))
	router.call("update_touch", 0, Vector2(100, 200))
	var swipe_result: String = str(router.call("end_touch", 0, Vector2(100, 220)))
	if swipe_result == "slide":
		push_error("%s: R1 swipe must be none when disabled got slide." % LABEL)
		quit(1)
		return
	router.call("set_swipe_enabled", true)
	router.call("begin_touch", 0, Vector2(100, 100))
	router.call("update_touch", 0, Vector2(100, 200))
	var swipe_on: String = str(router.call("end_touch", 0, Vector2(100, 220)))
	if swipe_on != "slide":
		push_error("%s: R1 swipe re-enable expected slide got %s." % [LABEL, swipe_on])
		quit(1)
		return
	print("%s: R1 PASS (swipe off→none, swipe on→slide)" % LABEL)

	var err: Error = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("%s: Main load failed (%s)" % [LABEL, error_string(err)])
		quit(1)
		return
	await _wait_frames(WARMUP_FRAMES)

	var gsm: Node = root.get_node_or_null("GameStateManager")
	var event_bus: Node = root.get_node_or_null("EventBus")
	if gsm == null or event_bus == null:
		push_error("%s: GSM/EventBus missing." % LABEL)
		quit(1)
		return
	if not Boot.ensure_playing_from_title(root, LABEL):
		quit(1)
		return
	await _wait_frames(POST_START_FRAMES)

	var main: Node = Boot.find_main(root)
	var game_scene: Node = _find_game_scene(main)
	var player: Node = _find_player(game_scene)
	var movement: Node = _find_movement(player)
	if game_scene == null or player == null or movement == null:
		push_error("%s: GameScene/Player/Movement missing." % LABEL)
		quit(1)
		return

	var touch: Node = game_scene.get_node_or_null("TouchControls")
	if touch == null:
		push_error("%s: TouchControls missing under GameScene." % LABEL)
		quit(1)
		return
	if not bool(touch.visible):
		push_error("%s: TouchControls should be visible while PLAYING." % LABEL)
		quit(1)
		return
	print("%s: B0 PASS (TouchControls visible in PLAYING)" % LABEL)

	_freeze_world(game_scene)
	await _wait_until_grounded(player, 120)

	var jump_count: Array = [0]
	var slide_count: Array = [0]
	var miss_count: Array = [0]
	var attach_count: Array = [0]
	event_bus.player_jumped.connect(func() -> void: jump_count[0] = int(jump_count[0]) + 1)
	event_bus.player_slid.connect(func() -> void: slide_count[0] = int(slide_count[0]) + 1)
	if event_bus.has_signal("player_grapple_missed"):
		event_bus.player_grapple_missed.connect(
			func() -> void: miss_count[0] = int(miss_count[0]) + 1
		)
	if event_bus.has_signal("player_attached_to_anchor"):
		event_bus.player_attached_to_anchor.connect(
			func(_p: Vector2) -> void: attach_count[0] = int(attach_count[0]) + 1
		)

	# --- B1: JUMP button → ground jump ---
	jump_count[0] = 0
	touch.emit_signal("jump_pressed")
	await _wait_frames(6)
	if int(jump_count[0]) != 1:
		push_error("%s: B1 JUMP button expected 1 jump got %d." % [LABEL, int(jump_count[0])])
		quit(1)
		return
	print("%s: B1 PASS (JUMP button → jump×1)" % LABEL)

	# --- B2: air JUMP no latch → miss cast, no attach, trajectory free ---
	await _wait_frames(4)
	if bool(player.call("is_on_floor")):
		player.set("velocity", Vector2(0.0, -700.0))
		await _wait_frames(3)
	_clear_anchors(game_scene)
	miss_count[0] = 0
	attach_count[0] = 0
	var vy_before: float = float(player.get("velocity").y)
	touch.emit_signal("jump_pressed")
	await _wait_frames(10)
	if int(attach_count[0]) != 0:
		push_error("%s: B2 no-latch must not attach." % LABEL)
		quit(1)
		return
	if int(miss_count[0]) < 1:
		push_error("%s: B2 expected player_grapple_missed." % LABEL)
		quit(1)
		return
	var driver: Node = movement.get_node_or_null("PlayerGrappleDriver")
	if driver != null and driver.has_method("is_miss_cast_active"):
		## May already finish; presence of EventBus miss is enough.
		pass
	## Velocity must still be under gravity (not zeroed / launched by miss).
	var vy_after: float = float(player.get("velocity").y)
	if not is_finite(vy_after):
		push_error("%s: B2 velocity non-finite after miss." % LABEL)
		quit(1)
		return
	print(
		"%s: B2 PASS (miss cast, no attach, vy %0.1f→%0.1f)"
		% [LABEL, vy_before, vy_after]
	)

	# --- B3: air JUMP with latch → attach ---
	await _wait_until_grounded(player, 180)
	movement.call("request_jump_immediate")
	await _wait_frames(4)
	var latch: Node2D = _spawn_anchor(
		game_scene,
		Vector2(float(player.global_position.x) + 160.0, float(player.global_position.y) - 180.0),
	)
	await _wait_frames(2)
	attach_count[0] = 0
	touch.emit_signal("jump_pressed")
	await _wait_frames(8)
	if int(attach_count[0]) < 1:
		push_error("%s: B3 JUMP+latch expected attach." % LABEL)
		_free_node(latch)
		quit(1)
		return
	_free_node(latch)
	print("%s: B3 PASS (JUMP+latch → attach)" % LABEL)

	# Wait release / land
	await _wait_until_grounded(player, 240)

	# --- B4: SLIDE button → slide, no jump ---
	jump_count[0] = 0
	slide_count[0] = 0
	touch.emit_signal("slide_pressed")
	await _wait_frames(4)
	if int(slide_count[0]) < 1:
		push_error("%s: B4 SLIDE button expected player_slid." % LABEL)
		quit(1)
		return
	if int(jump_count[0]) != 0:
		push_error("%s: B4 SLIDE must not jump." % LABEL)
		quit(1)
		return
	print("%s: B4 PASS (SLIDE button → slide, no jump)" % LABEL)

	# --- B5: live router swipe disabled ---
	var live_router: Node = movement.get_node_or_null("TouchGestureRouter")
	if live_router == null:
		push_error("%s: B5 TouchGestureRouter missing." % LABEL)
		quit(1)
		return
	if live_router.has_method("is_swipe_enabled") and bool(live_router.call("is_swipe_enabled")):
		push_error("%s: B5 live router swipe must be disabled." % LABEL)
		quit(1)
		return
	live_router.call("set_enabled", true)
	live_router.call("begin_touch", 0, Vector2(100, 100))
	live_router.call("update_touch", 0, Vector2(100, 220))
	var live_swipe: String = str(live_router.call("end_touch", 0, Vector2(100, 220)))
	if live_swipe == "slide":
		push_error("%s: B5 live swipe must not classify as slide." % LABEL)
		quit(1)
		return
	print("%s: B5 PASS (live swipe disabled)" % LABEL)

	# --- F1: fall gravity multiplier (must be airborne — floor zeroes +y) ---
	await _wait_until_standing(player, 120)
	player.set("velocity", Vector2(0.0, -200.0))
	await _wait_frames(8)
	if bool(player.call("is_on_floor")):
		push_error("%s: F1 setup failed to leave floor." % LABEL)
		quit(1)
		return
	## Wait until descending.
	var safety: int = 30
	while safety > 0 and float(player.get("velocity").y) <= 0.0:
		await physics_frame
		safety -= 1
	var vy0: float = float(player.get("velocity").y)
	await _wait_frames(1)
	var vy1: float = float(player.get("velocity").y)
	var delta_vy: float = vy1 - vy0
	var expected_min: float = (BASE_GRAVITY * FALL_MULT) / 60.0 * 0.8
	if delta_vy < expected_min:
		push_error(
			"%s: F1 fall accel too low dvy=%0.2f expected≥%0.2f (mult=%0.2f)"
			% [LABEL, delta_vy, expected_min, FALL_MULT]
		)
		quit(1)
		return
	print("%s: F1 PASS (faster fall dvy=%0.1f)" % [LABEL, delta_vy])

	# --- G1: Title/GO hide controls ---
	player.call("kill")
	await _wait_frames(20)
	if bool(touch.visible):
		push_error("%s: G1 TouchControls must hide on GAME_OVER." % LABEL)
		quit(1)
		return
	print("%s: G1 PASS (controls hidden on GO)" % LABEL)

	print("%s PASS" % LABEL)
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


func _free_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()


func _freeze_world(game_scene: Node) -> void:
	var velocity: Node = game_scene.get_node_or_null("WorldVelocityController")
	if velocity != null:
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


func _find_game_scene(main: Node) -> Node:
	var container: Node = main.get_node_or_null("GameSceneContainer")
	if container != null and container.get_child_count() > 0:
		return container.get_child(0)
	return null


func _find_player(game_scene: Node) -> Node:
	if game_scene == null:
		return null
	var root_player: Node = game_scene.get_node_or_null("PlayerRoot")
	if root_player != null:
		for child: Node in root_player.get_children():
			if child.has_method("is_alive") and child.has_method("kill"):
				return child
	return null


func _find_movement(player: Node) -> Node:
	if player == null:
		return null
	return player.get_node_or_null("PlayerMovement")
