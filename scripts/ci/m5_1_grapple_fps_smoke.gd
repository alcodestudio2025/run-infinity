extends SceneTree

## M5.1: Grapple simulator stability across 30/60/120 Hz fixed steps.
## Compares attach→auto-release outcomes within tolerances (not bit-identical).
## MUST run under smoke userdata:
##   source scripts/ci/smoke_env.sh && ri_smoke_env_setup
##   godot --headless --path . -s res://scripts/ci/m5_1_grapple_fps_smoke.gd

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const SimConfigScript := preload("res://scripts/grapple/GrappleSimConfig.gd")
const SimScript := preload("res://scripts/grapple/DeterministicGrappleSimulator.gd")

const LABEL := "M5.1 grapple-fps smoke"
const PLAYER_POS := Vector2(100.0, 800.0)
const GOOD_LATCH := Vector2(280.0, 620.0)
## Tolerances across discrete step rates (constant-ω release).
const POS_TOL: float = 24.0
const VEL_TOL: float = 80.0
const TIME_TOL: float = 0.04


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Guard.require_isolated(self, LABEL):
		return

	var ref60: Dictionary = _run_at_hz(60.0)
	var at30: Dictionary = _run_at_hz(30.0)
	var at120: Dictionary = _run_at_hz(120.0)

	if not bool(ref60.get("ok", false)):
		push_error("%s: 60Hz baseline failed." % LABEL)
		quit(1)
		return
	if not _within(ref60, at30, "30Hz"):
		quit(1)
		return
	if not _within(ref60, at120, "120Hz"):
		quit(1)
		return

	print(
		"%s PASS (60Hz launch=%s; 30/120 within tol pos=%.0f vel=%.0f time=%.2f)"
		% [LABEL, ref60["launch"], POS_TOL, VEL_TOL, TIME_TOL]
	)
	quit(0)


func _run_at_hz(hz: float) -> Dictionary:
	var cfg: RefCounted = SimConfigScript.new()
	var sim: RefCounted = SimScript.new(cfg)
	sim.call("set_player_state", PLAYER_POS, Vector2(0.0, -200.0))
	sim.call("set_latches", [GOOD_LATCH])
	if not bool(sim.call("try_attach")):
		return {"ok": false}
	var dt: float = 1.0 / hz
	var duration: float = float(cfg.get("swing_duration"))
	var safety: int = int(ceil(duration / dt)) + 8
	for _i in range(safety):
		sim.call("step", dt)
		if int(sim.get("phase")) == 2: ## RELEASED
			break
	var launch: Vector2 = sim.get("last_release_velocity") as Vector2
	var pos: Vector2 = sim.get("player_pos") as Vector2
	var elapsed: float = float(sim.get("swing_elapsed"))
	var ok: bool = (
		int(sim.get("release_count")) == 1
		and launch.x > 0.0
		and elapsed + 1e-4 >= duration - TIME_TOL
	)
	return {
		"ok": ok,
		"launch": launch,
		"pos": pos,
		"elapsed": elapsed,
		"hz": hz,
	}


func _within(ref: Dictionary, other: Dictionary, tag: String) -> bool:
	if not bool(other.get("ok", false)):
		push_error("%s: %s run failed." % [LABEL, tag])
		return false
	var rp: Vector2 = ref["pos"] as Vector2
	var op: Vector2 = other["pos"] as Vector2
	if rp.distance_to(op) > POS_TOL:
		push_error(
			"%s: %s pos drift %0.1f > %0.1f (ref=%s other=%s)"
			% [LABEL, tag, rp.distance_to(op), POS_TOL, rp, op]
		)
		return false
	var rv: Vector2 = ref["launch"] as Vector2
	var ov: Vector2 = other["launch"] as Vector2
	if rv.distance_to(ov) > VEL_TOL:
		push_error(
			"%s: %s launch drift %0.1f > %0.1f (ref=%s other=%s)"
			% [LABEL, tag, rv.distance_to(ov), VEL_TOL, rv, ov]
		)
		return false
	if absf(float(ref["elapsed"]) - float(other["elapsed"])) > TIME_TOL:
		push_error(
			"%s: %s elapsed drift (ref=%0.3f other=%0.3f)"
			% [LABEL, tag, float(ref["elapsed"]), float(other["elapsed"])]
		)
		return false
	print("%s: %s OK vs 60Hz" % [LABEL, tag])
	return true
