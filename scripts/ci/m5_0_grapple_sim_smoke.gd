extends SceneTree

## Headless M5.0 smoke: deterministic isolated Grapple simulator.
## Does NOT load Main.tscn or touch PlayerMovement / TouchGestureRouter.
## MUST run under dedicated smoke userdata (see scripts/ci/smoke_env.sh):
##   source scripts/ci/smoke_env.sh && ri_smoke_env_setup
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m5_0_grapple_sim_smoke.gd
##
## Autoload globals are avoided at parse time (-s). Scripts are preloaded.

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const SimConfigScript := preload("res://scripts/grapple/GrappleSimConfig.gd")
## Real deterministic sim (extends GrappleSimulator contract used by GrappleController).
const SimScript := preload("res://scripts/grapple/DeterministicGrappleSimulator.gd")
const LatchQueryScript := preload("res://scripts/grapple/GrappleLatchQuery.gd")

const LABEL := "M5.0 grapple-sim smoke"
const FIXED_DT: float = 1.0 / 60.0
const PHASE_IDLE: int = 0
const PHASE_ATTACHED: int = 1
const PHASE_RELEASED: int = 2

## Player standing-ish origin; latch ahead (+X) and above (−Y).
const PLAYER_POS := Vector2(100.0, 800.0)
const GOOD_LATCH := Vector2(280.0, 620.0)
const FAR_LATCH := Vector2(900.0, 500.0)
const BEHIND_LATCH := Vector2(20.0, 620.0)
const BELOW_LATCH := Vector2(280.0, 900.0)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Guard.require_isolated(self, LABEL):
		return

	if not _case_attach_success():
		return
	if not _case_misses():
		return
	if not _case_swing_duration():
		return
	if not _case_auto_release_launch():
		return
	if not _case_reset_after_death():
		return
	if not _case_determinism():
		return

	print("%s PASS" % LABEL)
	quit(0)


func _make_config() -> RefCounted:
	return SimConfigScript.new()


func _make_sim(config: RefCounted = null) -> RefCounted:
	var cfg: RefCounted = config if config != null else _make_config()
	return SimScript.new(cfg)


func _case_attach_success() -> bool:
	var sim: RefCounted = _make_sim()
	sim.call("set_player_state", PLAYER_POS, Vector2.ZERO)
	sim.call("set_latches", [GOOD_LATCH, FAR_LATCH])
	if not bool(sim.call("try_attach")):
		push_error("%s: C1 expected attach success for latch ahead/above in range." % LABEL)
		quit(1)
		return false
	if int(sim.get("phase")) != PHASE_ATTACHED:
		push_error("%s: C1 expected ATTACHED phase got %d." % [LABEL, int(sim.get("phase"))])
		quit(1)
		return false
	if int(sim.get("attached_latch_index")) != 0:
		push_error(
			"%s: C1 expected nearest latch index 0 got %d."
			% [LABEL, int(sim.get("attached_latch_index"))]
		)
		quit(1)
		return false
	print("%s: C1 PASS (attach ahead/above in range)" % LABEL)
	return true


func _case_misses() -> bool:
	## No latch
	var sim_empty: RefCounted = _make_sim()
	sim_empty.call("set_player_state", PLAYER_POS)
	sim_empty.call("set_latches", [])
	if bool(sim_empty.call("try_attach")) or int(sim_empty.get("phase")) != PHASE_IDLE:
		push_error("%s: C2a expected miss with no latches." % LABEL)
		quit(1)
		return false

	## Out of range
	var sim_far: RefCounted = _make_sim()
	sim_far.call("set_player_state", PLAYER_POS)
	sim_far.call("set_latches", [FAR_LATCH])
	if bool(sim_far.call("try_attach")):
		push_error("%s: C2b expected miss when latch out of max radius." % LABEL)
		quit(1)
		return false

	## Behind player
	var sim_behind: RefCounted = _make_sim()
	sim_behind.call("set_player_state", PLAYER_POS)
	sim_behind.call("set_latches", [BEHIND_LATCH])
	if bool(sim_behind.call("try_attach")):
		push_error("%s: C2c expected miss when latch behind player." % LABEL)
		quit(1)
		return false

	## Below (not above)
	var sim_below: RefCounted = _make_sim()
	sim_below.call("set_player_state", PLAYER_POS)
	sim_below.call("set_latches", [BELOW_LATCH])
	if bool(sim_below.call("try_attach")):
		push_error("%s: C2d expected miss when latch below player." % LABEL)
		quit(1)
		return false

	## Query helper agrees on behind
	var cfg: RefCounted = _make_config()
	if bool(LatchQueryScript.is_valid_latch(PLAYER_POS, BEHIND_LATCH, cfg)):
		push_error("%s: C2e LatchQuery should reject behind latch." % LABEL)
		quit(1)
		return false

	print("%s: C2 PASS (miss: empty / out-of-range / behind / below)" % LABEL)
	return true


