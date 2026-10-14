extends SceneTree

## Headless M5.1.2-D: integration stabilize across A/B/C.
## Landscape touch layout at multiple resolutions, GO/restart, config coherence,
## spawn still solvable with balance params, Grapple idle after restart.
## Usage: source scripts/ci/smoke_env.sh && ri_smoke_env_setup && \
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m5_1_2_d_stabilize_smoke.gd

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const Boot := preload("res://scripts/ci/smoke_boot_helpers.gd")
const GrappleStateScr := preload("res://scripts/grapple/GrappleState.gd")
const RouterScript := preload("res://scripts/input/TouchGestureRouter.gd")

const LABEL := "M5.1.2-D stabilize smoke"
const ANCHOR_GROUP := "anchor"
const WARMUP_FRAMES: int = 90
const POST_START_FRAMES: int = 50
const POST_KILL_FRAMES: int = 20
const POST_RESTART_FRAMES: int = 40
const STATE_PLAYING: int = 2
const STATE_GAME_OVER: int = 4
const LANDSCAPE_SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1280, 720),
	Vector2i(2340, 1080),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Guard.require_isolated(self, LABEL):
		return

	var GC = preload("res://scripts/core/GameConfig.gd")
	if GC == null:
		push_error("%s: GameConfig missing." % LABEL)
		quit(1)
		return

	## --- C0: balance + player-feel coherence (A+C) ---
	if float(GC.BASE_WORLD_SPEED) < 300.0 or float(GC.MAX_WORLD_SPEED) > 700.0:
		push_error("%s: C0 speed band unexpected." % LABEL)
		quit(1)
		return
	if float(GC.PLAYER_FALL_GRAVITY_MULT) < 1.2 or float(GC.PLAYER_FALL_GRAVITY_MULT) > 2.0:
		push_error("%s: C0 fall mult out of band." % LABEL)
		quit(1)
		return
	if float(GC.PLAYER_JUMP_VELOCITY) < 900.0:
		push_error("%s: C0 jump velocity too low." % LABEL)
		quit(1)
		return
	if float(GC.min_reaction_window_sec()) < 2.5:
		push_error("%s: C0 reaction window too tight." % LABEL)
		quit(1)
		return
	if int(GC.COIN_SCORE_VALUE) < 100:
		push_error("%s: C0 coin value too low." % LABEL)
		quit(1)
		return
	print(
		"%s: C0 PASS speed=%0.0f→%0.0f fall×%0.2f jump=%0.0f react=%0.2fs coin=%d"
		% [
			LABEL,
			float(GC.BASE_WORLD_SPEED),
			float(GC.MAX_WORLD_SPEED),
			float(GC.PLAYER_FALL_GRAVITY_MULT),
			float(GC.PLAYER_JUMP_VELOCITY),
			float(GC.min_reaction_window_sec()),
			int(GC.COIN_SCORE_VALUE),
		]
	)

	## --- R0: swipe dormant API still re-armable ---
	var router: Node = RouterScript.new() as Node
	router.call("set_enabled", true)
	router.call("set_swipe_enabled", false)
	router.call("begin_touch", 0, Vector2(40, 40))
	router.call("update_touch", 0, Vector2(40, 180))
	var off: String = str(router.call("end_touch", 0, Vector2(40, 200)))
	if off == "slide":
		push_error("%s: R0 swipe should be dormant." % LABEL)
		quit(1)
		return
	router.call("set_swipe_enabled", true)
	router.call("begin_touch", 0, Vector2(40, 40))
	router.call("update_touch", 0, Vector2(40, 180))
	var on: String = str(router.call("end_touch", 0, Vector2(40, 200)))
	if on != "slide":
		push_error("%s: R0 swipe re-arm expected slide got %s." % [LABEL, on])
		quit(1)
		return
	router.free()
	print("%s: R0 PASS (swipe dormant + re-armable)" % LABEL)

	var err: Error = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("%s: Main load failed." % LABEL)
		quit(1)
		return
	await _wait_frames(WARMUP_FRAMES)
	if not Boot.ensure_playing_from_title(root, LABEL):
		quit(1)
		return
	await _wait_frames(POST_START_FRAMES)

	var gsm: Node = root.get_node_or_null("GameStateManager")
	var event_bus: Node = root.get_node_or_null("EventBus")
	var main: Node = Boot.find_main(root)
	var game_scene: Node = _find_game_scene(main)
	var player: Node = _find_player(game_scene)
	var movement: Node = _find_movement(player)
	var touch: Node = game_scene.get_node_or_null("TouchControls") if game_scene else null
	var spawner: Node = game_scene.get_node_or_null("ModuleSpawner") if game_scene else null
	var difficulty: Node = game_scene.get_node_or_null("DifficultyDirector") if game_scene else null
	if (
		gsm == null
		or event_bus == null
		or game_scene == null
		or player == null
		or movement == null
		or touch == null
		or spawner == null
		or difficulty == null
	):
		push_error("%s: required scene nodes missing." % LABEL)
		quit(1)
		return

	## --- L1: landscape touch layout across resolutions ---
	for size: Vector2i in LANDSCAPE_SIZES:
		if size.x <= size.y:
			push_error("%s: L1 fixture not landscape %s" % [LABEL, str(size)])
			quit(1)
			return
		DisplayServer.window_set_size(size)
		root.get_viewport().size = size
		await _wait_frames(4)
		if not bool(touch.visible):
			push_error("%s: L1 TouchControls hidden at %s" % [LABEL, str(size)])
			quit(1)
			return
		var slide: Control = touch.get_node_or_null("Root/SlideButton") as Control
		var jump: Control = touch.get_node_or_null("Root/JumpButton") as Control
		if slide == null or jump == null:
			push_error("%s: L1 buttons missing at %s" % [LABEL, str(size)])
			quit(1)
			return
		var sr: Rect2 = slide.get_global_rect()
		var jr: Rect2 = jump.get_global_rect()
		if sr.size.x < 80.0 or sr.size.y < 80.0 or jr.size.x < 80.0 or jr.size.y < 80.0:
			push_error(
				"%s: L1 button too small at %s slide=%s jump=%s"
				% [LABEL, str(size), str(sr.size), str(jr.size)]
			)
			quit(1)
			return
		if jr.position.x <= sr.position.x:
			push_error("%s: L1 JUMP must be right of SLIDE at %s" % [LABEL, str(size)])
			quit(1)
			return
		if sr.position.x > float(size.x) * 0.45:
			push_error("%s: L1 SLIDE not left-biased at %s" % [LABEL, str(size)])
			quit(1)
			return
		if jr.end.x < float(size.x) * 0.55:
			push_error("%s: L1 JUMP not right-biased at %s" % [LABEL, str(size)])
			quit(1)
			return
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.get_viewport().size = Vector2i(1920, 1080)
	await _wait_frames(4)
	print("%s: L1 PASS landscape layouts %s" % [LABEL, str(LANDSCAPE_SIZES)])

	## --- S1: spawn still has latches / overhead / coins under current balance ---
	difficulty.set("current_level", 2)
	var counts: Dictionary = _scan(spawner, 48)
	if int(counts.get("latch", 0)) < 3:
		push_error("%s: S1 latches too sparse %s" % [LABEL, counts])
		quit(1)
		return
	if int(counts.get("overhead", 0)) < 1:
		push_error("%s: S1 need overhead for SLIDE %s" % [LABEL, counts])
		quit(1)
		return
	if int(counts.get("coin", 0)) < 2:
		push_error("%s: S1 coins missing %s" % [LABEL, counts])
		quit(1)
		return
	print("%s: S1 PASS spawn level2 %s" % [LABEL, counts])

	## --- G1: grounded JUMP + air miss path still live ---
	_freeze_world(game_scene)
	await _wait_until_grounded(player, 120)
	var jump_n: Array = [0]
	var miss_n: Array = [0]
	event_bus.player_jumped.connect(func() -> void: jump_n[0] = int(jump_n[0]) + 1)
	if event_bus.has_signal("player_grapple_missed"):
		event_bus.player_grapple_missed.connect(func() -> void: miss_n[0] = int(miss_n[0]) + 1)
	touch.emit_signal("jump_pressed")
	await _wait_frames(6)
	if int(jump_n[0]) < 1:
		push_error("%s: G1 grounded jump failed." % LABEL)
		quit(1)
		return
	await _wait_frames(4)
	if bool(player.call("is_on_floor")):
		player.set("velocity", Vector2(0.0, -700.0))
		await _wait_frames(3)
	_clear_anchors(game_scene)
	miss_n[0] = 0
	touch.emit_signal("jump_pressed")
	await _wait_frames(10)
	if int(miss_n[0]) < 1:
		push_error("%s: G1 expected grapple miss while airborne without latch." % LABEL)
		quit(1)
		return
	print("%s: G1 PASS jump+miss (j=%d m=%d)" % [LABEL, int(jump_n[0]), int(miss_n[0])])

	## --- K1: game over hides controls; restart restores + Grapple idle ---
	await _wait_until_grounded(player, 180)
	player.call("kill")
	await _wait_frames(POST_KILL_FRAMES)
	if int(gsm.get("current_state")) != STATE_GAME_OVER:
		push_error("%s: K1 expected GAME_OVER got %d" % [LABEL, int(gsm.get("current_state"))])
		quit(1)
		return
	if bool(touch.visible):
		push_error("%s: K1 TouchControls should hide on game over." % LABEL)
		quit(1)
		return
	game_scene.call("restart_run")
	await _wait_frames(POST_RESTART_FRAMES)
	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error("%s: K1 expected PLAYING after restart got %d" % [LABEL, int(gsm.get("current_state"))])
		quit(1)
		return
	if not bool(touch.visible):
		push_error("%s: K1 TouchControls not restored after restart." % LABEL)
		quit(1)
		return
	var driver: Node = movement.get_node_or_null("PlayerGrappleDriver")
	if driver == null:
		push_error("%s: K1 PlayerGrappleDriver missing." % LABEL)
		quit(1)
		return
	if bool(driver.call("is_grappling")):
		push_error("%s: K1 Grapple still active after restart." % LABEL)
		quit(1)
		return
	var controller: Object = driver.call("get_controller")
	if controller == null or int(controller.call("get_phase")) != int(GrappleStateScr.Phase.IDLE):
		push_error("%s: K1 Grapple not IDLE after restart." % LABEL)
		quit(1)
		return
	print("%s: K1 PASS GO hide + restart restore + Grapple idle" % LABEL)

	## --- O1: no obvious orphan explosion after restart cycle ---
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphans > 64:
		push_error("%s: O1 orphan node count high (%d)" % [LABEL, orphans])
		quit(1)
		return
	print("%s: O1 PASS orphans=%d" % [LABEL, orphans])

	print("%s PASS" % LABEL)
	quit(0)


