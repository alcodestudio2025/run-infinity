extends SceneTree

## Headless M4.1 smoke: real physics slide vs overhead collision.
## Proves standing hitbox dies on overhead, sliding hitbox clears by geometry,
## hitbox restores after slide duration, and restart restores standing.
## Requires dedicated smoke userdata (scripts/ci/smoke_env.sh).
## Usage: source scripts/ci/smoke_env.sh && ri_smoke_env_setup && \
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m4_1_slide_collision_smoke.gd
##
## Autoload singletons / class_name globals are NOT used at parse time (-s launch).
## Numeric constants mirror GameConfig.gd — keep in sync if tuning changes.
## Note: coordinator should wire this into .github/workflows/godot-ci.yml.

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const Boot := preload("res://scripts/ci/smoke_boot_helpers.gd")

const WARMUP_FRAMES: int = 90
const POST_START_FRAMES: int = 60
const STATE_PLAYING: int = 2
const STATE_GAME_OVER: int = 4
const STATE_SLIDING: int = 4
const LABEL := "M4.1 slide-collision smoke"

## Mirror GameConfig (VIEWPORT_HEIGHT=1080, GROUND_SURFACE_RATIO=0.85 → GROUND_Y=918).
const GROUND_Y: float = 918.0
const SEGMENT_GROUND_HEIGHT: float = 40.0
const OVERHEAD_LOCAL_Y: float = -96.0
const LOW_CURB_LOCAL_Y: float = -18.0
## segment.center_y + local_y
const OVERHEAD_WORLD_Y: float = GROUND_Y + SEGMENT_GROUND_HEIGHT * 0.5 + OVERHEAD_LOCAL_Y
const LOW_CURB_WORLD_Y: float = GROUND_Y + SEGMENT_GROUND_HEIGHT * 0.5 + LOW_CURB_LOCAL_Y

const SLIDE_DURATION: float = 0.45
const STANDING_HITBOX_SIZE := Vector2(48.0, 72.0)
const STANDING_HITBOX_POSITION := Vector2(0.0, -4.0)
const SLIDING_HITBOX_SIZE := Vector2(64.0, 38.0)
const SLIDING_HITBOX_POSITION := Vector2(0.0, 13.0)

