extends SceneTree

## Headless M4.1 smoke: touch latency — early tap/slide commit + no double emit.
## MUST run under dedicated smoke userdata (see scripts/ci/smoke_env.sh):
##   source scripts/ci/smoke_env.sh && ri_smoke_env_setup
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m4_1_touch_latency_smoke.gd
##
## Autoload singletons are resolved by node path (not global identifiers) so this
## script compiles when launched with -s.

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const Boot := preload("res://scripts/ci/smoke_boot_helpers.gd")
const RouterScript := preload("res://scripts/input/TouchGestureRouter.gd")

const WARMUP_FRAMES: int = 90
const POST_START_FRAMES: int = 90
const POST_KILL_FRAMES: int = 5
const POST_RESTART_FRAMES: int = 60
const GESTURE_SETTLE_FRAMES: int = 8
## Early tap dwell is 0.048s; at fixed 60fps ≈ 3 process frames — wait extra.
const EARLY_TAP_WAIT_FRAMES: int = 6
const STATE_PLAYING: int = 2
const STATE_GAME_OVER: int = 4
const SAVE_PATH := "user://save_data.json"
const LABEL := "M4.1 touch latency smoke"
const VIEWPORT_SIZE := Vector2(720.0, 1280.0)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Guard.require_isolated(self, LABEL):
		return

	_clear_isolated_save_file()

	# =========================================================================
	# Part A — router early-commit / no double-emit
	# =========================================================================
	var router: Node = RouterScript.new()
	router.name = "SmokeTouchLatencyRouter"
	root.add_child(router)
	await process_frame

	if not _router_has_contract(router):
		push_error("%s: TouchGestureRouter missing contract methods." % LABEL)
		quit(1)
		return

	var jump_count: Array = [0]
	var slide_count: Array = [0]
	router.jump_requested.connect(func() -> void: jump_count[0] = int(jump_count[0]) + 1)
	router.slide_requested.connect(func() -> void: slide_count[0] = int(slide_count[0]) + 1)

	router.call("set_enabled", true)
	router.call("reset")
	_reset_counts(jump_count, slide_count)

	var live_vp: Vector2 = _router_live_viewport(router)
	var live_swipe: float = float(router.call("get_swipe_threshold_px", live_vp))
	var live_slop: float = float(router.call("get_tap_slop_px", live_vp))
	print(
		"%s: live vp=%s swipe=%0.1f slop=%0.1f"
		% [LABEL, live_vp, live_swipe, live_slop]
	)

	# --- T1: rapid tap (press+release within slop) → exactly one jump ---
	var origin := Vector2(100, 200)
	router.call("begin_touch", 0, origin)
	router.call("update_touch", 0, origin + Vector2(2, 3))
	var t1: String = str(router.call("end_touch", 0, origin + Vector2(2, 3)))
	if t1 != "jump" or int(jump_count[0]) != 1 or int(slide_count[0]) != 0:
		push_error(
			"%s: T1 rapid tap expected jump/1/0 got result=%s jumps=%d slides=%d"
			% [LABEL, t1, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	print("%s: T1 PASS (rapid tap → jump×1)" % LABEL)

	# --- T2: early dwell tap → one jump before release ---
	_reset_counts(jump_count, slide_count)
	var dwell_origin := Vector2(110, 210)
	router.call("begin_touch", 0, dwell_origin)
	await _wait_process_frames(EARLY_TAP_WAIT_FRAMES)
	if int(jump_count[0]) != 1 or int(slide_count[0]) != 0:
		push_error(
			"%s: T2 early dwell expected jump×1 before release got jumps=%d slides=%d"
			% [LABEL, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	var t2: String = str(router.call("end_touch", 0, dwell_origin + Vector2(1, 1)))
	if t2 != "jump" or int(jump_count[0]) != 1:
		push_error(
			"%s: T2 release after early commit expected jump once got result=%s jumps=%d"
			% [LABEL, t2, int(jump_count[0])]
		)
		quit(1)
		return
	print("%s: T2 PASS (early dwell → jump×1, no double on release)" % LABEL)

	# --- T3: swipe down past threshold → slide mid-drag, zero jumps ---
	_reset_counts(jump_count, slide_count)
	var down_start := Vector2(120, 100)
	var down_mid := Vector2(120, 100 + live_swipe + 8.0)
	router.call("begin_touch", 0, down_start)
	router.call("update_touch", 0, down_mid)
	if int(slide_count[0]) != 1 or int(jump_count[0]) != 0:
		push_error(
			"%s: T3 mid-drag early slide expected slides=1 jumps=0 got jumps=%d slides=%d"
			% [LABEL, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	var t3: String = str(router.call("end_touch", 0, down_mid))
	if t3 != "slide" or int(slide_count[0]) != 1 or int(jump_count[0]) != 0:
		push_error(
			"%s: T3 swipe-down expected slide/0/1 got result=%s jumps=%d slides=%d"
			% [LABEL, t3, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	print("%s: T3 PASS (early slide mid-drag, no jump, no double)" % LABEL)

	# --- T4: past slop, short of swipe threshold → none or slide, never jump ---
	_reset_counts(jump_count, slide_count)
	var mid_dy: float = (live_slop + live_swipe) * 0.5
	if mid_dy <= live_slop:
		mid_dy = live_slop + 1.0
	if mid_dy >= live_swipe:
		mid_dy = maxf(live_slop + 1.0, live_swipe - 1.0)
	var mid_start := Vector2(160, 320)
	var mid_end := Vector2(160, 320 + mid_dy)
	router.call("begin_touch", 0, mid_start)
	## Move promptly past slop so early tap cannot commit.
	router.call("update_touch", 0, mid_end)
	await _wait_process_frames(EARLY_TAP_WAIT_FRAMES)
	var t4: String = str(router.call("end_touch", 0, mid_end))
	if t4 == "jump" or int(jump_count[0]) != 0:
		push_error(
			"%s: T4 mid-zone must never jump got result=%s jumps=%d slides=%d"
			% [LABEL, t4, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	if t4 != "none" and t4 != "slide":
		push_error("%s: T4 expected none|slide got %s" % [LABEL, t4])
		quit(1)
		return
	print("%s: T4 PASS (mid-zone → %s, never jump)" % [LABEL, t4])

	# --- T5: swipe up → none ---
	_reset_counts(jump_count, slide_count)
	var up_start := Vector2(90, 500)
	var up_end := Vector2(90, 500 - live_swipe - 8.0)
	router.call("begin_touch", 0, up_start)
	router.call("update_touch", 0, up_end)
	var t5: String = str(router.call("end_touch", 0, up_end))
	if t5 != "none" or int(jump_count[0]) != 0 or int(slide_count[0]) != 0:
		push_error(
			"%s: T5 upward expected none got result=%s jumps=%d slides=%d"
			% [LABEL, t5, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	print("%s: T5 PASS (swipe up → none)" % LABEL)

	# --- T6: horizontal → none ---
	_reset_counts(jump_count, slide_count)
	var h_start := Vector2(80, 400)
	var h_end := Vector2(80 + maxf(live_swipe, live_slop) + 40.0, 400 + 10.0)
	router.call("begin_touch", 0, h_start)
	router.call("update_touch", 0, h_end)
	var t6: String = str(router.call("end_touch", 0, h_end))
	if t6 != "none" or int(jump_count[0]) != 0 or int(slide_count[0]) != 0:
		push_error(
			"%s: T6 horizontal expected none got result=%s jumps=%d slides=%d"
			% [LABEL, t6, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	print("%s: T6 PASS (horizontal → none)" % LABEL)

	# --- T7: canceled touch → no action ---
	_reset_counts(jump_count, slide_count)
	router.call("begin_touch", 0, Vector2(50, 50))
	await _wait_process_frames(2)
	router.call("cancel_touch", 0)
	await _wait_process_frames(EARLY_TAP_WAIT_FRAMES)
	var t7: String = str(router.call("end_touch", 0, Vector2(50, 50)))
	if t7 != "none" or int(jump_count[0]) != 0 or int(slide_count[0]) != 0:
		push_error(
			"%s: T7 cancel expected none/0/0 got result=%s jumps=%d slides=%d"
			% [LABEL, t7, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	print("%s: T7 PASS (cancel → no action)" % LABEL)

	# --- T8: reset clears stale early-tap (no jump after reset) ---
	_reset_counts(jump_count, slide_count)
	router.call("begin_touch", 0, Vector2(60, 60))
	await _wait_process_frames(2)
	router.call("reset")
	await _wait_process_frames(EARLY_TAP_WAIT_FRAMES)
	var t8: String = str(router.call("end_touch", 0, Vector2(60, 60)))
	if t8 != "none" or int(jump_count[0]) != 0:
		push_error(
			"%s: T8 reset expected none/0 got result=%s jumps=%d"
			% [LABEL, t8, int(jump_count[0])]
		)
		quit(1)
		return
	print("%s: T8 PASS (reset clears early-tap / gesture)" % LABEL)

	# --- T9: no double emission — early slide then release same gesture ---
	_reset_counts(jump_count, slide_count)
	var d0 := Vector2(200, 80)
	var d1 := Vector2(200, 80 + live_swipe + 20.0)
	router.call("begin_touch", 0, d0)
	router.call("update_touch", 0, d1)
	router.call("update_touch", 0, d1 + Vector2(0, 10))
	var t9: String = str(router.call("end_touch", 0, d1 + Vector2(0, 10)))
	if t9 != "slide" or int(slide_count[0]) != 1 or int(jump_count[0]) != 0:
		push_error(
			"%s: T9 double-emit guard failed result=%s jumps=%d slides=%d"
			% [LABEL, t9, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	print("%s: T9 PASS (single slide emit for committed gesture)" % LABEL)

	# --- T10: secondary finger never emits; primary still one jump ---
	_reset_counts(jump_count, slide_count)
	router.call("begin_touch", 0, Vector2(200, 200))
	router.call("begin_touch", 1, Vector2(300, 200))
	router.call("update_touch", 1, Vector2(302, 202))
	var t10_sec: String = str(router.call("end_touch", 1, Vector2(302, 202)))
	var t10_pri: String = str(router.call("end_touch", 0, Vector2(202, 202)))
	if t10_sec != "none" or t10_pri != "jump" or int(jump_count[0]) != 1:
		push_error(
			"%s: T10 multi-touch expected none+jump×1 got sec=%s pri=%s jumps=%d"
			% [LABEL, t10_sec, t10_pri, int(jump_count[0])]
		)
		quit(1)
		return
	print("%s: T10 PASS (multi-touch no duplicate)" % LABEL)

	router.queue_free()
	await process_frame

	# =========================================================================
	# Part B — live gates: GAME_OVER / restart / immediate jump path
	# =========================================================================
	var err: Error = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("%s: failed to load Main.tscn (%s)" % [LABEL, error_string(err)])
		quit(1)
		return

	await _wait_physics_frames(WARMUP_FRAMES)

	var gsm: Node = _game_state()
	var event_bus: Node = _event_bus()
	var main: Node = Boot.find_main(root)
	if gsm == null or event_bus == null or main == null:
		push_error("%s: Main/GSM/EventBus missing after warmup." % LABEL)
		quit(1)
		return

	if not Boot.ensure_playing_from_title(root, LABEL):
		quit(1)
		return
	await _wait_physics_frames(POST_START_FRAMES)
	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error(
			"%s: L0 expected PLAYING after start_game, got %d."
			% [LABEL, int(gsm.get("current_state"))]
		)
		quit(1)
		return

	var game_scene: Node = _find_game_scene(main)
	var player: Node = _find_player(game_scene)
	var movement: Node = _find_movement(player)
	var live_router: Object = _find_touch_router(player)
	if player == null or movement == null or live_router == null:
		push_error("%s: Player/movement/router missing while PLAYING." % LABEL)
		quit(1)
		return

	var live_jumps: Array = [0]
	var live_slides: Array = [0]
	event_bus.player_jumped.connect(func() -> void: live_jumps[0] = int(live_jumps[0]) + 1)
	event_bus.player_slid.connect(func() -> void: live_slides[0] = int(live_slides[0]) + 1)

	var router_jumps: Array = [0]
	var router_slides: Array = [0]
	live_router.jump_requested.connect(
		func() -> void: router_jumps[0] = int(router_jumps[0]) + 1
	)
	live_router.slide_requested.connect(
		func() -> void: router_slides[0] = int(router_slides[0]) + 1
	)

	# --- L1: rapid live tap → ≤1 player_jumped (immediate apply path) ---
	_reset_counts(live_jumps, live_slides)
	_reset_counts(router_jumps, router_slides)
	live_router.call("begin_touch", 0, Vector2(200, 250))
	live_router.call("update_touch", 0, Vector2(201, 251))
	var l1: String = str(live_router.call("end_touch", 0, Vector2(201, 251)))
	await _wait_physics_frames(GESTURE_SETTLE_FRAMES)
	if l1 != "jump" or int(router_jumps[0]) != 1:
		push_error(
			"%s: L1 live tap expected jump×1 got result=%s router_jumps=%d"
			% [LABEL, l1, int(router_jumps[0])]
		)
		quit(1)
		return
	if int(live_jumps[0]) > 1:
		push_error("%s: L1 duplicate player_jumped=%d" % [LABEL, int(live_jumps[0])])
		quit(1)
		return
	print(
		"%s: L1 PASS (live tap → jump request×1 player_jumped=%d)"
		% [LABEL, int(live_jumps[0])]
	)

	# --- L2: GAME_OVER — no jump/slide from router ---
	if not await _wait_until_standing(player, 180):
		push_error("%s: L2 never landed after L1 jump." % LABEL)
		quit(1)
		return
	player.call("kill")
	await _wait_physics_frames(max(POST_KILL_FRAMES, 30))
	if int(gsm.get("current_state")) != STATE_GAME_OVER:
		push_error(
			"%s: L2 expected GAME_OVER, got %d." % [LABEL, int(gsm.get("current_state"))]
		)
		quit(1)
		return

	player = _find_player(game_scene)
	movement = _find_movement(player)
	live_router = _find_touch_router(player)
	if live_router == null or movement == null:
		push_error("%s: L2 router/movement missing after GAME_OVER." % LABEL)
		quit(1)
		return
	var sync_ev := InputEventMouseMotion.new()
	sync_ev.position = Vector2(1, 1)
	if movement.has_method("_unhandled_input"):
		movement.call("_unhandled_input", sync_ev)
	await _wait_physics_frames(2)

	var go_jumps: Array = [0]
	var go_slides: Array = [0]
	live_router.jump_requested.connect(func() -> void: go_jumps[0] = int(go_jumps[0]) + 1)
	live_router.slide_requested.connect(func() -> void: go_slides[0] = int(go_slides[0]) + 1)

	_reset_counts(live_jumps, live_slides)
	live_router.call("begin_touch", 0, Vector2(130, 130))
	await _wait_process_frames(EARLY_TAP_WAIT_FRAMES)
	live_router.call("end_touch", 0, Vector2(131, 131))
	await _wait_physics_frames(GESTURE_SETTLE_FRAMES)
	if int(go_jumps[0]) != 0 or int(go_slides[0]) != 0 or int(live_jumps[0]) != 0:
		push_error(
			"%s: L2 GAME_OVER still emitted rj=%d rs=%d jumps=%d"
			% [LABEL, int(go_jumps[0]), int(go_slides[0]), int(live_jumps[0])]
		)
		quit(1)
		return
	print("%s: L2 PASS (GAME_OVER no jump/slide)" % LABEL)

	# --- L3: restart clears stale gesture (no stale jump) ---
	if not game_scene.has_method("restart_run"):
		push_error("%s: L3 GameScene.restart_run missing." % LABEL)
		quit(1)
		return
	_reset_counts(live_jumps, live_slides)
	live_router.call("begin_touch", 0, Vector2(160, 160))
	game_scene.call("restart_run")
	await _wait_physics_frames(POST_RESTART_FRAMES)
	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error(
			"%s: L3 expected PLAYING after restart, got %d."
			% [LABEL, int(gsm.get("current_state"))]
		)
		quit(1)
		return

	player = _find_player(game_scene)
	movement = _find_movement(player)
	var router_after: Object = _find_touch_router(player)
	if player == null or movement == null or router_after == null:
		push_error("%s: L3 player/router missing after restart." % LABEL)
		quit(1)
		return
	if router_after != live_router:
		live_router = router_after
		_reset_counts(router_jumps, router_slides)
		live_router.jump_requested.connect(
			func() -> void: router_jumps[0] = int(router_jumps[0]) + 1
		)
		live_router.slide_requested.connect(
			func() -> void: router_slides[0] = int(router_slides[0]) + 1
		)
	else:
		live_router = router_after

	_reset_counts(live_jumps, live_slides)
	_reset_counts(router_jumps, router_slides)
	var stale: String = str(live_router.call("end_touch", 0, Vector2(160, 160)))
	await _wait_physics_frames(GESTURE_SETTLE_FRAMES)
	if stale != "none" or int(router_jumps[0]) != 0 or int(live_jumps[0]) != 0:
		push_error(
			"%s: L3 stale end after restart expected none got %s rj=%d jumps=%d"
			% [LABEL, stale, int(router_jumps[0]), int(live_jumps[0])]
		)
		quit(1)
		return

	_reset_counts(live_jumps, live_slides)
	_reset_counts(router_jumps, router_slides)
	live_router.call("begin_touch", 0, Vector2(170, 170))
	var l3: String = str(live_router.call("end_touch", 0, Vector2(171, 171)))
	await _wait_physics_frames(GESTURE_SETTLE_FRAMES)
	if l3 != "jump" or int(router_jumps[0]) != 1:
		push_error(
			"%s: L3 fresh tap after restart expected jump×1 got result=%s rj=%d"
			% [LABEL, l3, int(router_jumps[0])]
		)
		quit(1)
		return
	print("%s: L3 PASS (restart clears gesture; fresh tap OK)" % LABEL)

	# --- L4: keyboard/request_jump still works ---
	if not await _wait_until_standing(player, 180):
		push_error("%s: L4 never standing before request_jump." % LABEL)
		quit(1)
		return
	_reset_counts(live_jumps, live_slides)
	if not movement.has_method("request_jump"):
		push_error("%s: L4 request_jump missing." % LABEL)
		quit(1)
		return
	movement.call("request_jump")
	await _wait_physics_frames(GESTURE_SETTLE_FRAMES)
	if int(live_jumps[0]) < 1:
		push_error("%s: L4 request_jump produced no player_jumped." % LABEL)
		quit(1)
		return
	print("%s: L4 PASS (keyboard/request_jump → player_jumped=%d)" % [LABEL, int(live_jumps[0])])

	print("M4.1 touch latency smoke PASS")
	quit(0)


func _reset_counts(a: Array, b: Array) -> void:
	a[0] = 0
	b[0] = 0


func _router_live_viewport(router: Node) -> Vector2:
	if router != null:
		var viewport: Viewport = router.get_viewport()
		if viewport != null:
			var size: Vector2 = viewport.get_visible_rect().size
			if size.x > 0.0 and size.y > 0.0:
				return size
	return VIEWPORT_SIZE


func _router_has_contract(node: Object) -> bool:
	if node == null:
		return false
	for method_name: String in [
		"begin_touch",
		"update_touch",
		"end_touch",
		"cancel_touch",
		"set_enabled",
		"reset",
		"get_swipe_threshold_px",
		"get_tap_slop_px",
	]:
		if not node.has_method(method_name):
			return false
	return true


func _find_touch_router(player: Node) -> Object:
	if player == null:
		return null
	var movement: Node = _find_movement(player)
	var candidates: Array = []
	if movement != null:
		candidates.append(movement)
		for child: Node in movement.get_children():
			candidates.append(child)
		for prop_name: String in ["_touch_router", "touch_router"]:
			var prop: Variant = movement.get(prop_name)
			if prop != null and prop is Object:
				candidates.append(prop)
	candidates.append(player)
	for child: Node in player.get_children():
		candidates.append(child)
		if child.name == "PlayerMovement":
			for grand: Node in child.get_children():
				candidates.append(grand)
	for cand: Variant in candidates:
		if cand is Object and _router_has_contract(cand as Object):
			var obj: Object = cand as Object
			if obj.has_signal("jump_requested"):
				return obj
	for cand: Variant in candidates:
		if cand is Object and _router_has_contract(cand as Object):
			return cand as Object
	return null


func _clear_isolated_save_file() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _game_state() -> Node:
	return root.get_node_or_null("GameStateManager")


func _event_bus() -> Node:
	return root.get_node_or_null("EventBus")


func _find_game_scene(main: Node) -> Node:
	var container: Node = null
	if main != null:
		container = main.get_node_or_null("GameSceneContainer")
	if container == null:
		container = root.get_node_or_null("Main/GameSceneContainer")
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


func _wait_physics_frames(count: int) -> void:
	for _i: int in range(count):
		await physics_frame


func _wait_process_frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame


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
		if st == 4:
			continue
		if on_floor or st == 0 or st == 1:
			return true
	return false
