extends SceneTree

## Headless M1 smoke: boot main scene, advance frames, force game over + restart.
## Requires dedicated smoke userdata (scripts/ci/smoke_env.sh) — SaveManager may write on game_over.
## Usage: source scripts/ci/smoke_env.sh && ri_smoke_env_setup && \
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m1_core_loop_smoke.gd
##
## Autoload singletons are resolved by node path (not global identifiers) so this
## script compiles when launched with -s.

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")

const WARMUP_FRAMES: int = 90
const POST_RESTART_FRAMES: int = 60
## Must match GameStateManager.GameState
const STATE_PLAYING: int = 2
const STATE_GAME_OVER: int = 4
const LABEL := "M1 core-loop smoke"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Guard.require_isolated(self, LABEL):
		return

	var err: Error = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("M1 smoke: failed to load Main.tscn (%s)" % error_string(err))
		quit(1)
		return

	await _wait_frames(WARMUP_FRAMES)

	var gsm: Node = _game_state()
	if gsm == null:
		push_error("M1 smoke: GameStateManager autoload missing.")
		quit(1)
		return

	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error("M1 smoke: expected PLAYING after warmup.")
		quit(1)
		return

	var game_scene: Node = _find_game_scene()
	if game_scene == null:
		push_error("M1 smoke: GameScene not found.")
		quit(1)
		return

	var velocity: Node = game_scene.get_node_or_null("WorldVelocityController")
	if velocity == null:
		push_error("M1 smoke: WorldVelocityController missing.")
		quit(1)
		return

	var distance_before: float = float(velocity.get("distance_travelled"))
	if distance_before <= 0.0:
		push_error("M1 smoke: distance did not advance during warmup.")
		quit(1)
		return

	var player: Node = _find_player(game_scene)
	if player == null:
		push_error("M1 smoke: Player not found.")
		quit(1)
		return

	player.call("kill")
	await _wait_frames(5)

	if int(gsm.get("current_state")) != STATE_GAME_OVER:
		push_error("M1 smoke: expected GAME_OVER after kill.")
		quit(1)
		return

	if not game_scene.has_method("restart_run"):
		push_error("M1 smoke: restart_run missing on GameScene.")
		quit(1)
		return

	game_scene.call("restart_run")
	await _wait_frames(POST_RESTART_FRAMES)

	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error("M1 smoke: expected PLAYING after restart.")
		quit(1)
		return

	var distance_after: float = float(velocity.get("distance_travelled"))
	if distance_after <= 0.0:
		push_error("M1 smoke: distance did not advance after restart.")
		quit(1)
		return

	if distance_after >= distance_before:
		push_error(
			"M1 smoke: distance after restart (%0.1f) should be below pre-death (%0.1f)."
			% [distance_after, distance_before]
		)
		quit(1)
		return

	print(
		"M1 core-loop smoke PASS (distance_before=%0.1f distance_after=%0.1f)"
		% [distance_before, distance_after]
	)
	quit(0)


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