const OVERHEAD_SCENE_PATH := "res://scenes/modules/OverheadObstacleModule.tscn"
const LOW_CURB_SCENE_PATH := "res://scenes/modules/ObstacleModule.tscn"


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
	if gsm == null:
		push_error("%s: GameStateManager missing." % LABEL)
		quit(1)
		return

	if not Boot.ensure_playing_from_title(root, LABEL):
		quit(1)
		return
	await _wait_frames(POST_START_FRAMES)

	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error("%s: expected PLAYING after start_game." % LABEL)
		quit(1)
		return

	var game_scene: Node = _find_game_scene()
	var player: Node = _find_player(game_scene)
	var movement: Node = _find_movement(player)
	if game_scene == null or player == null or movement == null:
		push_error("%s: GameScene / Player / PlayerMovement missing." % LABEL)
		quit(1)
		return

	if not movement.has_method("request_slide"):
		push_error("%s: PlayerMovement.request_slide missing." % LABEL)
		quit(1)
		return

	var overhead_scene: PackedScene = load(OVERHEAD_SCENE_PATH) as PackedScene
	var low_curb_scene: PackedScene = load(LOW_CURB_SCENE_PATH) as PackedScene
	if overhead_scene == null or low_curb_scene == null:
		push_error("%s: failed to load module scenes." % LABEL)
		quit(1)
		return

	## Freeze world scroll so natural modules cannot interfere; safe-start is empty anyway.
	_freeze_world(game_scene)
	await _wait_until_grounded(player, 120)

	var restore_frames: int = int(ceil(SLIDE_DURATION * 60.0)) + 12

	# --- Case H1: standing vs sliding hitbox sizes differ ---
	var standing_hb: Dictionary = _read_hitbox(player)
	if not _hitbox_matches(standing_hb, STANDING_HITBOX_SIZE, STANDING_HITBOX_POSITION):
		push_error(
			"%s: H1 standing hitbox unexpected size=%s pos=%s"
			% [LABEL, standing_hb.get("size"), standing_hb.get("position")]
		)
		quit(1)
		return

	movement.call("request_slide")
	await _wait_frames(2)
	var sliding_hb: Dictionary = _read_hitbox(player)
	if not _hitbox_matches(sliding_hb, SLIDING_HITBOX_SIZE, SLIDING_HITBOX_POSITION):
		push_error(
			"%s: H1 sliding hitbox unexpected size=%s pos=%s"
			% [LABEL, sliding_hb.get("size"), sliding_hb.get("position")]
		)
		quit(1)
		return
	if int(player.call("get_state")) != STATE_SLIDING:
		push_error("%s: H1 expected SLIDING state after request_slide." % LABEL)
		quit(1)
		return
	print("%s: H1 PASS (hitbox standing→sliding)" % LABEL)

	# --- Case H2: after slide duration, hitbox restored ---
	await _wait_frames(restore_frames)
	var restored_hb: Dictionary = _read_hitbox(player)
	if not _hitbox_matches(restored_hb, STANDING_HITBOX_SIZE, STANDING_HITBOX_POSITION):
		push_error(
			"%s: H2 hitbox not restored after slide (size=%s pos=%s)"
			% [LABEL, restored_hb.get("size"), restored_hb.get("position")]
		)
		quit(1)
		return
	if int(player.call("get_state")) == STATE_SLIDING:
		push_error("%s: H2 still SLIDING after duration." % LABEL)
		quit(1)
		return
	print("%s: H2 PASS (hitbox restored after %d frames)" % [LABEL, restore_frames])

	# --- Case G1/G2: AABB geometry vs overhead at real world Y ---
	## Shape-only probe: setup without activate so Area2D cannot kill during measure.
	var overhead_probe: Node = await _spawn_module(
		game_scene,
		overhead_scene,
		Vector2(float(player.global_position.x), OVERHEAD_WORLD_Y),
		false
	)
	if not bool(player.call("is_alive")):
		push_error("%s: G1 player died before geometry measure (probe must stay inert)." % LABEL)
		quit(1)
		return
	var stand_aabb: Rect2 = _player_hitbox_aabb(player)
	var overhead_aabb: Rect2 = _module_hit_aabb(overhead_probe)
	if not stand_aabb.intersects(overhead_aabb):
		push_error(
			"%s: G1 standing AABB must overlap overhead (player=%s overhead=%s)"
			% [LABEL, stand_aabb, overhead_aabb]
		)
		quit(1)
		return
	print("%s: G1 PASS (standing AABB overlaps overhead)" % LABEL)

	movement.call("request_slide")
	await _wait_frames(2)
	if int(player.call("get_state")) != STATE_SLIDING:
		push_error("%s: G2 expected SLIDING for geometry measure." % LABEL)
		quit(1)
		return
	var slide_aabb: Rect2 = _player_hitbox_aabb(player)
	overhead_aabb = _module_hit_aabb(overhead_probe)
	if slide_aabb.intersects(overhead_aabb):
		push_error(
			"%s: G2 sliding AABB must NOT overlap overhead (player=%s overhead=%s)"
			% [LABEL, slide_aabb, overhead_aabb]
		)
		quit(1)
		return
	print("%s: G2 PASS (sliding AABB clears overhead by geometry)" % LABEL)

	_free_module(overhead_probe)
	await _wait_frames(restore_frames)
	await _wait_until_standing(player, 90)

	# --- Case S1: standing into overhead → death (real Area2D collision) ---
	var died: Array = [0]
	var event_bus: Node = root.get_node_or_null("EventBus")
	if event_bus != null and event_bus.has_signal("player_hit_obstacle"):
		event_bus.player_hit_obstacle.connect(
			func() -> void: died[0] = int(died[0]) + 1
		)

	var kill_overhead: Node = await _spawn_module(
		game_scene,
		overhead_scene,
		Vector2(float(player.global_position.x), OVERHEAD_WORLD_Y)
	)
	await _nudge_module_across_player(kill_overhead, player, 10)
	var dead_ok: bool = await _wait_until_dead_or_game_over(gsm, player, 90)
	if not dead_ok:
		push_error("%s: S1 standing player did not die on overhead collision." % LABEL)
		quit(1)
		return
	print(
		"%s: S1 PASS (standing overhead → death hits=%d state=%d)"
		% [LABEL, int(died[0]), int(gsm.get("current_state"))]
	)

	_free_module(kill_overhead)

	# --- Case S2: sliding clears same overhead without dying ---
	if not game_scene.has_method("restart_run"):
		push_error("%s: GameScene.restart_run missing." % LABEL)
		quit(1)
		return
	game_scene.call("restart_run")
	await _wait_frames(POST_START_FRAMES)
	_freeze_world(game_scene)
	player = _find_player(game_scene)
	movement = _find_movement(player)
	if player == null or movement == null:
		push_error("%s: S2 player missing after restart." % LABEL)
		quit(1)
		return
	await _wait_until_grounded(player, 120)

	died[0] = 0
	movement.call("request_slide")
	await _wait_frames(2)
	if int(player.call("get_state")) != STATE_SLIDING:
		push_error("%s: S2 failed to enter SLIDING." % LABEL)
		quit(1)
		return

	var clear_overhead: Node = await _spawn_module(
		game_scene,
		overhead_scene,
		Vector2(float(player.global_position.x), OVERHEAD_WORLD_Y)
	)
	## Sweep across while sliding; assert alive every frame of the sweep.
	for _step: int in range(14):
		await physics_frame
		if clear_overhead is Node2D and player != null:
			var px: float = float(player.global_position.x)
			var t: float = float(_step + 1) / 14.0
			(clear_overhead as Node2D).global_position = Vector2(
				lerpf(px + 80.0, px - 80.0, t),
				OVERHEAD_WORLD_Y
			)
		if not bool(player.call("is_alive")) or int(gsm.get("current_state")) == STATE_GAME_OVER:
			push_error("%s: S2 died while sliding under overhead." % LABEL)
			quit(1)
			return
		if int(player.call("get_state")) != STATE_SLIDING:
			push_error("%s: S2 left SLIDING mid-sweep (state=%d)." % [LABEL, int(player.call("get_state"))])
			quit(1)
			return

	## Park hazard far away before slide ends so restore cannot stand-up-into-bar.
	if clear_overhead is Node2D:
		(clear_overhead as Node2D).global_position = Vector2(
			float(player.global_position.x) - 400.0,
			OVERHEAD_WORLD_Y
		)
	_deactivate_module(clear_overhead)

	if int(died[0]) != 0:
		push_error("%s: S2 player_hit_obstacle fired while sliding." % LABEL)
		quit(1)
		return
	if not bool(player.call("is_alive")):
		push_error("%s: S2 player dead after slide clear." % LABEL)
		quit(1)
		return
	print("%s: S2 PASS (slide clears overhead, still alive)" % LABEL)

	# --- Case S3: after slide ends, restored standing hitbox dies on same overhead ---
	## Sliding AABB misses geometry, so body_entered never fired during S2.
	## Wait for restore, then re-sweep — proves standing hitbox is back.
	await _wait_frames(restore_frames)
	await _wait_until_standing(player, 90)
	var post_slide_hb: Dictionary = _read_hitbox(player)
	if not _hitbox_matches(post_slide_hb, STANDING_HITBOX_SIZE, STANDING_HITBOX_POSITION):
		push_error(
			"%s: S3 hitbox not standing after slide (size=%s pos=%s)"
			% [LABEL, post_slide_hb.get("size"), post_slide_hb.get("position")]
		)
		quit(1)
		return
	died[0] = 0
	await _nudge_module_across_player(clear_overhead, player, 12)
	var restored_dead: bool = await _wait_until_dead_or_game_over(gsm, player, 90)
	if not restored_dead:
		push_error("%s: S3 expected death when standing hitbox re-enters overhead." % LABEL)
		quit(1)
		return
	print("%s: S3 PASS (restored standing hitbox → overhead death)" % LABEL)
	_free_module(clear_overhead)

	# --- Case R1: restart restores standing hitbox ---
	game_scene.call("restart_run")
	await _wait_frames(POST_START_FRAMES)
	_freeze_world(game_scene)
	player = _find_player(game_scene)
	movement = _find_movement(player)
	if player == null:
		push_error("%s: R1 player missing after restart." % LABEL)
		quit(1)
		return
	await _wait_until_grounded(player, 120)
	var post_restart_hb: Dictionary = _read_hitbox(player)
	if not _hitbox_matches(post_restart_hb, STANDING_HITBOX_SIZE, STANDING_HITBOX_POSITION):
		push_error(
			"%s: R1 standing hitbox not restored after restart (size=%s pos=%s)"
			% [LABEL, post_restart_hb.get("size"), post_restart_hb.get("position")]
		)
		quit(1)
		return
	if int(player.call("get_state")) == STATE_SLIDING:
		push_error("%s: R1 unexpected SLIDING after restart." % LABEL)
		quit(1)
		return
	print("%s: R1 PASS (restart → standing hitbox)" % LABEL)

	# --- Case J1: jump while sliding is ignored ---
	movement.call("request_slide")
	await _wait_frames(2)
	if int(player.call("get_state")) != STATE_SLIDING:
		push_error("%s: J1 could not start slide." % LABEL)
		quit(1)
		return
	var y_before: float = float(player.global_position.y)
	movement.call("request_jump")
	await _wait_frames(6)
	var y_after: float = float(player.global_position.y)
	## Jump would lift Y significantly; allow tiny physics settle.
	if y_after < y_before - 20.0:
		push_error(
			"%s: J1 jump escaped slide (y_before=%0.1f y_after=%0.1f state=%d)"
			% [LABEL, y_before, y_after, int(player.call("get_state"))]
		)
		quit(1)
		return
	if int(player.call("get_state")) == 2: ## JUMPING
		push_error("%s: J1 entered JUMPING during/after blocked slide jump." % LABEL)
		quit(1)
		return
	print("%s: J1 PASS (jump ignored while sliding)" % LABEL)

	await _wait_frames(restore_frames)
	await _wait_until_standing(player, 90)

	# --- Case L1: low curb still kills while sliding ---
	died[0] = 0
	movement.call("request_slide")
	await _wait_frames(2)
	var low: Node = await _spawn_module(
		game_scene,
		low_curb_scene,
		Vector2(float(player.global_position.x), LOW_CURB_WORLD_Y)
	)
	await _nudge_module_across_player(low, player, 10)
	var low_dead: bool = await _wait_until_dead_or_game_over(gsm, player, 90)
	if not low_dead:
		push_error("%s: L1 sliding player should still die on low curb." % LABEL)
		quit(1)
		return
	print("%s: L1 PASS (slide does not clear low curb)" % LABEL)
	_free_module(low)

	print(
		"%s PASS (H1 H2 G1 G2 S1 S2 S3 R1 J1 L1 | overhead_y=%0.1f slide=%.2fs)"
		% [LABEL, OVERHEAD_WORLD_Y, SLIDE_DURATION]
	)
	quit(0)


