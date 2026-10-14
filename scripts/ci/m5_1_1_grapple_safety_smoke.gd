extends SceneTree

## Headless M5.1.1 smoke: Grapple path collisions, boost cap, latch recycle abort.
## Requires dedicated smoke userdata (scripts/ci/smoke_env.sh).
## Usage: source scripts/ci/smoke_env.sh && ri_smoke_env_setup && \
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m5_1_1_grapple_safety_smoke.gd

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const Boot := preload("res://scripts/ci/smoke_boot_helpers.gd")
const GrappleStateScr := preload("res://scripts/grapple/GrappleState.gd")

const WARMUP_FRAMES: int = 90
const POST_START_FRAMES: int = 60
const STATE_PLAYING: int = 2
const STATE_GAME_OVER: int = 4
const LABEL := "M5.1.1 grapple-safety smoke"

const ANCHOR_GROUP := "anchor"
const OVERHEAD_SCENE_PATH := "res://scenes/modules/OverheadObstacleModule.tscn"
const LATCH_SCENE_PATH := "res://scenes/modules/LatchModule.tscn"
const GROUND_Y: float = 918.0
const SEGMENT_GROUND_HEIGHT: float = 40.0
const OVERHEAD_LOCAL_Y: float = -96.0
const OVERHEAD_WORLD_Y: float = GROUND_Y + SEGMENT_GROUND_HEIGHT * 0.5 + OVERHEAD_LOCAL_Y
## Boost ceilings mirrored from GameConfig (keep in sync).
const MAX_WORLD_SPEED: float = 580.0
const MAX_BOOST_WORLD_SPEED: float = 900.0


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
		push_error("%s: Main/GSM/EventBus missing." % LABEL)
		quit(1)
		return

	if not Boot.ensure_playing_from_title(root, LABEL):
		quit(1)
		return
	await _wait_frames(POST_START_FRAMES)

	var game_scene: Node = _find_game_scene(main)
	var player: Node = _find_player(game_scene)
	var movement: Node = _find_movement(player)
	var driver: Node = _find_grapple_driver(movement)
	if game_scene == null or player == null or movement == null or driver == null:
		push_error("%s: GameScene/Player/Movement/Driver missing." % LABEL)
		quit(1)
		return

	_freeze_world(game_scene)
	await _wait_until_grounded(player, 120)

	# --- B1: boost cap / stack / decay / finite ---
	if not await _assert_boost_cap(game_scene):
		quit(1)
		return

	# --- C1: path-swept lethal hit (real PhysicsShapeQuery → resolve_body_overlap) ---
	if not await _assert_path_collision_kill(game_scene, player, movement, driver, gsm, event_bus):
		quit(1)
		return

	# Restart for clean state
	game_scene.call("restart_run")
	await _wait_frames(POST_START_FRAMES)
	_freeze_world(game_scene)
	player = _find_player(game_scene)
	movement = _find_movement(player)
	driver = _find_grapple_driver(movement)
	if player == null or movement == null or driver == null:
		push_error("%s: missing player after restart for C2." % LABEL)
		quit(1)
		return
	await _wait_until_grounded(player, 120)

	# --- C2: negative — clear path, large pose move, stay alive ---
	if not await _assert_path_clear_alive(player, movement, driver):
		quit(1)
		return

	# --- L1: latch recycle / deactivate mid-swing → controlled abort ---
	if not await _assert_latch_recycle_abort(game_scene, player, movement, driver):
		quit(1)
		return

	# --- R1: boost clears on game over / restart ---
	if not await _assert_boost_clears_on_restart(game_scene, player, gsm):
		quit(1)
		return

	print("%s PASS" % LABEL)
	quit(0)


