extends SceneTree

## Headless M3.2 smoke: Best Score HUD contract (display, NEW BEST, baseline).
## MUST run under dedicated smoke userdata (see scripts/ci/smoke_env.sh):
##   source scripts/ci/smoke_env.sh && ri_smoke_env_setup
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m3_2_hud_smoke.gd
##
## Autoload singletons are resolved by node path (not global identifiers) so this
## script compiles when launched with -s.
##
## Drives HUD methods after seeding SaveManager — does not rely on live kill scores.

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const Boot := preload("res://scripts/ci/smoke_boot_helpers.gd")

const WARMUP_FRAMES: int = 90
const POST_START_FRAMES: int = 30
const POST_CALL_FRAMES: int = 3
## Must match GameStateManager.GameState
const STATE_PLAYING: int = 2
const STATE_GAME_OVER: int = 4
const SAVE_PATH := "user://save_data.json"
const LABEL := "M3.2 HUD smoke"
const BASELINE: int = 100
const NEW_RECORD: int = 150


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Fail-fast BEFORE any delete/reset/userdata write.
	if not Guard.require_isolated(self, LABEL):
		return

	_clear_isolated_save_file()

	var save_manager: Node = _save_manager()
	var event_bus: Node = _event_bus()
	if save_manager == null or event_bus == null:
		push_error("%s: SaveManager or EventBus autoload missing." % LABEL)
		quit(1)
		return

	# --- Seed preexisting best before Main loads ---
	save_manager.call("reset_data")
	var data: Object = save_manager.get("data")
	if data == null:
		push_error("%s: SaveManager.data null after reset_data." % LABEL)
		quit(1)
		return
	data.set("high_score", BASELINE)
	save_manager.call("save_data")
	if int(save_manager.get("data").get("high_score")) != BASELINE:
		push_error("%s: failed to seed high_score=%d." % [LABEL, BASELINE])
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
		push_error("%s: GameStateManager missing." % LABEL)
		quit(1)
		return

	## M3.3: start from title so HUD becomes visible and baseline is live.
	if not Boot.ensure_playing_from_title(root, LABEL):
		quit(1)
		return
	await _wait_frames(POST_START_FRAMES)

	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error("%s: expected PLAYING after start_game." % LABEL)
		quit(1)
		return

	var game_scene: Node = _find_game_scene()
	if game_scene == null:
		push_error("%s: GameScene not found." % LABEL)
		quit(1)
		return

	var hud: Node = _find_hud(game_scene)
	if hud == null:
		push_error("%s: HUD with contract methods not found." % LABEL)
		quit(1)
		return

	# --- Case 1: bootstrap with preexisting best ---
	if not _assert_eq(int(hud.call("get_displayed_best_score")), BASELINE, "case1 displayed best"):
		return
	if not _assert_eq(int(hud.call("get_baseline_best_score")), BASELINE, "case1 baseline"):
		return
	if not _assert_eq(bool(hud.call("is_new_best_visible")), false, "case1 NEW BEST hidden"):
		return
	print("%s: case1 PASS (best=%d baseline=%d NEW BEST hidden)" % [LABEL, BASELINE, BASELINE])

	# Freeze GameScene HUD ticks: while PLAYING it calls show_running() every
	# physics frame and would clear NEW BEST before we can assert.
	gsm.call("transition_to", STATE_GAME_OVER)
	await _wait_frames(POST_CALL_FRAMES)
	if int(gsm.get("current_state")) != STATE_GAME_OVER:
		push_error("%s: failed to enter GAME_OVER for HUD method tests." % LABEL)
		quit(1)
		return

	# --- Case 2: new best (score > baseline) ---
	hud.call("show_game_over", NEW_RECORD, 10.0)
	await _wait_frames(POST_CALL_FRAMES)
	if not _assert_eq(bool(hud.call("is_new_best_visible")), true, "case2 NEW BEST visible"):
		return
	print("%s: case2 PASS (show_game_over(%d) → NEW BEST)" % [LABEL, NEW_RECORD])

	# --- Case 3: no new best when lower ---
	# Re-snap baseline to 100 so this case is independent of case2 UI state.
	if not _ensure_baseline(hud, save_manager, BASELINE):
		return
	hud.call("show_game_over", 90, 10.0)
	await _wait_frames(POST_CALL_FRAMES)
	if not _assert_eq(bool(hud.call("is_new_best_visible")), false, "case3 NEW BEST hidden (90)"):
		return
	print("%s: case3 PASS (show_game_over(90) → no NEW BEST)" % LABEL)

	# --- Case 4: no new best on tie ---
	if not _ensure_baseline(hud, save_manager, BASELINE):
		return
	hud.call("show_game_over", BASELINE, 10.0)
	await _wait_frames(POST_CALL_FRAMES)
	if not _assert_eq(bool(hud.call("is_new_best_visible")), false, "case4 NEW BEST hidden (tie)"):
		return
	print("%s: case4 PASS (show_game_over(%d) tie → no NEW BEST)" % [LABEL, BASELINE])

	# --- Case 5: restart baseline after simulated record ---
	# Production order: EventBus.game_over (SaveManager updates) then HUD.show_game_over, then reset.
	event_bus.emit_signal("game_over", NEW_RECORD, 10.0)
	if int(save_manager.get("data").get("high_score")) != NEW_RECORD:
		push_error(
			"%s: case5 SaveManager high_score=%d expected %d after game_over emit."
			% [LABEL, int(save_manager.get("data").get("high_score")), NEW_RECORD]
		)
		quit(1)
		return

	hud.call("show_game_over", NEW_RECORD, 10.0)
	await _wait_frames(POST_CALL_FRAMES)
	hud.call("reset")
	# Assert score zero synchronously: reset() sets it; no GameScene overwrite in GAME_OVER.
	if not _assert_score_label_zero(hud):
		return
	await _wait_frames(POST_CALL_FRAMES)

	if not _assert_eq(int(hud.call("get_displayed_best_score")), NEW_RECORD, "case5 displayed best"):
		return
	if not _assert_eq(int(hud.call("get_baseline_best_score")), NEW_RECORD, "case5 baseline"):
		return
	if not _assert_eq(bool(hud.call("is_new_best_visible")), false, "case5 NEW BEST hidden"):
		return
	print(
		"%s: case5 PASS (reset after record → best=%d baseline=%d Score: 0 NEW BEST hidden)"
		% [LABEL, NEW_RECORD, NEW_RECORD]
	)

	print("M3.2 HUD smoke PASS")
	quit(0)