func _freeze_world(game_scene: Node) -> void:
	var scroller: Node = game_scene.get_node_or_null("WorldScroller")
	if scroller != null and scroller.has_method("stop"):
		scroller.call("stop")
	var velocity: Node = game_scene.get_node_or_null("WorldVelocityController")
	if velocity != null and velocity.has_method("stop_run"):
		velocity.call("stop_run")


func _spawn_module(
	game_scene: Node,
	scene: PackedScene,
	world_pos: Vector2,
	activate: bool = true
) -> Node:
	var holder: Node2D = game_scene.get_node_or_null("SmokeHazardHolder") as Node2D
	if holder == null:
		holder = Node2D.new()
		holder.name = "SmokeHazardHolder"
		game_scene.add_child(holder)
	var mod: Node = scene.instantiate()
	holder.add_child(mod)
	## Ensure _ready ran (collision shape + signals).
	await physics_frame
	if mod.has_method("setup"):
		mod.call("setup", {"local_position": world_pos})
	if activate and mod.has_method("activate"):
		mod.call("activate")
	elif not activate and mod.has_method("deactivate"):
		## _ready may leave HitArea monitoring on until first deactivate.
		mod.call("deactivate")
	await physics_frame
	return mod


func _deactivate_module(mod: Node) -> void:
	if mod != null and is_instance_valid(mod) and mod.has_method("deactivate"):
		mod.call("deactivate")


