extends SceneTree

## Headless M3.1 smoke: high_score persistence via EventBus.game_over → SaveManager.
## MUST run under dedicated smoke userdata (see scripts/ci/smoke_env.sh):
##   source scripts/ci/smoke_env.sh && ri_smoke_env_setup
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m3_best_score_smoke.gd
##
## Autoload singletons are resolved by node path (not global identifiers) so this
## script compiles when launched with -s.

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const Boot := preload("res://scripts/ci/smoke_boot_helpers.gd")

const WARMUP_FRAMES: int = 90
const POST_START_FRAMES: int = 60
const POST_KILL_FRAMES: int = 5
const POST_RESTART_FRAMES: int = 30
## Must match GameStateManager.GameState
const STATE_PLAYING: int = 2
const STATE_GAME_OVER: int = 4
const SAVE_PATH := "user://save_data.json"
const LABEL := "M3 best-score smoke"


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

	# Ensure clean in-memory + disk state for this isolated process.
	save_manager.call("reset_data")
	if int(save_manager.get("data").get("high_score")) != 0:
		push_error("M3 best-score smoke: expected high_score 0 after reset.")
		quit(1)
		return

	var connections_before: int = _game_over_handler_count(event_bus, save_manager)
	if connections_before != 1:
		push_error(
			"M3 best-score smoke: expected 1 SaveManager game_over connection at start, got %d."
			% connections_before
		)
		quit(1)
		return

	# --- Synthetic emits: new record, lower score, higher record ---
	event_bus.emit_signal("game_over", 100, 40.0)
	if not _check_high_score(save_manager, 100, "after first record"):
		return
	if not _check_total_runs(save_manager, 1, "after first record"):
		return

	event_bus.emit_signal("game_over", 50, 20.0)
	if not _check_high_score(save_manager, 100, "lower score must not lower record"):
		return
	if not _check_total_runs(save_manager, 2, "after lower score"):
		return

	event_bus.emit_signal("game_over", 250, 90.0)
	if not _check_high_score(save_manager, 250, "after beating record"):
		return
	if not _check_total_runs(save_manager, 3, "after new record"):
		return

	# --- Disk round-trip (simulates fresh app instance reload) ---
	save_manager.set("data", null)
	save_manager.call("load_data")
	if not _check_high_score(save_manager, 250, "after load_data round-trip"):
		return

	if not FileAccess.file_exists(SAVE_PATH):
		push_error("M3 best-score smoke: save_data.json missing after writes.")
		quit(1)
		return

	var reloaded := _read_save_dict()
	if int(reloaded.get("high_score", -1)) != 250:
		push_error(
			"M3 best-score smoke: disk high_score=%s expected 250."
			% str(reloaded.get("high_score", null))
		)
		quit(1)
		return

	# --- Live run: kill → restart ×3 must keep high_score and not duplicate connections ---
	var err: Error = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("M3 best-score smoke: failed to load Main.tscn (%s)" % error_string(err))
		quit(1)
		return

	await _wait_frames(WARMUP_FRAMES)

	var gsm: Node = _game_state()
	if gsm == null:
		push_error("M3 best-score smoke: GameStateManager missing.")
		quit(1)
		return

	## M3.3 title gate: live kill/restart portion requires PLAYING via start_game.
	if not Boot.ensure_playing_from_title(root, LABEL):
		quit(1)
		return
	await _wait_frames(POST_START_FRAMES)

	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error("M3 best-score smoke: expected PLAYING after start_game.")
		quit(1)
		return

	var game_scene: Node = _find_game_scene()
	if game_scene == null:
		push_error("M3 best-score smoke: GameScene not found.")
		quit(1)
		return

	var record_before_live: int = int(save_manager.get("data").get("high_score"))

	for restart_i: int in range(3):
		var player: Node = _find_player(game_scene)
		if player == null:
			push_error("M3 best-score smoke: Player missing before kill #%d." % (restart_i + 1))
			quit(1)
			return

		player.call("kill")
		await _wait_frames(POST_KILL_FRAMES)

		if int(gsm.get("current_state")) != STATE_GAME_OVER:
			push_error("M3 best-score smoke: expected GAME_OVER on kill #%d." % (restart_i + 1))
			quit(1)
			return

		var high_now: int = int(save_manager.get("data").get("high_score"))
		if high_now < record_before_live:
			push_error(
				"M3 best-score smoke: high_score dropped after live game_over (%d < %d)."
				% [high_now, record_before_live]
			)
			quit(1)
			return
		record_before_live = maxi(record_before_live, high_now)

		game_scene.call("restart_run")
		await _wait_frames(POST_RESTART_FRAMES)

		if int(gsm.get("current_state")) != STATE_PLAYING:
			push_error("M3 best-score smoke: expected PLAYING after restart #%d." % (restart_i + 1))
			quit(1)
			return

		if int(save_manager.get("data").get("high_score")) < record_before_live:
			push_error("M3 best-score smoke: restart_run reset high_score.")
			quit(1)
			return

	var connections_after: int = _game_over_handler_count(event_bus, save_manager)
	if connections_after != 1:
		push_error(
			"M3 best-score smoke: expected exactly 1 SaveManager game_over connection after restarts, got %d (before=%d)."
			% [connections_after, connections_before]
		)
		quit(1)
		return

	print(
		"M3 best-score smoke PASS (high_score=%d total_runs=%d connections=%d)"
		% [
			int(save_manager.get("data").get("high_score")),
			int(save_manager.get("data").get("total_runs")),
			connections_after,
		]
	)
	quit(0)


func _clear_isolated_save_file() -> void:
	## Only called after Guard.require_isolated — never touch real userdata.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _check_high_score(save_manager: Node, expected: int, context: String) -> bool:
	var actual: int = int(save_manager.get("data").get("high_score"))
	if actual != expected:
		push_error("M3 best-score smoke: high_score=%d expected %d (%s)." % [actual, expected, context])
		quit(1)
		return false
	return true


func _check_total_runs(save_manager: Node, expected: int, context: String) -> bool:
	var actual: int = int(save_manager.get("data").get("total_runs"))
	if actual != expected:
		push_error("M3 best-score smoke: total_runs=%d expected %d (%s)." % [actual, expected, context])
		quit(1)
		return false
	return true


func _game_over_handler_count(event_bus: Node, save_manager: Node) -> int:
	var count: int = 0
	var connections: Array = event_bus.get_signal_connection_list("game_over")
	for entry: Variant in connections:
		var callable: Callable = entry["callable"]
		if callable.get_object() == save_manager:
			count += 1
	return count


func _read_save_dict() -> Dictionary:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not (json.data is Dictionary):
		return {}
	return json.data


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


func _find_player(game_scene: Node) -> Node:
	var player_root: Node = game_scene.get_node_or_null("PlayerRoot")
	if player_root == null or player_root.get_child_count() == 0:
		return null
	return player_root.get_child(0)


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await physics_frame
