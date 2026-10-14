extends SceneTree

## Headless M2 smoke: module variety, difficulty progression, segment continuity.
## Requires dedicated smoke userdata (scripts/ci/smoke_env.sh) — SaveManager may write on game_over.
## Usage: source scripts/ci/smoke_env.sh && ri_smoke_env_setup && \
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m2_modules_smoke.gd

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")

const WARMUP_FRAMES: int = 90
const RUN_FRAMES: int = 60 * 55
const STATE_PLAYING: int = 2
const STATE_GAME_OVER: int = 4
## Survive past the first low curb, then keep running into mid-difficulty.
const SURVIVE_PAST_FIRST: float = 7500.0
const TARGET_DISTANCE: float = 12000.0
const JUMP_WINDOW_START: float = 6000.0
const JUMP_WINDOW_END: float = 6500.0
const LABEL := "M2 modules smoke"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Guard.require_isolated(self, LABEL):
		return

	var err: Error = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("M2 smoke: failed to load Main.tscn (%s)" % error_string(err))
		quit(1)
		return

	await _wait_frames(WARMUP_FRAMES)

	var gsm: Node = root.get_node_or_null("GameStateManager")
	var game_scene: Node = _find_game_scene()
	if gsm == null or game_scene == null:
		push_error("M2 smoke: scene graph incomplete.")
		quit(1)
		return

	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error("M2 smoke: expected PLAYING after warmup.")
		quit(1)
		return

	var spawner: Node = game_scene.get_node_or_null("ModuleSpawner")
	var difficulty: Node = game_scene.get_node_or_null("DifficultyDirector")
	var segment_manager: Node = game_scene.get_node_or_null("SegmentManager")
	if spawner == null or difficulty == null or segment_manager == null:
		push_error("M2 smoke: ModuleSpawner / DifficultyDirector / SegmentManager missing.")
		quit(1)
		return

	if not spawner.has_method("setup"):
		push_error("M2 smoke: ModuleSpawner.setup missing.")
		quit(1)
		return

	var jumped: bool = false
	var saw_low: bool = false
	var saw_tall: bool = false
	var saw_overhead: bool = false
	var saw_coin: bool = false
	var max_level: int = 0
	var gap_checks: int = 0

	for _frame: int in range(RUN_FRAMES):
		await physics_frame

		if int(gsm.get("current_state")) == STATE_GAME_OVER:
			## Auto-restart once early so we can still inspect spawn mix if needed,
			## but first-curb death before a jump means the M1 placement broke.
			var velocity_dead: Node = game_scene.get_node_or_null("WorldVelocityController")
			var dist_dead: float = 0.0
			if velocity_dead != null:
				dist_dead = float(velocity_dead.get("distance_travelled"))
			if not jumped and dist_dead < SURVIVE_PAST_FIRST:
				push_error(
					"M2 smoke: died at %0.1f before clearing first curb (jumped=%s)."
					% [dist_dead, jumped]
				)
				quit(1)
				return
			if game_scene.has_method("restart_run"):
				game_scene.call("restart_run")
				jumped = false
			continue

		var velocity: Node = game_scene.get_node_or_null("WorldVelocityController")
		var player: Node = _find_player(game_scene)
		if velocity == null or player == null:
			continue

		var distance: float = float(velocity.get("distance_travelled"))
		if distance >= JUMP_WINDOW_START and distance <= JUMP_WINDOW_END:
			var movement: Node = player.get_node_or_null("PlayerMovement")
			if movement != null and movement.has_method("request_jump"):
				movement.call("request_jump")
				jumped = true

		max_level = maxi(max_level, int(difficulty.get("current_level")))
		var module_flags: Dictionary = _scan_module_flags(game_scene)
		if bool(module_flags.get("low", false)):
			saw_low = true
		if bool(module_flags.get("tall", false)):
			saw_tall = true
		if bool(module_flags.get("overhead", false)):
			saw_overhead = true
		if bool(module_flags.get("coin", false)):
			saw_coin = true

		if _active_segments_contiguous(segment_manager):
			gap_checks += 1
		else:
			push_error("M2 smoke: segment gap/overlap detected at distance %0.1f." % distance)
			quit(1)
			return

		## Exit once past first curb with progression + continuity + any advanced module.
		var advanced_seen: bool = saw_tall or saw_overhead or saw_coin
		if (
			jumped
			and distance >= TARGET_DISTANCE
			and max_level >= 2
			and saw_low
			and advanced_seen
			and gap_checks >= 180
		):
			break

	if not saw_low:
		push_error("M2 smoke: never observed ObstacleModule (low curb).")
		quit(1)
		return

	if max_level < 1:
		push_error("M2 smoke: difficulty never increased (level=%d)." % max_level)
		quit(1)
		return

	if gap_checks < 60:
		push_error("M2 smoke: insufficient contiguous segment checks (%d)." % gap_checks)
		quit(1)
		return

	## Tall unlocks at level 2; coin at 1. Require something beyond low curb.
	var advanced: int = 0
	if saw_tall:
		advanced += 1
	if saw_overhead:
		advanced += 1
	if saw_coin:
		advanced += 1

	print(
		"M2 modules smoke PASS (level=%d low=%s tall=%s overhead=%s coin=%s gaps_ok=%d)"
		% [max_level, saw_low, saw_tall, saw_overhead, saw_coin, gap_checks]
	)

	const TALL_UNLOCK_LEVEL: int = 2
	if max_level >= TALL_UNLOCK_LEVEL and advanced < 1:
		push_error(
			"M2 smoke: expected tall/overhead/coin after unlock (level=%d)." % max_level
		)
		quit(1)
		return

	quit(0)