func _reactivate_module(mod: Node) -> void:
	if mod != null and is_instance_valid(mod) and mod.has_method("activate"):
		mod.call("activate")


func _free_module(mod: Node) -> void:
	if mod == null or not is_instance_valid(mod):
		return
	_deactivate_module(mod)
	var parent: Node = mod.get_parent()
	if parent != null:
		parent.remove_child(mod)
	mod.free()


func _nudge_module_across_player(mod: Node, player: Node, steps: int) -> void:
	## Sweep hazard across the player in X so Area2D.body_entered always fires.
	if mod == null or player == null or not (mod is Node2D):
		return
	var node: Node2D = mod as Node2D
	var px: float = float(player.global_position.x)
	var base_y: float = node.global_position.y
	node.global_position = Vector2(px + 80.0, base_y)
	if mod.has_method("activate"):
		mod.call("activate")
	for i: int in range(maxi(steps, 1)):
		await physics_frame
		var t: float = float(i + 1) / float(maxi(steps, 1))
		node.global_position = Vector2(lerpf(px + 80.0, px - 80.0, t), base_y)


func _read_hitbox(player: Node) -> Dictionary:
	var cs: CollisionShape2D = player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		return {}
	var rect: RectangleShape2D = cs.shape as RectangleShape2D
	if rect == null:
		return {}
	return {"size": rect.size, "position": cs.position}


