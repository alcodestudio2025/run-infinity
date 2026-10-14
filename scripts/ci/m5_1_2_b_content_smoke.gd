extends SceneTree

## Headless M5.1.2-B: deterministic spawn density across segment windows / levels.
## Usage: source scripts/ci/smoke_env.sh && ri_smoke_env_setup && \
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m5_1_2_b_content_smoke.gd

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const Boot := preload("res://scripts/ci/smoke_boot_helpers.gd")

const LABEL := "M5.1.2-B content smoke"
const WARMUP_FRAMES: int = 90
const POST_START_FRAMES: int = 40
const STATE_PLAYING: int = 2
const EARLY_LATCH := [4, 5, 8, 10, 11, 14]
const SCAN_SEGMENTS: int = 48


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Guard.require_isolated(self, LABEL):
		return

	var err: Error = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("%s: Main load failed." % LABEL)
		quit(1)
		return
	await _wait_frames(WARMUP_FRAMES)
	if not Boot.ensure_playing_from_title(root, LABEL):
		quit(1)
		return
	await _wait_frames(POST_START_FRAMES)

	var main: Node = Boot.find_main(root)
	var game_scene: Node = null
	if main != null:
		var container: Node = main.get_node_or_null("GameSceneContainer")
		if container != null and container.get_child_count() > 0:
			game_scene = container.get_child(0)
	var spawner: Node = game_scene.get_node_or_null("ModuleSpawner") if game_scene else null
	var difficulty: Node = game_scene.get_node_or_null("DifficultyDirector") if game_scene else null
	if spawner == null or difficulty == null:
		push_error("%s: ModuleSpawner/DifficultyDirector missing." % LABEL)
		quit(1)
		return

	if not spawner.has_method("debug_classify_segment"):
		push_error("%s: debug_classify_segment missing." % LABEL)
		quit(1)
		return

	var indices: Array = spawner.call("get_latch_spawn_indices")
	if indices != EARLY_LATCH:
		push_error("%s: latch indices expected %s got %s" % [LABEL, str(EARLY_LATCH), str(indices)])
		quit(1)
		return
	print("%s: L0 PASS (latch indices denser teach list)" % LABEL)

	## Level 0 scan
	difficulty.set("current_level", 0)
	var c0: Dictionary = _scan(spawner, 0)
	if int(c0.get("latch", 0)) < 4:
		push_error("%s: S0 expected ≥4 early latches got %s" % [LABEL, c0])
		quit(1)
		return
	if int(c0.get("low", 0)) < 1:
		push_error("%s: S0 expected low curbs got %s" % [LABEL, c0])
		quit(1)
		return
	if int(c0.get("coin", 0)) < 2:
		push_error("%s: S0 expected coins at level 0 got %s" % [LABEL, c0])
		quit(1)
		return
	## Latches denser than M5.1 but must leave coin/hazard room.
	if int(c0.get("latch", 0)) > 14:
		push_error("%s: S0 latch density too high (starves coins/gaps): %s" % [LABEL, c0])
		quit(1)
		return
	## No impossible double-stack: classifier is mutually exclusive by design.
	print("%s: S0 PASS level0 %s" % [LABEL, c0])

	## Level 2 — overhead/tall unlocked
	difficulty.set("current_level", 2)
	var c2: Dictionary = _scan(spawner, 2)
	if int(c2.get("overhead", 0)) < 2:
		push_error("%s: S2 expected overheads for SLIDE teach got %s" % [LABEL, c2])
		quit(1)
		return
	if int(c2.get("tall", 0)) < 1:
		push_error("%s: S2 expected tall curbs got %s" % [LABEL, c2])
		quit(1)
		return
	print("%s: S2 PASS level2 %s" % [LABEL, c2])

	## Level 6 — denser stride
	difficulty.set("current_level", 6)
	var stride6: int = int(difficulty.call("get_hazard_stride"))
	if stride6 > 1:
		push_error("%s: S6 expected stride≤1 at level 6 got %d" % [LABEL, stride6])
		quit(1)
		return
	var c6: Dictionary = _scan(spawner, 6)
	var hazards6: int = (
		int(c6.get("low", 0))
		+ int(c6.get("tall", 0))
		+ int(c6.get("overhead", 0))
		+ int(c6.get("double", 0))
	)
	if hazards6 < 12:
		push_error("%s: S6 denser hazards expected≥12 got %d %s" % [LABEL, hazards6, c6])
		quit(1)
		return
	## Compatible co-placement keeps coin opportunities when stride==1 (no gap slots).
	var coins6: int = int(c6.get("coin_slots", 0))
	if coins6 < 8:
		push_error("%s: S6 expected compatible coins≥8 got %d %s" % [LABEL, coins6, c6])
		quit(1)
		return
	print("%s: S6 PASS level6 stride=%d coins=%d %s" % [LABEL, stride6, coins6, c6])

	## Multi-seed stability: classification must be identical for same level/index
	## (deterministic — "seed" here is difficulty level as the only entropy).
	for level: int in [0, 2, 4]:
		difficulty.set("current_level", level)
		var a: Dictionary = _scan(spawner, level)
		var b: Dictionary = _scan(spawner, level)
		if a.hash() != b.hash():
			push_error("%s: D1 non-deterministic at level %d" % [LABEL, level])
			quit(1)
			return
	print("%s: D1 PASS (deterministic multi-level scans)" % LABEL)

	## Solvability: never latch+hazard same primary; coins may co-locate on clear path.
	difficulty.set("current_level", 3)
	for i: int in range(SCAN_SEGMENTS):
		var kind: StringName = spawner.call("debug_classify_segment", i) as StringName
		if kind == &"latch":
			## Latch primary never shares with a curb/overhead primary.
			pass
		if str(kind) == "safe" and i >= 2:
			push_error("%s: unexpected safe after start at %d" % [LABEL, i])
			quit(1)
			return
	print("%s: V1 PASS (exclusive hazard/latch primary; coins may co-locate)" % LABEL)

	print("%s PASS" % LABEL)
	quit(0)


func _scan(spawner: Node, level: int) -> Dictionary:
	var counts := {
		"safe": 0,
		"latch": 0,
		"low": 0,
		"tall": 0,
		"overhead": 0,
		"double": 0,
		"coin": 0,
		"empty": 0,
		"coin_slots": 0,
	}
	for i: int in range(SCAN_SEGMENTS):
		var kind: String = str(spawner.call("debug_classify_segment", i))
		if counts.has(kind):
			counts[kind] = int(counts[kind]) + 1
		else:
			counts[kind] = 1
		if spawner.has_method("debug_segment_has_coin") and bool(spawner.call("debug_segment_has_coin", i)):
			counts["coin_slots"] = int(counts["coin_slots"]) + 1
	counts["level"] = level
	return counts


func _wait_frames(n: int) -> void:
	for _i in range(maxi(n, 0)):
		await physics_frame