func _assert_boost_cap(game_scene: Node) -> bool:
	var velocity: Node = game_scene.get_node_or_null("WorldVelocityController")
	if velocity == null or not velocity.has_method("apply_speed_boost"):
		push_error("%s: B1 WorldVelocityController.apply_speed_boost missing." % LABEL)
		return false

	velocity.call("start_run")
	velocity.set("current_speed", MAX_WORLD_SPEED)
	velocity.set("target_speed", MAX_WORLD_SPEED)
	velocity.set("max_speed", MAX_WORLD_SPEED)
	velocity.set("max_boost_speed", MAX_BOOST_WORLD_SPEED)

	## Single boost: may exceed progression max but not boost ceiling.
	velocity.call("apply_speed_boost", 400.0, 0.35)
	var after_one: float = float(velocity.get("current_speed"))
	if after_one > MAX_BOOST_WORLD_SPEED + 0.01:
		push_error("%s: B1 single boost exceeded ceiling (%s)." % [LABEL, after_one])
		return false
	if after_one <= MAX_WORLD_SPEED:
		push_error("%s: B1 boost should feel faster than progression max (%s)." % [LABEL, after_one])
		return false

	## Stacked boosts must clamp, not explode.
	velocity.call("apply_speed_boost", 500.0, 0.35)
	velocity.call("apply_speed_boost", 500.0, 0.35)
	var after_stack: float = float(velocity.get("current_speed"))
	if after_stack > MAX_BOOST_WORLD_SPEED + 0.01:
		push_error("%s: B1 stacked boost exceeded ceiling (%s)." % [LABEL, after_stack])
		return false

	## Non-finite / negative rejected.
	var before_bad: float = after_stack
	velocity.call("apply_speed_boost", -100.0, 0.35)
	velocity.call("apply_speed_boost", INF, 0.35)
	velocity.call("apply_speed_boost", 50.0, NAN)
	if absf(float(velocity.get("current_speed")) - before_bad) > 0.01:
		push_error("%s: B1 invalid boost mutated speed." % LABEL)
		return false

	## Decay toward target over duration.
	var dist0: float = float(velocity.get("distance_travelled"))
	for _i in range(30):
		velocity.call("physics_update", 1.0 / 60.0)
	var after_decay: float = float(velocity.get("current_speed"))
	if after_decay > after_stack + 0.01:
		push_error("%s: B1 speed rose during decay." % LABEL)
		return false
	var dist1: float = float(velocity.get("distance_travelled"))
	if dist1 <= dist0:
		push_error("%s: B1 distance must advance during boost window." % LABEL)
		return false
	if not is_finite(after_decay) or after_decay < 0.0:
		push_error("%s: B1 non-finite/negative speed after decay." % LABEL)
		return false

	velocity.call("reset")
	if float(velocity.get("current_speed")) != 0.0 or bool(velocity.call("is_boost_active")):
		push_error("%s: B1 reset must clear boost/speed." % LABEL)
		return false

	print("%s: B1 PASS (boost cap/stack/decay/reset)" % LABEL)
	return true