func _case_swing_duration() -> bool:
	var cfg: RefCounted = _make_config()
	var duration: float = float(cfg.swing_duration)
	var sim: RefCounted = _make_sim(cfg)
	sim.call("set_player_state", PLAYER_POS)
	sim.call("set_latches", [GOOD_LATCH])
	if not bool(sim.call("try_attach")):
		push_error("%s: C3 attach failed." % LABEL)
		quit(1)
		return false

	var frames_before: int = int(floor(duration / FIXED_DT)) - 1
	sim.call("step_n", frames_before)
	if int(sim.get("phase")) != PHASE_ATTACHED:
		push_error(
			"%s: C3 expected still ATTACHED before duration (%d frames) got phase=%d."
			% [LABEL, frames_before, int(sim.get("phase"))]
		)
		quit(1)
		return false

	## Step through remaining swing + one extra.
	var safety: int = int(ceil(duration / FIXED_DT)) + 4
	var released := false
	for _i in range(safety):
		sim.call("step")
		if int(sim.get("phase")) == PHASE_RELEASED:
			released = true
			break

	if not released:
		push_error("%s: C3 swing did not complete within configured duration." % LABEL)
		quit(1)
		return false

	var elapsed: float = float(sim.get("swing_elapsed"))
	if elapsed + 0.0001 < duration:
		push_error(
			"%s: C3 swing_elapsed=%0.4f < duration=%0.4f."
			% [LABEL, elapsed, duration]
		)
		quit(1)
		return false

	print(
		"%s: C3 PASS (oscillation completes in %0.2fs, elapsed=%0.4f)"
		% [LABEL, duration, elapsed]
	)
	return true


func _case_auto_release_launch() -> bool:
	var cfg: RefCounted = _make_config()
	var duration: float = float(cfg.swing_duration)
	var sim: RefCounted = _make_sim(cfg)
	sim.call("set_player_state", PLAYER_POS)
	sim.call("set_latches", [GOOD_LATCH])
	sim.call("try_attach")
	sim.call("step_n", int(ceil(duration / FIXED_DT)) + 2)

	if int(sim.get("phase")) != PHASE_RELEASED:
		push_error("%s: C4 expected RELEASED after swing." % LABEL)
		quit(1)
		return false
	if int(sim.get("release_count")) != 1:
		push_error(
			"%s: C4 expected release_count=1 got %d."
			% [LABEL, int(sim.get("release_count"))]
		)
		quit(1)
		return false
	if not bool(sim.get("release_fired")):
		push_error("%s: C4 release_fired should be true." % LABEL)
		quit(1)
		return false

	var launch: Vector2 = sim.get("last_release_velocity") as Vector2
	if launch.x <= 0.0:
		push_error("%s: C4 expected forward (+X) launch velocity got %s." % [LABEL, launch])
		quit(1)
		return false

	## Extra steps must not re-fire release.
	sim.call("step_n", 10)
	if int(sim.get("release_count")) != 1:
		push_error("%s: C4 auto-release must fire once only." % LABEL)
		quit(1)
		return false

	print(
		"%s: C4 PASS (auto-release×1 launch=%s)"
		% [LABEL, launch]
	)
	return true


