extends SceneTree

## Headless M1 smoke: auto-jump near the first obstacle and require survival past it.
## Usage: godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m1_jump_clear_smoke.gd

const MAX_FRAMES: int = 60 * 45
const STATE_PLAYING: int = 2
const STATE_GAME_OVER: int = 4
## First obstacle is segment index 6 (safe start 4, then %3==0) → ~12300 distance.
const JUMP_WINDOW_START: float = 11950.0
const JUMP_WINDOW_END: float = 12280.0
const SURVIVE_DISTANCE: float = 13500.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var err: Error = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("M1 jump smoke: failed to load Main.tscn (%s)" % error_string(err))
		quit(1)
		return

	var jumped: bool = false
	for _frame: int in range(MAX_FRAMES):
		await physics_frame

		var gsm: Node = root.get_node_or_null("GameStateManager")
		var game_scene: Node = _find_game_scene()
		if gsm == null or game_scene == null:
			push_error("M1 jump smoke: scene graph incomplete.")
			quit(1)
			return

		if int(gsm.get("current_state")) == STATE_GAME_OVER:
			var velocity_dead: Node = game_scene.get_node_or_null("WorldVelocityController")
			var dist_dead: float = 0.0
			if velocity_dead != null:
				dist_dead = float(velocity_dead.get("distance_travelled"))
			push_error("M1 jump smoke: died at distance %0.1f (jumped=%s)." % [dist_dead, jumped])
			quit(1)
			return

		var velocity: Node = game_scene.get_node_or_null("WorldVelocityController")
		var player: Node = _find_player(game_scene)
		if velocity == null or player == null:
			continue

		var distance: float = float(velocity.get("distance_travelled"))
		if distance >= JUMP_WINDOW_START and distance <= JUMP_WINDOW_END:
			var movement: Node = player.get_node_or_null("PlayerMovement")
			if movement == null or not movement.has_method("request_jump"):
				push_error("M1 jump smoke: PlayerMovement.request_jump missing.")
				quit(1)
				return
			movement.call("request_jump")
			jumped = true

		if jumped and distance >= SURVIVE_DISTANCE and int(gsm.get("current_state")) == STATE_PLAYING:
			print(
				"M1 jump-clear smoke PASS (distance=%0.1f jumped=%s)"
				% [distance, jumped]
			)
			quit(0)
			return

	push_error("M1 jump smoke: timed out before surviving past first obstacle.")
	quit(1)


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