func _assert_path_collision_kill(
	game_scene: Node,
	player: Node,
	movement: Node,
	driver: Node,
	gsm: Node,
	event_bus: Node,
) -> bool:
	await _wait_until_grounded(player, 120)
	_clear_anchors(game_scene)

	var hit_count: Array = [0]
	if event_bus != null and event_bus.has_signal("player_hit_obstacle"):
		event_bus.player_hit_obstacle.connect(
			func() -> void: hit_count[0] = int(hit_count[0]) + 1
		)

	## Enter swing so pose lock is active (same path as live Grapple).
	movement.call("request_jump")
	await _wait_frames(4)
	var latch: Node2D = _spawn_anchor(
		game_scene,
		Vector2(float(player.global_position.x) + 160.0, float(player.global_position.y) - 180.0),
	)
	await _wait_frames(2)
	movement.call("request_air_ability")
	await _wait_frames(6)
	var controller: RefCounted = driver.call("get_controller") as RefCounted
	if controller == null or int(controller.call("get_phase")) != GrappleStateScr.Phase.ATTACHED:
		push_error("%s: C1 failed to attach before path collision." % LABEL)
		_free_node(latch)
		return false
	if not bool(driver.call("is_pose_locked")):
		push_error("%s: C1 expected pose lock while attached." % LABEL)
		_free_node(latch)
		return false

	## Pause live swing posing so the controlled sweep is not overwritten mid-setup.
	driver.set_physics_process(false)

	## Large vertical teleport that would tunnel through an overhead if only the
	## end point were tested. Start above, end below; hazard at the midpoint.
	var px: float = float(player.global_position.x)
	var start := Vector2(px, OVERHEAD_WORLD_Y - 160.0)
	var end := Vector2(px, OVERHEAD_WORLD_Y + 80.0)
	var mid := start.lerp(end, 0.5)
	player.global_position = start

	var overhead: Node = await _spawn_overhead(game_scene, mid)
	## Keep player at start after spawn frames (activate can take a physics tick).
	player.global_position = start
	await _wait_frames(1)
	player.global_position = start
	if not bool(player.call("is_alive")):
		push_error("%s: C1 player died before path sweep (setup overlap)." % LABEL)
		driver.set_physics_process(true)
		_free_module(overhead)
		_free_node(latch)
		return false

	## End pose alone must clear the hazard AABB (forces mid-path detection).
	var end_player_aabb := Rect2(
		end + Vector2(-24.0, -40.0),
		Vector2(48.0, 72.0)
	)
	var hazard_aabb: Rect2 = _module_hit_aabb(overhead)
	if end_player_aabb.intersects(hazard_aabb):
		push_error(
			"%s: C1 end pose overlaps hazard (need mid-path-only kill); end=%s hazard=%s"
			% [LABEL, end_player_aabb, hazard_aabb]
		)
		driver.set_physics_process(true)
		_free_module(overhead)
		_free_node(latch)
		return false
	if not _segment_crosses_module(start, end, overhead):
		push_error(
			"%s: C1 path must cross hazard (start=%s end=%s hazard=%s)"
			% [LABEL, start, end, hazard_aabb]
		)
		driver.set_physics_process(true)
		_free_module(overhead)
		_free_node(latch)
		return false

	hit_count[0] = 0
	driver.call("debug_move_swing_pose_to", end)
	driver.set_physics_process(true)
	await _wait_frames(4)

	if bool(player.call("is_alive")):
		push_error("%s: C1 path sweep must kill via obstacle overlap (still alive)." % LABEL)
		_free_module(overhead)
		_free_node(latch)
		return false
	if int(hit_count[0]) < 1:
		push_error("%s: C1 expected player_hit_obstacle from real overlap resolve." % LABEL)
		_free_module(overhead)
		_free_node(latch)
		return false
	if int(gsm.get("current_state")) != STATE_GAME_OVER:
		## kill → EventBus → GO may take a frame; wait briefly
		var go_ok := false
		for _i in range(30):
			await physics_frame
			if int(gsm.get("current_state")) == STATE_GAME_OVER:
				go_ok = true
				break
		if not go_ok:
			push_error("%s: C1 expected GAME_OVER after path kill." % LABEL)
			_free_module(overhead)
			_free_node(latch)
			return false

	_free_module(overhead)
	_free_node(latch)
	print("%s: C1 PASS (path-swept lethal overlap → death, hits=%d)" % [LABEL, int(hit_count[0])])
	return true


func _assert_path_clear_alive(player: Node, movement: Node, driver: Node) -> bool:
	await _wait_until_grounded(player, 120)
	movement.call("request_jump")
	await _wait_frames(4)
	var game_scene: Node = player.get_parent()
	while game_scene != null and game_scene.get_node_or_null("WorldVelocityController") == null:
		game_scene = game_scene.get_parent()
	if game_scene == null:
		push_error("%s: C2 GameScene missing." % LABEL)
		return false
	_clear_anchors(game_scene)
	var latch: Node2D = _spawn_anchor(
		game_scene,
		Vector2(float(player.global_position.x) + 160.0, float(player.global_position.y) - 180.0),
	)
	await _wait_frames(2)
	movement.call("request_air_ability")
	await _wait_frames(6)
	var controller: RefCounted = driver.call("get_controller") as RefCounted
	if controller == null or int(controller.call("get_phase")) != GrappleStateScr.Phase.ATTACHED:
		push_error("%s: C2 failed to attach." % LABEL)
		_free_node(latch)
		return false

	var start: Vector2 = player.global_position
	var end := Vector2(start.x + 20.0, start.y + 80.0)
	driver.call("debug_move_swing_pose_to", end)
	await _wait_frames(2)
	if not bool(player.call("is_alive")):
		push_error("%s: C2 clear path must not kill." % LABEL)
		_free_node(latch)
		return false
	if not bool(driver.call("is_pose_locked")) and int(controller.call("get_phase")) != GrappleStateScr.Phase.ATTACHED:
		## Still attached/swinging is OK; abort is not.
		pass
	if int(controller.call("get_phase")) == GrappleStateScr.Phase.IDLE and bool(driver.call("is_pose_locked")):
		push_error("%s: C2 inconsistent IDLE+locked after clear move." % LABEL)
		_free_node(latch)
		return false

	_free_node(latch)
	print("%s: C2 PASS (clear path pose move → alive)" % LABEL)
	return true


