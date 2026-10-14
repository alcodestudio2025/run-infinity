extends SceneTree

## Headless M5.1.2-C: speed curve, reaction window, score weighting.
## Usage: source scripts/ci/smoke_env.sh && ri_smoke_env_setup && \
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m5_1_2_c_balance_smoke.gd

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")

const LABEL := "M5.1.2-C balance smoke"
const BASE: float = 340.0
const MAX_SPD: float = 620.0
const RAMP: float = 9000.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Guard.require_isolated(self, LABEL):
		return

	var GC = preload("res://scripts/core/GameConfig.gd")
	if GC == null:
		push_error("%s: GameConfig missing." % LABEL)
		quit(1)
		return

	var s0: float = float(GC.get_target_speed_for_distance(0.0))
	var s2k: float = float(GC.get_target_speed_for_distance(2000.0))
	var s5k: float = float(GC.get_target_speed_for_distance(5000.0))
	var s9k: float = float(GC.get_target_speed_for_distance(9000.0))
	var s20k: float = float(GC.get_target_speed_for_distance(20000.0))

	if absf(s0 - BASE) > 1.0:
		push_error("%s: start speed expected ~%0.0f got %0.1f" % [LABEL, BASE, s0])
		quit(1)
		return
	if not (s2k > s0 + 15.0):
		push_error("%s: speed at 2k must rise perceptibly (%0.1f → %0.1f)" % [LABEL, s0, s2k])
		quit(1)
		return
	if not (s5k > s2k + 20.0):
		push_error("%s: mid-run acceleration flat (%0.1f → %0.1f)" % [LABEL, s2k, s5k])
		quit(1)
		return
	if absf(s9k - MAX_SPD) > 2.0:
		push_error("%s: at ramp end expected ~max %0.0f got %0.1f" % [LABEL, MAX_SPD, s9k])
		quit(1)
		return
	if absf(s20k - MAX_SPD) > 0.5:
		push_error("%s: past ramp must clamp at max got %0.1f" % [LABEL, s20k])
		quit(1)
		return
	print(
		"%s: S1 PASS curve 0/2k/5k/9k = %0.0f/%0.0f/%0.0f/%0.0f"
		% [LABEL, s0, s2k, s5k, s9k]
	)

	var react: float = float(GC.min_reaction_window_sec())
	if react < 2.5:
		push_error("%s: R1 reaction window too tight %0.2fs" % [LABEL, react])
		quit(1)
		return
	print("%s: R1 PASS min reaction %0.2fs" % [LABEL, react])

	var coin: int = int(GC.COIN_SCORE_VALUE)
	var dist_score: int = int(GC.distance_to_score(1000.0))
	if coin < 100 or coin > 500:
		push_error("%s: C1 coin value out of band %d" % [LABEL, coin])
		quit(1)
		return
	if dist_score != 1000:
		push_error("%s: C1 distance score scale unexpected %d" % [LABEL, dist_score])
		quit(1)
		return
	## ~8 coins should matter vs 1k distance.
	if coin * 8 < dist_score * 0.5:
		push_error("%s: C1 coins too weak vs distance" % LABEL)
		quit(1)
		return
	print("%s: C1 PASS coin=%d dist1000=%d" % [LABEL, coin, dist_score])

	var boost_cap: float = float(GC.MAX_BOOST_WORLD_SPEED)
	var max_prog: float = float(GC.MAX_WORLD_SPEED)
	if boost_cap <= max_prog:
		push_error("%s: boost cap should exceed progression max" % LABEL)
		quit(1)
		return
	print("%s: B1 PASS boost_cap=%0.0f > max=%0.0f" % [LABEL, boost_cap, max_prog])

	print("%s PASS" % LABEL)
	quit(0)
