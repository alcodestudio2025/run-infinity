extends SceneTree

## Headless M5.1.2-E: late-run coin opportunities via compatible co-placement.
## Scans ≥100 segments at early / mid / advanced levels; checks reachability lanes.
## Usage: source scripts/ci/smoke_env.sh && ri_smoke_env_setup && \
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m5_1_2_e_coins_smoke.gd

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const Boot := preload("res://scripts/ci/smoke_boot_helpers.gd")

const LABEL := "M5.1.2-E coins smoke"
const WARMUP_FRAMES: int = 90
const POST_START_FRAMES: int = 40
const SCAN_SEGMENTS: int = 100
## Min coin-bearing segments per 100 at each band (compat period 3 → ~33 theoretical).
const MIN_COINS_EARLY: int = 20
const MIN_COINS_MID: int = 20
const MIN_COINS_ADVANCED: int = 25
const COIN_VALUE: int = 300


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Guard.require_isolated(self, LABEL):
		return

	var GC = preload("res://scripts/core/GameConfig.gd")
	if GC == null or int(GC.COIN_SCORE_VALUE) != COIN_VALUE:
		push_error("%s: COIN_SCORE_VALUE must stay %d." % [LABEL, COIN_VALUE])
		quit(1)
		return
	print("%s: V0 PASS coin value=%d" % [LABEL, COIN_VALUE])

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
	if not spawner.has_method("debug_segment_has_coin"):
		push_error("%s: debug_segment_has_coin missing." % LABEL)
		quit(1)
		return
	if not spawner.has_method("debug_segment_coin_lane"):
		push_error("%s: debug_segment_coin_lane missing." % LABEL)
		quit(1)
		return

	## Early (level 0, stride 3), mid (level 3, stride 2), advanced (level 6, stride 1).
	var bands: Array = [
		{"level": 0, "min_coins": MIN_COINS_EARLY, "label": "early"},
		{"level": 3, "min_coins": MIN_COINS_MID, "label": "mid"},
		{"level": 6, "min_coins": MIN_COINS_ADVANCED, "label": "advanced"},
	]
	var reports: Array = []
	for band: Dictionary in bands:
		var level: int = int(band["level"])
		difficulty.set("current_level", level)
		var stride: int = int(difficulty.call("get_hazard_stride"))
		var scan: Dictionary = _scan(spawner, SCAN_SEGMENTS)
		scan["level"] = level
		scan["stride"] = stride
		scan["label"] = str(band["label"])
		reports.append(scan)

		var coins: int = int(scan.get("coin_slots", 0))
		var hazards: int = int(scan.get("hazards", 0))
		if coins < int(band["min_coins"]):
			push_error(
				"%s: %s L%d coin slots %d < min %d (stride=%d) %s"
				% [LABEL, band["label"], level, coins, int(band["min_coins"]), stride, scan]
			)
			quit(1)
			return
		## Hazard density must not collapse vs prior M5.1.2-C expectations.
		if level >= 6 and hazards < 70:
			push_error(
				"%s: advanced hazard density collapsed hazards=%d %s"
				% [LABEL, hazards, scan]
			)
			quit(1)
			return
		print(
			"%s: DENSITY PASS %s L%d stride=%d coins=%d hazards=%d latches=%d gap=%d compat=%d"
			% [
				LABEL,
				band["label"],
				level,
				stride,
				coins,
				hazards,
				int(scan.get("latch", 0)),
				int(scan.get("gap_coin", 0)),
				int(scan.get("compat_coin", 0)),
			]
		)

	## Reachability: co-placed coins use the clear-action lane.
	difficulty.set("current_level", 6)
	var bad_lane: int = 0
	for i: int in range(SCAN_SEGMENTS):
		if not bool(spawner.call("debug_segment_has_coin", i)):
			continue
		var kind: String = str(spawner.call("debug_classify_segment", i))
		var lane: int = int(spawner.call("debug_segment_coin_lane", i))
		if kind == "overhead" and lane != 0:
			bad_lane += 1
		elif kind == "latch" and lane != 2:
			bad_lane += 1
		elif kind in ["low", "tall", "double"] and lane != 1:
			bad_lane += 1
	if bad_lane > 0:
		push_error("%s: R1 incompatible coin lanes count=%d" % [LABEL, bad_lane])
		quit(1)
		return
	print("%s: R1 PASS reachability lanes on advanced co-placement" % LABEL)

	## Determinism across repeated scans (level as seed).
	for level: int in [0, 3, 6]:
		difficulty.set("current_level", level)
		var a: Dictionary = _scan(spawner, SCAN_SEGMENTS)
		var b: Dictionary = _scan(spawner, SCAN_SEGMENTS)
		if a.hash() != b.hash():
			push_error("%s: N1 non-deterministic at level %d" % [LABEL, level])
			quit(1)
			return
	print("%s: N1 PASS deterministic 100-seg scans (levels 0/3/6)" % LABEL)

	## No latch+hazard dual primary; coins may share hazard/latch slices.
	difficulty.set("current_level", 6)
	for i: int in range(SCAN_SEGMENTS):
		var kind: String = str(spawner.call("debug_classify_segment", i))
		if kind == "safe" and i >= 2:
			push_error("%s: unexpected safe at %d" % [LABEL, i])
			quit(1)
			return
	print("%s: S1 PASS no impossible safe gaps after start" % LABEL)

	print("%s PASS reports=%s" % [LABEL, str(reports)])
	quit(0)


func _scan(spawner: Node, n: int) -> Dictionary:
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
		"gap_coin": 0,
		"compat_coin": 0,
		"hazards": 0,
	}
	for i: int in range(n):
		var kind: String = str(spawner.call("debug_classify_segment", i))
		if counts.has(kind):
			counts[kind] = int(counts[kind]) + 1
		else:
			counts[kind] = 1
		if kind in ["low", "tall", "overhead", "double"]:
			counts["hazards"] = int(counts["hazards"]) + 1
		if bool(spawner.call("debug_segment_has_coin", i)):
			counts["coin_slots"] = int(counts["coin_slots"]) + 1
			if kind == "coin":
				counts["gap_coin"] = int(counts["gap_coin"]) + 1
			else:
				counts["compat_coin"] = int(counts["compat_coin"]) + 1
	return counts


func _wait_frames(n: int) -> void:
	for _i in range(maxi(n, 0)):
		await physics_frame