func _scan_module_flags(game_scene: Node) -> Dictionary:
	var flags := {
		"low": false,
		"tall": false,
		"overhead": false,
		"coin": false,
	}

	## `self` is the SceneTree when launched with -s.
	for obstacle: Node in get_nodes_in_group("obstacle"):
		var key: String = _module_key(obstacle)
		match key:
			"tall":
				flags["tall"] = true
			"overhead":
				flags["overhead"] = true
			_:
				flags["low"] = true

	if not get_nodes_in_group("coin").is_empty():
		flags["coin"] = true

	## Also walk ModuleRoots in case groups were cleared mid-frame.
	var world: Node = game_scene.get_node_or_null("World")
	if world != null:
		_walk_modules(world, flags)
	return flags


func _walk_modules(node: Node, flags: Dictionary) -> void:
	var key: String = _module_key(node)
	match key:
		"low":
			flags["low"] = true
		"tall":
			flags["tall"] = true
		"overhead":
			flags["overhead"] = true
		"coin":
			flags["coin"] = true
	for child: Node in node.get_children():
		_walk_modules(child, flags)


func _module_key(node: Node) -> String:
	var label: String = String(node.name)
	var script: Script = node.get_script()
	if script != null:
		var path: String = script.resource_path
		if not path.is_empty():
			label = path.get_file().get_basename()
	label = label.to_lower()
	if "tall" in label:
		return "tall"
	if "overhead" in label:
		return "overhead"
	if "coin" in label:
		return "coin"
	if "obstacle" in label:
		return "low"
	return ""


func _active_segments_contiguous(segment_manager: Node) -> bool:
	if not segment_manager.has_method("get_active_segments"):
		return false
	var segments: Array = segment_manager.call("get_active_segments")
	if segments.size() < 2:
		return true

	var edges: Array[Dictionary] = []
	for segment: Variant in segments:
		var node := segment as Node2D
		if node == null or not node.has_method("get_length"):
			continue
		var length: float = float(node.call("get_length"))
		var left: float = node.position.x - length * 0.5
		var right: float = node.position.x + length * 0.5
		edges.append({"left": left, "right": right})

	edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["left"] < b["left"])

	const TOLERANCE: float = 1.5
	for index: int in range(1, edges.size()):
		var prev_right: float = float(edges[index - 1]["right"])
		var cur_left: float = float(edges[index]["left"])
		if absf(cur_left - prev_right) > TOLERANCE:
			return false
	return true


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
