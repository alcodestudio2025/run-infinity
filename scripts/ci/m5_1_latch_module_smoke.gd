extends SceneTree

## Headless M5.1 smoke: LatchModule joins Tags.ANCHOR on activate and leaves on deactivate.
## Also checks ModuleSpawner early latch indices via debug_force_latch_on_next + natural wait.
## Requires dedicated smoke userdata (scripts/ci/smoke_env.sh).
## Usage: source scripts/ci/smoke_env.sh && ri_smoke_env_setup && \
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m5_1_latch_module_smoke.gd
##
## Autoload singletons / class_name globals are NOT used at parse time (-s launch).

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const Boot := preload("res://scripts/ci/smoke_boot_helpers.gd")

const WARMUP_FRAMES: int = 90
const POST_START_FRAMES: int = 60
const STATE_PLAYING: int = 2
const LABEL := "M5.1 latch-module smoke"
## Mirror GameConfig.LATCH_SEGMENT_INDICES / Tags.ANCHOR
const ANCHOR_GROUP := "anchor"
const EARLY_LATCH_INDICES := [4, 8, 11]
const LATCH_SCENE_PATH := "res://scenes/modules/LatchModule.tscn"


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
	var spawner: Node = null
	if game_scene != null:
		spawner = game_scene.get_node_or_null("ModuleSpawner")
	if game_scene == null or spawner == null:
		push_error("%s: GameScene / ModuleSpawner missing." % LABEL)
		quit(1)
		return

	if not spawner.has_method("get_latch_spawn_indices"):
		push_error("%s: ModuleSpawner.get_latch_spawn_indices missing." % LABEL)
		quit(1)
		return

	var indices: Array = spawner.call("get_latch_spawn_indices")
	if indices != EARLY_LATCH_INDICES:
		push_error(
			"%s: expected latch indices %s, got %s" % [LABEL, str(EARLY_LATCH_INDICES), str(indices)]
		)
		quit(1)
		return

	## Unit-style: instantiate LatchModule, activate → ANCHOR, deactivate → gone.
	if not await _assert_latch_lifecycle():
		quit(1)
		return

	## Spawner one-shot: force latch onto an empty safe-start recycle inject.
	if not spawner.has_method("debug_force_latch_on_next"):
		push_error("%s: ModuleSpawner.debug_force_latch_on_next missing." % LABEL)
		quit(1)
		return

	if not await _assert_forced_spawner_latch(game_scene, spawner):
		quit(1)
		return

	## Explicitly free pooled segments before quit (SegmentManager._exit_tree also does this).
	if spawner != null:
		var seg_mgr: Node = game_scene.get_node_or_null("SegmentManager")
		if seg_mgr != null and seg_mgr.has_method("free_pooled_segments"):
			seg_mgr.call("free_pooled_segments")
	await _wait_frames(1)

	print("%s: PASS" % LABEL)
	quit(0)


func _assert_latch_lifecycle() -> bool:
	var packed: PackedScene = load(LATCH_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("%s: failed to load LatchModule.tscn." % LABEL)
		return false

	var latch: Node2D = packed.instantiate() as Node2D
	if latch == null:
		push_error("%s: LatchModule instantiate failed." % LABEL)
		return false

	root.add_child(latch)
	await _wait_frames(2)

	if latch.has_method("setup"):
		latch.call("setup", {"local_position": Vector2(100.0, -220.0)})
	if latch.has_method("activate"):
		latch.call("activate")
	await _wait_frames(2)

	if not latch.is_in_group(ANCHOR_GROUP):
		push_error("%s: LatchModule not in ANCHOR after activate." % LABEL)
		latch.free()
		return false
	if latch.has_method("is_latch_valid") and not bool(latch.call("is_latch_valid")):
		push_error("%s: is_latch_valid() false after activate." % LABEL)
		latch.free()
		return false
	if not latch.has_method("get_latch_global_position"):
		push_error("%s: get_latch_global_position missing." % LABEL)
		latch.free()
		return false

	var pos: Vector2 = latch.call("get_latch_global_position") as Vector2
	if pos == Vector2.ZERO and latch.global_position != Vector2.ZERO:
		push_error("%s: latch global position unexpected zero." % LABEL)
		latch.free()
		return false

	if latch.has_method("deactivate"):
		latch.call("deactivate")
	await _wait_frames(1)

	if latch.is_in_group(ANCHOR_GROUP):
		push_error("%s: LatchModule still in ANCHOR after deactivate." % LABEL)
		latch.free()
		return false
	if latch.has_method("is_latch_valid") and bool(latch.call("is_latch_valid")):
		push_error("%s: is_latch_valid() true after deactivate." % LABEL)
		latch.free()
		return false

	latch.free()
	print("%s: lifecycle OK (activate→ANCHOR, deactivate→leave)." % LABEL)
	return true


func _assert_forced_spawner_latch(game_scene: Node, spawner: Node) -> bool:
	var segment_manager: Node = game_scene.get_node_or_null("SegmentManager")
	if segment_manager == null or not segment_manager.has_method("request_segment"):
		push_error("%s: SegmentManager.request_segment missing." % LABEL)
		return false

	spawner.call("debug_force_latch_on_next")
	var segment: Node = segment_manager.call("request_segment") as Node
	if segment == null:
		push_error("%s: request_segment returned null." % LABEL)
		return false

	await _wait_frames(3)

	var anchors: Array[Node] = get_nodes_in_group(ANCHOR_GROUP)
	var found: bool = false
	for node: Node in anchors:
		if node.has_method("is_latch_valid") and node.has_method("get_latch_global_position"):
			if not bool(node.call("is_latch_valid")):
				push_error("%s: spawned LatchModule is_latch_valid() false." % LABEL)
				return false
			found = true
			break

	if not found:
		push_error(
			"%s: no LatchModule in ANCHOR after debug_force_latch_on_next + populate."
			% LABEL
		)
		return false

	## Recycle must invalidate: Segment.reset_segment deactivate+free.
	if segment_manager.has_method("release_segment"):
		segment_manager.call("release_segment", segment)
		await _wait_frames(2)
		for node: Node in get_nodes_in_group(ANCHOR_GROUP):
			## Released segment's latch must be gone; ignore our earlier free'd nodes.
			if is_instance_valid(node) and node.is_inside_tree():
				var parent_seg: Node = node
				while parent_seg != null and parent_seg != segment:
					parent_seg = parent_seg.get_parent()
				if parent_seg == segment:
					push_error("%s: latch still ANCHOR on released segment." % LABEL)
					return false

	print("%s: spawner force + ANCHOR populate OK." % LABEL)
	return true


func _find_game_scene() -> Node:
	var main: Node = Boot.find_main(root)
	if main == null:
		return null
	var container: Node = main.get_node_or_null("GameSceneContainer")
	if container == null:
		return null
	for child: Node in container.get_children():
		if child.get_node_or_null("ModuleSpawner") != null:
			return child
	return null


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame
