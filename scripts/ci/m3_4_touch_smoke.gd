extends SceneTree

## Headless M3.4 smoke: TouchGestureRouter classification + live PLAY gates.
## MUST run under dedicated smoke userdata (see scripts/ci/smoke_env.sh):
##   source scripts/ci/smoke_env.sh && ri_smoke_env_setup
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m3_4_touch_smoke.gd
##
## Autoload singletons are resolved by node path (not global identifiers) so this
## script compiles when launched with -s.
##
## Contract APIs (MA-005 / M3.4):
##   TouchGestureRouter: begin_touch/update_touch/end_touch → jump|slide|none
##   set_enabled, reset, get_swipe_threshold_px, get_tap_slop_px, handle_input_event
##   Signals: jump_requested, slide_requested
##   Live: Main.start_game, GameScene.restart_run, PlayerMovement.request_jump
##   Slide is real — may assert EventBus.player_slid / PlayerState.SLIDING

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const Boot := preload("res://scripts/ci/smoke_boot_helpers.gd")
const RouterScript := preload("res://scripts/input/TouchGestureRouter.gd")

const WARMUP_FRAMES: int = 90
const POST_START_FRAMES: int = 90
const POST_KILL_FRAMES: int = 5
const POST_RESTART_FRAMES: int = 60
const GESTURE_SETTLE_FRAMES: int = 8
const STATE_MAIN_MENU: int = 1
const STATE_PLAYING: int = 2
const STATE_GAME_OVER: int = 4
const SAVE_PATH := "user://save_data.json"
const LABEL := "M3.4 touch smoke"
## Deterministic viewport for threshold math (matches router DEFAULT when detached).
const VIEWPORT_SIZE := Vector2(720.0, 1280.0)
const SWIPE_RATIO := 0.06
const SWIPE_FALLBACK := 48.0
const TAP_SLOP_RATIO := 0.025
const TAP_SLOP_FALLBACK := 24.0
const THRESHOLD_EPS := 1.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Guard.require_isolated(self, LABEL):
		return

	_clear_isolated_save_file()

	# =========================================================================
	# Part A — pure router API (unit-like)
	# =========================================================================
	var router: Node = RouterScript.new()
	router.name = "SmokeTouchGestureRouter"
	root.add_child(router)
	await physics_frame

	if not _router_has_contract(router):
		push_error("%s: TouchGestureRouter missing contract methods." % LABEL)
		quit(1)
		return

	var jump_count: Array = [0]
	var slide_count: Array = [0]
	router.jump_requested.connect(func() -> void: jump_count[0] = int(jump_count[0]) + 1)
	router.slide_requested.connect(func() -> void: slide_count[0] = int(slide_count[0]) + 1)

	# --- Threshold helpers ---
	var swipe_thr: float = float(router.call("get_swipe_threshold_px", VIEWPORT_SIZE))
	var tap_slop: float = float(router.call("get_tap_slop_px", VIEWPORT_SIZE))
	var expected_swipe: float = maxf(SWIPE_FALLBACK, VIEWPORT_SIZE.y * SWIPE_RATIO)
	var expected_slop: float = maxf(TAP_SLOP_FALLBACK, VIEWPORT_SIZE.y * TAP_SLOP_RATIO)
	if absf(swipe_thr - expected_swipe) > THRESHOLD_EPS:
		push_error(
			"%s: thr swipe=%0.2f expected ~%0.2f (max(%.0f, h*%0.3f))."
			% [LABEL, swipe_thr, expected_swipe, SWIPE_FALLBACK, SWIPE_RATIO]
		)
		quit(1)
		return
	if absf(tap_slop - expected_slop) > THRESHOLD_EPS:
		push_error(
			"%s: thr tap_slop=%0.2f expected ~%0.2f."
			% [LABEL, tap_slop, expected_slop]
		)
		quit(1)
		return
	print(
		"%s: thr PASS (swipe=%0.1f slop=%0.1f vp=%s)"
		% [LABEL, swipe_thr, tap_slop, VIEWPORT_SIZE]
	)

	router.call("set_enabled", true)
	router.call("reset")
	_reset_counts(jump_count, slide_count)

	# Classification uses the router's live viewport — drive deltas from that threshold.
	var live_vp: Vector2 = _router_live_viewport(router)
	var live_swipe: float = float(router.call("get_swipe_threshold_px", live_vp))
	var live_slop: float = float(router.call("get_tap_slop_px", live_vp))
	print(
		"%s: live vp=%s swipe=%0.1f slop=%0.1f (for gesture deltas)"
		% [LABEL, live_vp, live_swipe, live_slop]
	)

	# --- Case R1: valid tap → jump (exactly one signal) ---
	var origin := Vector2(100, 200)
	router.call("begin_touch", 0, origin)
	router.call("update_touch", 0, origin + Vector2(2, 3))
	var r1: String = str(router.call("end_touch", 0, origin + Vector2(2, 3)))
	if r1 != "jump" or int(jump_count[0]) != 1 or int(slide_count[0]) != 0:
		push_error(
			"%s: R1 tap expected jump/1/0 got result=%s jumps=%d slides=%d"
			% [LABEL, r1, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	print("%s: R1 PASS (tap → jump×1)" % LABEL)

	# --- Case R2: swipe down → slide, never jump ---
	_reset_counts(jump_count, slide_count)
	var down_start := Vector2(120, 100)
	var down_end := Vector2(120, 100 + live_swipe + 8.0)
	router.call("begin_touch", 0, down_start)
	router.call("update_touch", 0, down_end)
	var r2: String = str(router.call("end_touch", 0, down_end))
	if r2 != "slide" or int(slide_count[0]) != 1 or int(jump_count[0]) != 0:
		push_error(
			"%s: R2 swipe-down expected slide/0/1 got result=%s jumps=%d slides=%d (live_swipe=%0.1f)"
			% [LABEL, r2, int(jump_count[0]), int(slide_count[0]), live_swipe]
		)
		quit(1)
		return
	print("%s: R2 PASS (swipe down → slide, not jump)" % LABEL)

	# --- Case R3: small movement within tap slop → jump ---
	_reset_counts(jump_count, slide_count)
	var sub_start := Vector2(150, 300)
	var sub_end := Vector2(150, 300 + maxf(1.0, live_slop * 0.5))
	router.call("begin_touch", 0, sub_start)
	router.call("update_touch", 0, sub_end)
	var r3: String = str(router.call("end_touch", 0, sub_end))
	if r3 != "jump" or int(jump_count[0]) != 1 or int(slide_count[0]) != 0:
		push_error(
			"%s: R3 within-slop expected jump got result=%s jumps=%d slides=%d"
			% [LABEL, r3, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	print("%s: R3 PASS (within tap slop → jump)" % LABEL)

	# --- Case R3b: ambiguous mid-zone (past slop, short of swipe) → none ---
	_reset_counts(jump_count, slide_count)
	var mid_dy: float = (live_slop + live_swipe) * 0.5
	if mid_dy <= live_slop:
		mid_dy = live_slop + 1.0
	if mid_dy >= live_swipe:
		mid_dy = maxf(live_slop + 1.0, live_swipe - 1.0)
	var mid_start := Vector2(160, 320)
	var mid_end := Vector2(160, 320 + mid_dy)
	router.call("begin_touch", 0, mid_start)
	router.call("update_touch", 0, mid_end)
	var r3b: String = str(router.call("end_touch", 0, mid_end))
	if r3b != "none" or int(jump_count[0]) != 0 or int(slide_count[0]) != 0:
		push_error(
			"%s: R3b mid-zone expected none got result=%s jumps=%d slides=%d (mid_dy=%0.1f slop=%0.1f swipe=%0.1f)"
			% [LABEL, r3b, int(jump_count[0]), int(slide_count[0]), mid_dy, live_slop, live_swipe]
		)
		quit(1)
		return
	print("%s: R3b PASS (ambiguous mid-zone → none)" % LABEL)

	# --- Case R4: horizontal-dominant swipe → none ---
	_reset_counts(jump_count, slide_count)
	var h_start := Vector2(80, 400)
	var h_end := Vector2(80 + maxf(live_swipe, live_slop) + 40.0, 400 + 10.0)
	router.call("begin_touch", 0, h_start)
	router.call("update_touch", 0, h_end)
	var r4: String = str(router.call("end_touch", 0, h_end))
	if r4 != "none" or int(jump_count[0]) != 0 or int(slide_count[0]) != 0:
		push_error(
			"%s: R4 horizontal expected none/0/0 got result=%s jumps=%d slides=%d"
			% [LABEL, r4, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	print("%s: R4 PASS (horizontal → none)" % LABEL)

	# --- Case R4b: long upward swipe → none (must not jump) ---
	_reset_counts(jump_count, slide_count)
	var up_start := Vector2(90, 500)
	var up_end := Vector2(90, 500 - live_swipe - 8.0)
	router.call("begin_touch", 0, up_start)
	router.call("update_touch", 0, up_end)
	var r4b: String = str(router.call("end_touch", 0, up_end))
	if r4b != "none" or int(jump_count[0]) != 0 or int(slide_count[0]) != 0:
		push_error(
			"%s: R4b upward swipe expected none got result=%s jumps=%d slides=%d"
			% [LABEL, r4b, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	print("%s: R4b PASS (upward swipe → none)" % LABEL)

	# --- Case R5: multi-touch — secondary finger must not duplicate actions ---
	_reset_counts(jump_count, slide_count)
	router.call("begin_touch", 0, Vector2(200, 200))
	router.call("begin_touch", 1, Vector2(300, 200))
	router.call("update_touch", 1, Vector2(302, 202))
	var r5_sec: String = str(router.call("end_touch", 1, Vector2(302, 202)))
	var r5_pri: String = str(router.call("end_touch", 0, Vector2(202, 202)))
	if r5_sec != "none":
		push_error("%s: R5 secondary end expected none got %s" % [LABEL, r5_sec])
		quit(1)
		return
	if r5_pri != "jump" or int(jump_count[0]) != 1 or int(slide_count[0]) != 0:
		push_error(
			"%s: R5 primary expected single jump got result=%s jumps=%d slides=%d"
			% [LABEL, r5_pri, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	print("%s: R5 PASS (multi-touch no duplicate)" % LABEL)

	# --- Case R6: set_enabled(false) → no signal emission ---
	_reset_counts(jump_count, slide_count)
	router.call("set_enabled", false)
	router.call("begin_touch", 0, Vector2(50, 50))
	router.call("end_touch", 0, Vector2(51, 51))
	if int(jump_count[0]) != 0 or int(slide_count[0]) != 0:
		push_error(
			"%s: R6 disabled still emitted jumps=%d slides=%d"
			% [LABEL, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	print("%s: R6 PASS (set_enabled false → no emit)" % LABEL)

	# --- Case R7: reset clears in-flight gesture (no action on stale end) ---
	router.call("set_enabled", true)
	_reset_counts(jump_count, slide_count)
	router.call("begin_touch", 0, Vector2(60, 60))
	router.call("reset")
	var r7: String = str(router.call("end_touch", 0, Vector2(60, 60)))
	if r7 != "none" or int(jump_count[0]) != 0:
		push_error(
			"%s: R7 reset expected none/0 got result=%s jumps=%d"
			% [LABEL, r7, int(jump_count[0])]
		)
		quit(1)
		return
	print("%s: R7 PASS (reset clears gesture state)" % LABEL)

	# --- Case R8: mouse+touch double suppressed (headless-testable via handle_input_event) ---
	if not router.has_method("handle_input_event"):
		push_error("%s: R8 handle_input_event missing." % LABEL)
		quit(1)
		return
	router.call("set_enabled", true)
	router.call("reset")
	_reset_counts(jump_count, slide_count)
	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 0
	touch_press.pressed = true
	touch_press.position = Vector2(400, 400)
	router.call("handle_input_event", touch_press)
	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.pressed = true
	mouse_press.position = Vector2(400, 400)
	router.call("handle_input_event", mouse_press)
	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 0
	touch_release.pressed = false
	touch_release.position = Vector2(401, 401)
	router.call("handle_input_event", touch_release)
	var mouse_release := InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.pressed = false
	mouse_release.position = Vector2(401, 401)
	router.call("handle_input_event", mouse_release)
	if int(jump_count[0]) != 1 or int(slide_count[0]) != 0:
		push_error(
			"%s: R8 mouse+touch expected exactly 1 jump got jumps=%d slides=%d"
			% [LABEL, int(jump_count[0]), int(slide_count[0])]
		)
		quit(1)
		return
	print("%s: R8 PASS (mouse+touch → single jump)" % LABEL)

	router.queue_free()
	await physics_frame

	# =========================================================================
	# Part B — live Main title → PLAY gates
	# =========================================================================
	var err: Error = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("%s: failed to load Main.tscn (%s)" % [LABEL, error_string(err)])
		quit(1)
		return

	await _wait_frames(WARMUP_FRAMES)

	var gsm: Node = _game_state()
	var event_bus: Node = _event_bus()
	var main: Node = Boot.find_main(root)
	if gsm == null or event_bus == null or main == null:
		push_error("%s: Main/GSM/EventBus missing after warmup." % LABEL)
		quit(1)
		return

	if int(gsm.get("current_state")) != STATE_MAIN_MENU:
		push_error(
			"%s: L0 expected MAIN_MENU, got %d." % [LABEL, int(gsm.get("current_state"))]
		)
		quit(1)
		return

	var game_scene: Node = _find_game_scene(main)
	if game_scene == null:
		push_error("%s: GameScene not found." % LABEL)
		quit(1)
		return

	var live_jumps: Array = [0]
	var live_slides: Array = [0]
	event_bus.player_jumped.connect(func() -> void: live_jumps[0] = int(live_jumps[0]) + 1)
	event_bus.player_slid.connect(func() -> void: live_slides[0] = int(live_slides[0]) + 1)

	# --- Case L1: MAIN_MENU — router disabled / no player jump from gestures ---
	_reset_counts(live_jumps, live_slides)
	var menu_player: Node = _find_player(game_scene)
	var menu_router: Object = _find_touch_router(menu_player)
	if menu_router != null and menu_router.has_method("set_enabled"):
		# Drive whatever router exists; even if mis-enabled, player must not jump off title.
		menu_router.call("set_enabled", false)
		menu_router.call("begin_touch", 0, Vector2(100, 100))
		menu_router.call("end_touch", 0, Vector2(101, 101))
	# Also synthesize screen tap through Input (old or new path).
	_inject_screen_tap(Vector2(110, 110))
	await _wait_frames(GESTURE_SETTLE_FRAMES)
	if int(gsm.get("current_state")) != STATE_MAIN_MENU:
		push_error("%s: L1 gesture left MAIN_MENU." % LABEL)
		quit(1)
		return
	if int(live_jumps[0]) != 0 or int(live_slides[0]) != 0:
		push_error(
			"%s: L1 MAIN_MENU gesture caused jumps=%d slides=%d"
			% [LABEL, int(live_jumps[0]), int(live_slides[0])]
		)
		quit(1)
		return
	print("%s: L1 PASS (MAIN_MENU no jump/slide)" % LABEL)

	# --- Case L2: PLAY press does not jump (title→start, no spurious jump) ---
	_reset_counts(live_jumps, live_slides)
	if not Boot.ensure_playing_from_title(root, LABEL):
		quit(1)
		return
	await _wait_frames(POST_START_FRAMES)
	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error(
			"%s: L2 expected PLAYING after start_game, got %d."
			% [LABEL, int(gsm.get("current_state"))]
		)
		quit(1)
		return
	if int(live_jumps[0]) != 0:
		push_error(
			"%s: L2 PLAY/start_game caused spurious jumps=%d" % [LABEL, int(live_jumps[0])]
		)
		quit(1)
		return
	print("%s: L2 PASS (start_game no spurious jump)" % LABEL)

	var player: Node = _find_player(game_scene)
	var movement: Node = _find_movement(player)
	if player == null or movement == null:
		push_error("%s: Player/PlayerMovement missing while PLAYING." % LABEL)
		quit(1)
		return

	var live_router: Object = _find_touch_router(player)
	if live_router == null:
		push_error(
			"%s: live TouchGestureRouter not found on Player/PlayerMovement (Agent A wire-up)."
			% LABEL
		)
		quit(1)
		return

	# Ensure router is enabled for PLAYING (PlayerMovement should have done this).
	if live_router.has_method("set_enabled"):
		live_router.call("set_enabled", true)

	var router_jumps: Array = [0]
	var router_slides: Array = [0]
	if live_router.has_signal("jump_requested"):
		live_router.jump_requested.connect(
			func() -> void: router_jumps[0] = int(router_jumps[0]) + 1
		)
	if live_router.has_signal("slide_requested"):
		live_router.slide_requested.connect(
			func() -> void: router_slides[0] = int(router_slides[0]) + 1
		)

	# --- Case L3: valid tap → exactly one jump request (live) ---
	_reset_counts(live_jumps, live_slides)
	_reset_counts(router_jumps, router_slides)
	var play_vp: Vector2 = _router_live_viewport(live_router as Node)
	var play_swipe: float = float(live_router.call("get_swipe_threshold_px", play_vp))
	live_router.call("begin_touch", 0, Vector2(200, 250))
	live_router.call("update_touch", 0, Vector2(201, 251))
	var l3: String = str(live_router.call("end_touch", 0, Vector2(201, 251)))
	await _wait_frames(GESTURE_SETTLE_FRAMES)
	if l3 != "jump" or int(router_jumps[0]) != 1:
		push_error(
			"%s: L3 live tap expected jump×1 got result=%s router_jumps=%d"
			% [LABEL, l3, int(router_jumps[0])]
		)
		quit(1)
		return
	# Player may or may not leave ground yet (coyote/floor); require jump request path fired.
	if int(live_jumps[0]) > 1:
		push_error("%s: L3 duplicate player_jumped=%d" % [LABEL, int(live_jumps[0])])
		quit(1)
		return
	print(
		"%s: L3 PASS (live tap → jump request×1 player_jumped=%d)"
		% [LABEL, int(live_jumps[0])]
	)

	# --- Case L4: swipe down → slide, not jump (live; slide is real) ---
	# Slide requires on-floor — wait out the L3 jump before swiping.
	if not await _wait_until_grounded(player, 180):
		push_error("%s: L4 player never grounded after tap jump." % LABEL)
		quit(1)
		return
	_reset_counts(live_jumps, live_slides)
	_reset_counts(router_jumps, router_slides)
	var s0 := Vector2(220, 180)
	var s1 := Vector2(220, 180 + play_swipe + 12.0)
	live_router.call("begin_touch", 0, s0)
	live_router.call("update_touch", 0, s1)
	var l4: String = str(live_router.call("end_touch", 0, s1))
	await _wait_frames(GESTURE_SETTLE_FRAMES)
	if l4 != "slide" or int(router_slides[0]) != 1 or int(router_jumps[0]) != 0:
		push_error(
			"%s: L4 live swipe expected slide not jump got result=%s rj=%d rs=%d"
			% [LABEL, l4, int(router_jumps[0]), int(router_slides[0])]
		)
		quit(1)
		return
	var slid_ok: bool = int(live_slides[0]) >= 1
	var sliding_state: bool = false
	if player.has_method("get_state"):
		var st: Variant = player.call("get_state")
		# PlayerState.State: IDLE=0 RUNNING=1 JUMPING=2 FALLING=3 SLIDING=4
		sliding_state = str(st).contains("SLIDING") or int(st) == 4
	if not slid_ok and not sliding_state:
		var state_dbg: String = "?"
		if player.has_method("get_state"):
			state_dbg = str(player.call("get_state"))
		push_error(
			"%s: L4 slide intent OK but no player_slid/SLIDING (slides=%d state=%s)"
			% [LABEL, int(live_slides[0]), state_dbg]
		)
		quit(1)
		return
	if int(live_jumps[0]) != 0:
		push_error("%s: L4 swipe-down also jumped (player_jumped=%d)" % [LABEL, int(live_jumps[0])])
		quit(1)
		return
	print(
		"%s: L4 PASS (live swipe → slide player_slid=%d)"
		% [LABEL, int(live_slides[0])]
	)

	# --- Case L5: keyboard still works (request_jump) ---
	# request_jump is ignored while sliding — wait for standing again.
	if not await _wait_until_standing(player, 180):
		push_error("%s: L5 player never finished slide before request_jump." % LABEL)
		quit(1)
		return
	_reset_counts(live_jumps, live_slides)
	if not movement.has_method("request_jump"):
		push_error("%s: L5 PlayerMovement.request_jump missing." % LABEL)
		quit(1)
		return
	movement.call("request_jump")
	await _wait_frames(GESTURE_SETTLE_FRAMES)
	if int(live_jumps[0]) < 1:
		push_error("%s: L5 request_jump produced no player_jumped." % LABEL)
		quit(1)
		return
	print("%s: L5 PASS (keyboard/request_jump → player_jumped=%d)" % [LABEL, int(live_jumps[0])])

	# --- Case L6: GAME_OVER — no jump/slide from gestures ---
	# Finish L5 airborne jump so kill does not race a pending buffer.
	if not await _wait_until_standing(player, 180):
		push_error("%s: L6 never landed after L5 jump." % LABEL)
		quit(1)
		return
	player.call("kill")
	await _wait_frames(max(POST_KILL_FRAMES, 30))
	if int(gsm.get("current_state")) != STATE_GAME_OVER:
		push_error(
			"%s: L6 expected GAME_OVER after kill, got %d."
			% [LABEL, int(gsm.get("current_state"))]
		)
		quit(1)
		return
	# Re-resolve after death; nudge PlayerMovement._unhandled_input so it syncs enable flag.
	player = _find_player(game_scene)
	movement = _find_movement(player)
	live_router = _find_touch_router(player)
	if live_router == null or movement == null:
		push_error("%s: L6 router/movement missing after GAME_OVER." % LABEL)
		quit(1)
		return
	var sync_ev := InputEventMouseMotion.new()
	sync_ev.position = Vector2(1, 1)
	if movement.has_method("_unhandled_input"):
		movement.call("_unhandled_input", sync_ev)
	await _wait_frames(2)

	var go_jumps: Array = [0]
	var go_slides: Array = [0]
	if live_router.has_signal("jump_requested"):
		live_router.jump_requested.connect(func() -> void: go_jumps[0] = int(go_jumps[0]) + 1)
	if live_router.has_signal("slide_requested"):
		live_router.slide_requested.connect(func() -> void: go_slides[0] = int(go_slides[0]) + 1)

	_reset_counts(live_jumps, live_slides)
	# Drive router API only — InputEventScreenTouch on GAME_OVER restarts the run
	# (GameScene restart gesture); that would leave PLAYING and false-fail this case.
	live_router.call("begin_touch", 0, Vector2(130, 130))
	live_router.call("end_touch", 0, Vector2(131, 131))
	var go_swipe: float = float(
		live_router.call("get_swipe_threshold_px", _router_live_viewport(live_router as Node))
	)
	live_router.call("begin_touch", 0, Vector2(130, 100))
	live_router.call("end_touch", 0, Vector2(130, 100 + go_swipe + 20.0))
	await _wait_frames(GESTURE_SETTLE_FRAMES)
	if int(gsm.get("current_state")) != STATE_GAME_OVER:
		push_error(
			"%s: L6 left GAME_OVER (state=%d) — gesture must not restart."
			% [LABEL, int(gsm.get("current_state"))]
		)
		quit(1)
		return
	if int(go_jumps[0]) != 0 or int(go_slides[0]) != 0:
		push_error(
			"%s: L6 GAME_OVER router still emitted rj=%d rs=%d (enabled gate broken)"
			% [LABEL, int(go_jumps[0]), int(go_slides[0])]
		)
		quit(1)
		return
	if int(live_jumps[0]) != 0 or int(live_slides[0]) != 0:
		push_error(
			"%s: L6 GAME_OVER gesture caused jumps=%d slides=%d"
			% [LABEL, int(live_jumps[0]), int(live_slides[0])]
		)
		quit(1)
		return
	print("%s: L6 PASS (GAME_OVER no jump/slide)" % LABEL)

	# --- Case L7: restart clears prior gesture state ---
	if not game_scene.has_method("restart_run"):
		push_error("%s: L7 GameScene.restart_run missing." % LABEL)
		quit(1)
		return
	# Begin a gesture during GAME_OVER, then restart — must not complete as jump/slide.
	_reset_counts(live_jumps, live_slides)
	_reset_counts(router_jumps, router_slides)
	live_router.call("begin_touch", 0, Vector2(160, 160))
	game_scene.call("restart_run")
	await _wait_frames(POST_RESTART_FRAMES)
	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error(
			"%s: L7 expected PLAYING after restart, got %d."
			% [LABEL, int(gsm.get("current_state"))]
		)
		quit(1)
		return
	# Refresh player/router after restart (may be same nodes).
	player = _find_player(game_scene)
	movement = _find_movement(player)
	var router_after: Object = _find_touch_router(player)
	if player == null or movement == null or router_after == null:
		push_error("%s: L7 player/router missing after restart." % LABEL)
		quit(1)
		return
	## Rebind router signal counters if the router instance was replaced.
	if router_after != live_router:
		live_router = router_after
		_reset_counts(router_jumps, router_slides)
		if live_router.has_signal("jump_requested"):
			live_router.jump_requested.connect(
				func() -> void: router_jumps[0] = int(router_jumps[0]) + 1
			)
		if live_router.has_signal("slide_requested"):
			live_router.slide_requested.connect(
				func() -> void: router_slides[0] = int(router_slides[0]) + 1
			)
	else:
		live_router = router_after

	_reset_counts(live_jumps, live_slides)
	_reset_counts(router_jumps, router_slides)
	# Stale end after restart+reset must be none and must not emit any intent/bus events.
	var stale: String = str(live_router.call("end_touch", 0, Vector2(160, 160)))
	await _wait_frames(GESTURE_SETTLE_FRAMES)
	if stale != "none":
		push_error(
			"%s: L7 stale end_touch after restart expected none got %s (pre-restart gesture leaked)."
			% [LABEL, stale]
		)
		quit(1)
		return
	if int(router_jumps[0]) != 0 or int(router_slides[0]) != 0:
		push_error(
			"%s: L7 stale gesture emitted router jumps=%d slides=%d after restart."
			% [LABEL, int(router_jumps[0]), int(router_slides[0])]
		)
		quit(1)
		return
	if int(live_jumps[0]) != 0 or int(live_slides[0]) != 0:
		push_error(
			"%s: L7 stale gesture emitted player_jumped=%d player_slid=%d after restart."
			% [LABEL, int(live_jumps[0]), int(live_slides[0])]
		)
		quit(1)
		return

	_reset_counts(live_jumps, live_slides)
	_reset_counts(router_jumps, router_slides)
	live_router.call("begin_touch", 0, Vector2(170, 170))
	var l7: String = str(live_router.call("end_touch", 0, Vector2(171, 171)))
	await _wait_frames(GESTURE_SETTLE_FRAMES)
	if l7 != "jump" or int(router_jumps[0]) != 1:
		push_error(
			"%s: L7 fresh tap after restart expected jump×1 got result=%s router_jumps=%d"
			% [LABEL, l7, int(router_jumps[0])]
		)
		quit(1)
		return
	if int(router_slides[0]) != 0:
		push_error("%s: L7 fresh tap unexpectedly emitted slide." % LABEL)
		quit(1)
		return
	print("%s: L7 PASS (restart clears gesture; stale=none; fresh tap=%s)" % [LABEL, l7])

	print("M3.4 touch smoke PASS")
	quit(0)


func _reset_counts(a: Array, b: Array) -> void:
	a[0] = 0
	b[0] = 0


func _router_live_viewport(router: Node) -> Vector2:
	## Match TouchGestureRouter._viewport_size so gesture deltas clear the real threshold.
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
		for prop_name: String in [
			"touch_router",
			"_touch_router",
			"gesture_router",
			"_gesture_router",
			"router",
			"_router",
		]:
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
			# Prefer objects that also expose jump_requested (router, not movement).
			var obj: Object = cand as Object
			if obj.has_signal("jump_requested"):
				return obj
	for cand: Variant in candidates:
		if cand is Object and _router_has_contract(cand as Object):
			return cand as Object
	return null


func _inject_screen_tap(pos: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = pos
	Input.parse_input_event(press)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = pos + Vector2(1, 1)
	Input.parse_input_event(release)


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
	## On-floor (may still be SLIDING) — enough to start a slide after a jump.
	for _i: int in range(max_frames):
		await physics_frame
		if player == null:
			return false
		if player is CharacterBody2D and (player as CharacterBody2D).is_on_floor():
			return true
		if player.has_method("get_state"):
			var st: int = int(player.call("get_state"))
			# IDLE=0 RUNNING=1 SLIDING=4
			if st == 0 or st == 1 or st == 4:
				return true
	return false


func _wait_until_standing(player: Node, max_frames: int) -> bool:
	## On-floor and not SLIDING — request_jump is a no-op during slide.
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