func _assert_latch_recycle_abort(
	game_scene: Node,
	player: Node,
	movement: Node,
	driver: Node,
) -> bool:
	## Fresh restart so we are PLAYING
	if int(root.get_node("GameStateManager").get("current_state")) != STATE_PLAYING:
		game_scene.call("restart_run")
		await _wait_frames(POST_START_FRAMES)
		_freeze_world(game_scene)
		player = _find_player(game_scene)
		movement = _find_movement(player)
		driver = _find_grapple_driver(movement)
		await _wait_until_grounded(player, 120)

	_clear_anchors(game_scene)
	movement.call("request_jump")
	await _wait_frames(4)

	var packed: PackedScene = load(LATCH_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("%s: L1 LatchModule.tscn missing." % LABEL)
		return false
	var latch_pos := Vector2(
		float(player.global_position.x) + 150.0,
		float(player.global_position.y) - 170.0,
	)
	var latch_mod: Node2D = await _spawn_latch_module(game_scene, latch_pos)
	await _wait_frames(2)

	movement.call("request_air_ability")
	await _wait_frames(6)
	var controller: RefCounted = driver.call("get_controller") as RefCounted
	if controller == null or int(controller.call("get_phase")) != GrappleStateScr.Phase.ATTACHED:
		push_error("%s: L1 failed to attach to LatchModule." % LABEL)
		_free_node(latch_mod)
		return false

	var pos_before: Vector2 = player.global_position
	## Recycle / invalidate while swinging.
	if latch_mod.has_method("deactivate"):
		latch_mod.call("deactivate")
	await _wait_frames(3)

	if bool(driver.call("is_pose_locked")):
		push_error("%s: L1 pose must unlock after latch deactivate." % LABEL)
		_free_node(latch_mod)
		return false
	if int(controller.call("get_phase")) != GrappleStateScr.Phase.IDLE:
		push_error("%s: L1 controller must reset to IDLE after latch invalidate." % LABEL)
		_free_node(latch_mod)
		return false
	## Must not keep tracking a stale latch forever (position may move under gravity, but
	## rope/pose lock must be gone).
	if driver.has_method("is_grappling") and bool(driver.call("is_grappling")):
		push_error("%s: L1 must not report grappling after latch recycle." % LABEL)
		_free_node(latch_mod)
		return false

	## Free the module entirely (harder recycle) on a second attach.
	_free_node(latch_mod)
	await _wait_frames(2)

	## Second pass: free source mid-swing
	await _wait_until_grounded(player, 180)
	movement.call("request_jump")
	await _wait_frames(4)
	var latch2_pos := Vector2(
		float(player.global_position.x) + 150.0,
		float(player.global_position.y) - 170.0,
	)
	var latch2: Node2D = await _spawn_latch_module(game_scene, latch2_pos)
	await _wait_frames(2)
	movement.call("request_air_ability")
	await _wait_frames(6)
	controller = driver.call("get_controller") as RefCounted
	if controller == null or int(controller.call("get_phase")) != GrappleStateScr.Phase.ATTACHED:
		push_error("%s: L1b failed to attach before free." % LABEL)
		_free_node(latch2)
		return false
	latch2.free()
	await _wait_frames(3)
	if bool(driver.call("is_pose_locked")) or int(controller.call("get_phase")) != GrappleStateScr.Phase.IDLE:
		push_error("%s: L1b free mid-swing must abort Grapple." % LABEL)
		return false

	print("%s: L1 PASS (latch deactivate/free → controlled abort; before=%s)" % [LABEL, pos_before])
	return true


func _assert_boost_clears_on_restart(game_scene: Node, player: Node, gsm: Node) -> bool:
	var velocity: Node = game_scene.get_node_or_null("WorldVelocityController")
	if velocity == null:
		push_error("%s: R1 velocity controller missing." % LABEL)
		return false
	if int(gsm.get("current_state")) != STATE_PLAYING:
		game_scene.call("restart_run")
		await _wait_frames(POST_START_FRAMES)
	velocity.call("start_run")
	velocity.call("apply_speed_boost", 300.0, 0.5)
	if not bool(velocity.call("is_boost_active")):
		push_error("%s: R1 expected active boost before GO." % LABEL)
		return false
	player = _find_player(game_scene)
	if player != null:
		player.call("kill")
	await _wait_frames(20)
	if int(gsm.get("current_state")) != STATE_GAME_OVER:
		push_error("%s: R1 expected GAME_OVER." % LABEL)
		return false
	game_scene.call("restart_run")
	await _wait_frames(POST_START_FRAMES)
	velocity = game_scene.get_node_or_null("WorldVelocityController")
	if velocity == null:
		push_error("%s: R1 velocity missing after restart." % LABEL)
		return false
	if bool(velocity.call("is_boost_active")):
		push_error("%s: R1 boost must clear on restart." % LABEL)
		return false
	var spd: float = float(velocity.get("current_speed"))
	if not is_finite(spd) or spd < 0.0:
		push_error("%s: R1 speed invalid after restart (%s)." % [LABEL, spd])
		return false
	print("%s: R1 PASS (boost cleared on GO/restart)" % LABEL)
	return true


func _spawn_latch_module(game_scene: Node, world_pos: Vector2) -> Node2D:
	var packed: PackedScene = load(LATCH_SCENE_PATH) as PackedScene
	var holder: Node2D = game_scene.get_node_or_null("SmokeLatchHolder") as Node2D
	if holder == null:
		holder = Node2D.new()
		holder.name = "SmokeLatchHolder"
		game_scene.add_child(holder)
	var latch_mod: Node2D = packed.instantiate() as Node2D
	holder.add_child(latch_mod)
	await physics_frame
	if latch_mod.has_method("setup"):
		latch_mod.call("setup", {"local_position": world_pos})
	if latch_mod.has_method("activate"):
		latch_mod.call("activate")
	await physics_frame
	return latch_mod


func _spawn_overhead(game_scene: Node, world_pos: Vector2) -> Node:
	## Match M4.1: holder under GameScene so setup(local_position=world) sticks through activate().
	var packed: PackedScene = load(OVERHEAD_SCENE_PATH) as PackedScene
	var holder: Node2D = game_scene.get_node_or_null("SmokeHazardHolder") as Node2D
	if holder == null:
		holder = Node2D.new()
		holder.name = "SmokeHazardHolder"
		game_scene.add_child(holder)
	var mod: Node = packed.instantiate()
	holder.add_child(mod)
	await physics_frame
	if mod.has_method("setup"):
		mod.call("setup", {"local_position": world_pos})
	if mod.has_method("activate"):
		mod.call("activate")
	await physics_frame
	return mod


func _segment_crosses_module(start: Vector2, end: Vector2, module: Node) -> bool:
	var aabb: Rect2 = _module_hit_aabb(module).grow(8.0)
	## Approximate player standing half-extents along the path.
	var half := Vector2(24.0, 36.0)
	for i in range(0, 33):
		var p: Vector2 = start.lerp(end, float(i) / 32.0)
		var body := Rect2(p - half, half * 2.0)
		if body.intersects(aabb):
			return true
	return false


func _module_hit_aabb(module: Node) -> Rect2:
	var hit_area: Area2D = module.get_node_or_null("HitArea") as Area2D
	var cs: CollisionShape2D = null
	if hit_area != null:
		cs = hit_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs != null and cs.shape is RectangleShape2D:
		var size: Vector2 = (cs.shape as RectangleShape2D).size
		var center: Vector2 = (module as Node2D).global_position
		if cs.global_position != Vector2.ZERO:
			center = cs.global_position
		return Rect2(center - size * 0.5, size)
	var origin: Vector2 = (module as Node2D).global_position
	return Rect2(origin - Vector2(70, 26), Vector2(140, 52))


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


func _free_module(module: Node) -> void:
	if module == null or not is_instance_valid(module):
		return
	if module.has_method("deactivate"):
		module.call("deactivate")
	module.queue_free()


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
	return null