func _case_reset_after_death() -> bool:
	var sim: RefCounted = _make_sim()
	sim.call("set_player_state", PLAYER_POS)
	sim.call("set_latches", [GOOD_LATCH])
	sim.call("try_attach")
	sim.call("step_n", 5)
	sim.call("reset_after_death", Vector2(50.0, 800.0))

	if int(sim.get("phase")) != PHASE_IDLE:
		push_error("%s: C5 expected IDLE after death reset." % LABEL)
		quit(1)
		return false
	if int(sim.get("release_count")) != 0 or int(sim.get("attach_successes")) != 0:
		push_error("%s: C5 counters should clear on reset." % LABEL)
		quit(1)
		return false
	if int(sim.get("latch_positions").size()) != 0:
		push_error("%s: C5 latches should clear on reset." % LABEL)
		quit(1)
		return false
	var pos: Vector2 = sim.get("player_pos") as Vector2
	if pos != Vector2(50.0, 800.0):
		push_error("%s: C5 spawn pos not applied got %s." % [LABEL, pos])
		quit(1)
		return false

	print("%s: C5 PASS (death/restart reset clears state)" % LABEL)
	return true


func _case_determinism() -> bool:
	var samples_a: Array = _run_identical_scenario()
	var samples_b: Array = _run_identical_scenario()
	if samples_a.size() != samples_b.size():
		push_error("%s: C6 sample count mismatch." % LABEL)
		quit(1)
		return false

	for i in range(samples_a.size()):
		if not _samples_equal(samples_a[i], samples_b[i]):
			push_error("%s: C6 determinism mismatch at sample %d." % [LABEL, i])
			quit(1)
			return false

	print("%s: C6 PASS (identical sims → identical key samples ×%d)" % [LABEL, samples_a.size()])
	return true


func _run_identical_scenario() -> Array:
	var cfg: RefCounted = _make_config()
	var sim: RefCounted = _make_sim(cfg)
	sim.call("set_player_state", PLAYER_POS, Vector2(0.0, -200.0))
	sim.call("set_latches", [GOOD_LATCH, Vector2(320.0, 600.0)])
	sim.call("try_attach")

	var out: Array = []
	out.append(_key_sample(sim))
	var total_frames: int = int(ceil(float(cfg.swing_duration) / FIXED_DT)) + 8
	for i in range(total_frames):
		sim.call("step")
		if i % 5 == 0 or i == total_frames - 1:
			out.append(_key_sample(sim))
	return out


func _key_sample(sim: RefCounted) -> Dictionary:
	var s: Dictionary = sim.call("sample") as Dictionary
	return {
		"phase": int(s["phase"]),
		"player_pos": s["player_pos"],
		"player_vel": s["player_vel"],
		"swing_elapsed": float(s["swing_elapsed"]),
		"release_count": int(s["release_count"]),
		"last_release_velocity": s["last_release_velocity"],
		"sim_steps": int(s["sim_steps"]),
		"sim_time": float(s["sim_time"]),
		"attached_latch_pos": s["attached_latch_pos"],
		"rope_length": float(s["rope_length"]),
	}


func _samples_equal(a: Dictionary, b: Dictionary) -> bool:
	if int(a["phase"]) != int(b["phase"]):
		return false
	if int(a["release_count"]) != int(b["release_count"]):
		return false
	if int(a["sim_steps"]) != int(b["sim_steps"]):
		return false
	if not _vec_eq(a["player_pos"] as Vector2, b["player_pos"] as Vector2):
		return false
	if not _vec_eq(a["player_vel"] as Vector2, b["player_vel"] as Vector2):
		return false
	if not _vec_eq(a["last_release_velocity"] as Vector2, b["last_release_velocity"] as Vector2):
		return false
	if not _vec_eq(a["attached_latch_pos"] as Vector2, b["attached_latch_pos"] as Vector2):
		return false
	if absf(float(a["swing_elapsed"]) - float(b["swing_elapsed"])) > 1e-9:
		return false
	if absf(float(a["sim_time"]) - float(b["sim_time"])) > 1e-9:
		return false
	if absf(float(a["rope_length"]) - float(b["rope_length"])) > 1e-9:
		return false
	return true


func _vec_eq(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= 1e-9 and absf(a.y - b.y) <= 1e-9
