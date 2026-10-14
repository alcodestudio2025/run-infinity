extends SceneTree

## Headless M3.3 smoke: title screen boot → Play → game over → restart (no auto-start).
## MUST run under dedicated smoke userdata (see scripts/ci/smoke_env.sh):
##   source scripts/ci/smoke_env.sh && ri_smoke_env_setup
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m3_3_title_smoke.gd
##
## Autoload singletons are resolved by node path (not global identifiers) so this
## script compiles when launched with -s.
##
## Contract APIs (MA-004 / M3.3):
##   Main: start_game(), is_title_visible()
##   GameScene: begin_run(), is_run_active(), restart_run()
##   TitleScreen: get_displayed_best_score()
##   States: MAIN_MENU=1, PLAYING=2, GAME_OVER=4

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")

const WARMUP_FRAMES: int = 90
const HOLD_FRAMES: int = 60
const POST_START_FRAMES: int = 90
const POST_KILL_FRAMES: int = 5
const POST_RESTART_FRAMES: int = 60
## Must match GameStateManager.GameState
const STATE_MAIN_MENU: int = 1
const STATE_PLAYING: int = 2
const STATE_GAME_OVER: int = 4
const SAVE_PATH := "user://save_data.json"
const LABEL := "M3.3 title smoke"
const SEEDED_BEST: int = 100
## Distance at title / before Play must stay near zero (float slack).
const DISTANCE_EPS: float = 0.5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Fail-fast BEFORE any delete/reset/userdata write.
	if not Guard.require_isolated(self, LABEL):
		return

	_clear_isolated_save_file()

	var save_manager: Node = _save_manager()
	if save_manager == null:
		push_error("%s: SaveManager autoload missing." % LABEL)
		quit(1)
		return

	# --- Seed preexisting best before Main loads ---
	save_manager.call("reset_data")
	var data: Object = save_manager.get("data")
	if data == null:
		push_error("%s: SaveManager.data null after reset_data." % LABEL)
		quit(1)
		return
	data.set("high_score", SEEDED_BEST)
	save_manager.call("save_data")
	if int(save_manager.get("data").get("high_score")) != SEEDED_BEST:
		push_error("%s: failed to seed high_score=%d." % [LABEL, SEEDED_BEST])
		quit(1)
		return

	var err: Error = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("%s: failed to load Main.tscn (%s)" % [LABEL, error_string(err)])
		quit(1)
		return

	await _wait_frames(WARMUP_FRAMES)

	var gsm: Node = _game_state()
	if gsm == null:
		push_error("%s: GameStateManager autoload missing." % LABEL)
		quit(1)
		return

	var main: Node = _find_main()
	if main == null:
		push_error("%s: Main not found." % LABEL)
		quit(1)
		return

	if not main.has_method("start_game") or not main.has_method("is_title_visible"):
		push_error("%s: Main missing start_game/is_title_visible contract." % LABEL)
		quit(1)
		return

	var game_scene: Node = _find_game_scene(main)
	if game_scene == null:
		push_error("%s: GameScene not found under GameSceneContainer." % LABEL)
		quit(1)
		return

	if not game_scene.has_method("restart_run"):
		push_error("%s: GameScene missing restart_run." % LABEL)
		quit(1)
		return

	var title: Node = _find_title_screen(main)
	if title == null or not title.has_method("get_displayed_best_score"):
		push_error("%s: TitleScreen with get_displayed_best_score not found." % LABEL)
		quit(1)
		return

	var velocity: Node = game_scene.get_node_or_null("WorldVelocityController")
	if velocity == null:
		push_error("%s: WorldVelocityController missing." % LABEL)
		quit(1)
		return

	# --- Case 1: seed high_score=100; after warmup MAIN_MENU + title + best + distance~0 ---
	if int(gsm.get("current_state")) != STATE_MAIN_MENU:
		push_error(
			"%s: case1 expected MAIN_MENU after warmup, got %d."
			% [LABEL, int(gsm.get("current_state"))]
		)
		quit(1)
		return

	if not bool(main.call("is_title_visible")):
		push_error("%s: case1 expected is_title_visible()==true." % LABEL)
		quit(1)
		return

	var best_shown: int = int(title.call("get_displayed_best_score"))
	if best_shown != SEEDED_BEST:
		push_error(
			"%s: case1 Title best=%d expected %d."
			% [LABEL, best_shown, SEEDED_BEST]
		)
		quit(1)
		return

	var dist1: float = float(velocity.get("distance_travelled"))
	if dist1 > DISTANCE_EPS:
		push_error("%s: case1 distance=%0.3f expected ~0 at title." % [LABEL, dist1])
		quit(1)
		return

	if game_scene.has_method("is_run_active") and bool(game_scene.call("is_run_active")):
		push_error("%s: case1 expected is_run_active()==false at title." % LABEL)
		quit(1)
		return

	print(
		"%s: case1 PASS (MAIN_MENU title visible best=%d distance=%0.3f)"
		% [LABEL, best_shown, dist1]
	)

	# --- Case 2: hold frames — still MAIN_MENU, no auto-start, distance still ~0 ---
	await _wait_frames(HOLD_FRAMES)

	if int(gsm.get("current_state")) != STATE_MAIN_MENU:
		push_error(
			"%s: case2 auto-started (state=%d) — expected still MAIN_MENU."
			% [LABEL, int(gsm.get("current_state"))]
		)
		quit(1)
		return

	if not bool(main.call("is_title_visible")):
		push_error("%s: case2 title became hidden without start_game()." % LABEL)
		quit(1)
		return

	var dist2: float = float(velocity.get("distance_travelled"))
	if dist2 > DISTANCE_EPS:
		push_error("%s: case2 distance advanced to %0.3f without Play." % [LABEL, dist2])
		quit(1)
		return

	print("%s: case2 PASS (still MAIN_MENU distance=%0.3f)" % [LABEL, dist2])

	# --- Case 3: start_game() → PLAYING, title hidden, distance increases ---
	main.call("start_game")
	await _wait_frames(POST_START_FRAMES)

	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error(
			"%s: case3 expected PLAYING after start_game(), got %d."
			% [LABEL, int(gsm.get("current_state"))]
		)
		quit(1)
		return

	if bool(main.call("is_title_visible")):
		push_error("%s: case3 expected is_title_visible()==false after start_game()." % LABEL)
		quit(1)
		return

	if game_scene.has_method("is_run_active") and not bool(game_scene.call("is_run_active")):
		push_error("%s: case3 expected is_run_active()==true while PLAYING." % LABEL)
		quit(1)
		return

	var dist3: float = float(velocity.get("distance_travelled"))
	if dist3 <= DISTANCE_EPS:
		push_error("%s: case3 distance=%0.3f did not increase after start_game()." % [LABEL, dist3])
		quit(1)
		return

	print("%s: case3 PASS (PLAYING title hidden distance=%0.3f)" % [LABEL, dist3])

	# --- Case 4: kill player → GAME_OVER; high_score coherent (>= seed) ---
	var high_before_kill: int = int(save_manager.get("data").get("high_score"))
	var player: Node = _find_player(game_scene)
	if player == null:
		push_error("%s: case4 Player not found." % LABEL)
		quit(1)
		return

	player.call("kill")
	await _wait_frames(POST_KILL_FRAMES)

	if int(gsm.get("current_state")) != STATE_GAME_OVER:
		push_error(
			"%s: case4 expected GAME_OVER after kill, got %d."
			% [LABEL, int(gsm.get("current_state"))]
		)
		quit(1)
		return

	var high_after_kill: int = int(save_manager.get("data").get("high_score"))
	if high_after_kill < SEEDED_BEST:
		push_error(
			"%s: case4 high_score dropped below seed (%d < %d)."
			% [LABEL, high_after_kill, SEEDED_BEST]
		)
		quit(1)
		return
	if high_after_kill < high_before_kill:
		push_error(
			"%s: case4 high_score dropped after kill (%d < %d)."
			% [LABEL, high_after_kill, high_before_kill]
		)
		quit(1)
		return

	print(
		"%s: case4 PASS (GAME_OVER high_score=%d seed=%d)"
		% [LABEL, high_after_kill, SEEDED_BEST]
	)

	# --- Case 5: restart_run() → PLAYING; high_score not wiped ---
	var high_before_restart: int = high_after_kill
	game_scene.call("restart_run")
	await _wait_frames(POST_RESTART_FRAMES)

	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error(
			"%s: case5 expected PLAYING after restart_run(), got %d."
			% [LABEL, int(gsm.get("current_state"))]
		)
		quit(1)
		return

	var high_after_restart: int = int(save_manager.get("data").get("high_score"))
	if high_after_restart != high_before_restart:
		push_error(
			"%s: case5 high_score wiped/changed on restart (%d vs %d)."
			% [LABEL, high_after_restart, high_before_restart]
		)
		quit(1)
		return

	# Restart must not force a return to title.
	if bool(main.call("is_title_visible")):
		push_error("%s: case5 title reappeared after restart_run()." % LABEL)
		quit(1)
		return

	var dist5: float = float(velocity.get("distance_travelled"))
	if dist5 <= DISTANCE_EPS:
		push_error("%s: case5 distance=%0.3f did not advance after restart." % [LABEL, dist5])
		quit(1)
		return

	print(
		"%s: case5 PASS (PLAYING after restart high_score=%d distance=%0.3f)"
		% [LABEL, high_after_restart, dist5]
	)

	print("M3.3 title smoke PASS")
	quit(0)