func _scan(spawner: Node, n: int) -> Dictionary:
	var counts := {
		"safe": 0,
		"latch": 0,
		"low": 0,
		"tall": 0,
		"overhead": 0,
		"double": 0,
		"coin": 0,
		"empty": 0,
	}
	for i: int in range(n):
		var kind: String = str(spawner.call("debug_classify_segment", i))
		if counts.has(kind):
			counts[kind] = int(counts[kind]) + 1
		else:
			counts[kind] = 1
	return counts


func _find_game_scene(main: Node) -> Node:
	if main == null:
		return null
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


func _freeze_world(game_scene: Node) -> void:
	var velocity: Node = game_scene.get_node_or_null("WorldVelocityController")
	if velocity != null:
		velocity.set("current_speed", 0.0)
		velocity.set("target_speed", 0.0)
	var scroller: Node = game_scene.get_node_or_null("WorldScroller")
	if scroller != null and scroller.has_method("stop"):
		scroller.call("stop")


func _clear_anchors(game_scene: Node) -> void:
	var tree: SceneTree = game_scene.get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(ANCHOR_GROUP):
		if node != null and is_instance_valid(node):
			node.queue_free()


func _wait_until_grounded(player: Node, max_frames: int) -> bool:
	for _i in range(max_frames):
		if player != null and bool(player.call("is_on_floor")):
			return true
		await physics_frame
	return player != null and bool(player.call("is_on_floor"))


func _wait_frames(n: int) -> void:
	for _i in range(maxi(n, 0)):
		await physics_frame