func _ensure_baseline(hud: Node, save_manager: Node, expected: int) -> bool:
	## Keep SaveManager at expected and re-snapshot HUD baseline via reset().
	var data: Object = save_manager.get("data")
	if data == null:
		push_error("%s: SaveManager.data null while ensuring baseline." % LABEL)
		quit(1)
		return false
	data.set("high_score", expected)
	save_manager.call("save_data")
	hud.call("reset")
	# reset() may be followed by GameScene _process updating score — wait a frame then
	# re-check baseline; do not depend on live score for NEW BEST cases.
	# We only need baseline == expected before the next show_game_over.
	if int(hud.call("get_baseline_best_score")) != expected:
		push_error(
			"%s: baseline=%d expected %d after reset seed."
			% [LABEL, int(hud.call("get_baseline_best_score")), expected]
		)
		quit(1)
		return false
	return true


func _assert_eq(actual: Variant, expected: Variant, context: String) -> bool:
	if actual != expected:
		push_error("%s: %s got %s expected %s." % [LABEL, context, str(actual), str(expected)])
		quit(1)
		return false
	return true


func _assert_score_label_zero(hud: Node) -> bool:
	var score_label: Node = hud.get_node_or_null("TopLeftContainer/Content/ScoreLabel")
	if score_label == null:
		# Fallback: force update_score(0) then re-read if label appears later — still fail clear.
		if hud.has_method("update_score"):
			hud.call("update_score", 0)
			score_label = hud.get_node_or_null("TopLeftContainer/Content/ScoreLabel")
	if score_label == null:
		push_error("%s: case5 ScoreLabel missing." % LABEL)
		quit(1)
		return false
	var text: String = str(score_label.get("text"))
	if text != "Score: 0":
		# Accept parsed zero if formatting matches Score: %d
		var parsed: int = _parse_score_label(text)
		if parsed != 0:
			push_error("%s: case5 score label text=%s expected Score: 0." % [LABEL, text])
			quit(1)
			return false
	return true


func _parse_score_label(text: String) -> int:
	var prefix := "Score: "
	if text.begins_with(prefix):
		return int(text.substr(prefix.length()))
	return -1


func _clear_isolated_save_file() -> void:
	## Only called after Guard.require_isolated — never touch real userdata.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _save_manager() -> Node:
	return root.get_node_or_null("SaveManager")


func _event_bus() -> Node:
	return root.get_node_or_null("EventBus")


func _game_state() -> Node:
	return root.get_node_or_null("GameStateManager")


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


func _find_hud(game_scene: Node) -> Node:
	var ui_root: Node = game_scene.get_node_or_null("UIRoot")
	if ui_root != null:
		var named: Node = ui_root.get_node_or_null("HUD")
		if named != null and _hud_has_contract(named):
			return named
		for child: Node in ui_root.get_children():
			if child.name == "HUD" or child is CanvasLayer:
				if _hud_has_contract(child):
					return child

	# Depth-first fallback: any descendant with contract methods.
	return _find_hud_recursive(game_scene)


func _find_hud_recursive(node: Node) -> Node:
	if _hud_has_contract(node):
		return node
	for child: Node in node.get_children():
		var found: Node = _find_hud_recursive(child)
		if found != null:
			return found
	return null


func _hud_has_contract(node: Node) -> bool:
	return (
		node.has_method("get_displayed_best_score")
		and node.has_method("is_new_best_visible")
		and node.has_method("get_baseline_best_score")
		and node.has_method("show_game_over")
		and node.has_method("reset")
	)


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await physics_frame