func _clear_isolated_save_file() -> void:
	## Only called after Guard.require_isolated — never touch real userdata.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _save_manager() -> Node:
	return root.get_node_or_null("SaveManager")


func _game_state() -> Node:
	return root.get_node_or_null("GameStateManager")


func _find_main() -> Node:
	var current: Node = get_current_scene()
	if current != null and _main_has_contract(current):
		return current
	# Prefer named Main under root, then any root child with contract methods.
	var named: Node = root.get_node_or_null("Main")
	if named != null and _main_has_contract(named):
		return named
	for child: Node in root.get_children():
		if _main_has_contract(child):
			return child
	return null


func _main_has_contract(node: Node) -> bool:
	return node.has_method("start_game") and node.has_method("is_title_visible")


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


func _find_title_screen(main: Node) -> Node:
	if main == null:
		return null
	# Prefer name, then Title contract (set_visible_menu) — never pick HUD which
	# also exposes get_displayed_best_score under GameScene.
	var named: Node = main.get_node_or_null("TitleScreen")
	if named != null and _title_has_contract(named):
		return named
	for child: Node in main.get_children():
		if _title_has_contract(child):
			return child
		for grand: Node in child.get_children():
			if _title_has_contract(grand):
				return grand
	return _find_title_recursive(main)


func _title_has_contract(node: Node) -> bool:
	if node == null or not node.has_method("get_displayed_best_score"):
		return false
	if node.name == "HUD":
		return false
	# TitleScreen name or set_visible_menu (contract) distinguishes from HUD.
	return node.name == "TitleScreen" or node.has_method("set_visible_menu")


func _find_title_recursive(node: Node) -> Node:
	if _title_has_contract(node):
		return node
	for child: Node in node.get_children():
		var found: Node = _find_title_recursive(child)
		if found != null:
			return found
	return null


func _find_player(game_scene: Node) -> Node:
	var player_root: Node = game_scene.get_node_or_null("PlayerRoot")
	if player_root == null or player_root.get_child_count() == 0:
		return null
	return player_root.get_child(0)


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await physics_frame