func _hitbox_matches(hb: Dictionary, size: Vector2, position: Vector2) -> bool:
	if hb.is_empty():
		return false
	var got_size: Vector2 = hb.get("size") as Vector2
	var got_pos: Vector2 = hb.get("position") as Vector2
	return got_size.is_equal_approx(size) and got_pos.is_equal_approx(position)


func _player_hitbox_aabb(player: Node) -> Rect2:
	var cs: CollisionShape2D = player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return _collision_shape_aabb(cs)


func _module_hit_aabb(mod: Node) -> Rect2:
	if mod == null:
		return Rect2()
	var cs: CollisionShape2D = mod.get_node_or_null("HitArea/CollisionShape2D") as CollisionShape2D
	return _collision_shape_aabb(cs)


func _collision_shape_aabb(cs: CollisionShape2D) -> Rect2:
	if cs == null:
		return Rect2()
	var rect: RectangleShape2D = cs.shape as RectangleShape2D
	if rect == null:
		return Rect2()
	var half: Vector2 = rect.size * 0.5
	var center: Vector2 = cs.global_position
	return Rect2(center - half, rect.size)


func _wait_until_dead_or_game_over(gsm: Node, player: Node, max_frames: int) -> bool:
	for _i: int in range(max_frames):
		await physics_frame
		if gsm != null and int(gsm.get("current_state")) == STATE_GAME_OVER:
			return true
		if player != null and player.has_method("is_alive") and not bool(player.call("is_alive")):
			return true
	return false


func _find_game_scene() -> Node:
	var container: Node = root.get_node_or_null("Main/GameSceneContainer")
	if container == null:
		for child: Node in root.get_children():
			var nested: Node = child.get_node_or_null("GameSceneContainer")
			if nested != null:
				container = nested
				break
	if container == null or container.get_child_count() == 0:
		return null
	return container.get_child(0)


func _find_player(game_scene: Node) -> Node:
	if game_scene == null:
		return null
	var player_root: Node = game_scene.get_node_or_null("PlayerRoot")
	if player_root == null or player_root.get_child_count() == 0:
		return null
	return player_root.get_child(0)


func _find_movement(player: Node) -> Node:
	if player == null:
		return null
	return player.get_node_or_null("PlayerMovement")


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await physics_frame


func _wait_until_grounded(player: Node, max_frames: int) -> bool:
	for _i: int in range(max_frames):
		await physics_frame
		if player == null:
			return false
		if player is CharacterBody2D and (player as CharacterBody2D).is_on_floor():
			return true
		if player.has_method("get_state"):
			var st: int = int(player.call("get_state"))
			if st == 0 or st == 1 or st == 4:
				return true
	return false


func _wait_until_standing(player: Node, max_frames: int) -> bool:
	for _i: int in range(max_frames):
		await physics_frame
		if player == null:
			return false
		var on_floor: bool = (
			player is CharacterBody2D and (player as CharacterBody2D).is_on_floor()
		)
		var st: int = -1
		if player.has_method("get_state"):
			st = int(player.call("get_state"))
		if st == STATE_SLIDING:
			continue
		if on_floor or st == 0 or st == 1:
			return true
	return false
