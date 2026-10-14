extends SceneTree

## Headless M5.0 smoke: GrappleController FSM + LatchSelector + NullGrappleSimulator.
## Does NOT load Main / GameScene and does NOT touch PlayerMovement / TouchGestureRouter.
## Usage: godot --headless --path . -s res://scripts/ci/m5_0_grapple_arch_smoke.gd

const LABEL := "M5.0 grapple-arch smoke"

const GrappleControllerScr := preload("res://scripts/grapple/GrappleController.gd")
const GrappleStateScr := preload("res://scripts/grapple/GrappleState.gd")
const GrappleConfigScr := preload("res://scripts/grapple/GrappleConfig.gd")
const LatchPointScr := preload("res://scripts/grapple/LatchPoint.gd")
const LatchSelectorScr := preload("res://scripts/grapple/LatchSelector.gd")
const ArrayLatchProviderScr := preload("res://scripts/grapple/ArrayLatchProvider.gd")
const NullGrappleSimulatorScr := preload("res://scripts/grapple/NullGrappleSimulator.gd")

var _saw_attached: bool = false
var _saw_released: bool = false
var _release_impulse: Vector2 = Vector2.ZERO


func _initialize() -> void:
	call_deferred("_run")


func _on_attached(_latch: Variant) -> void:
	_saw_attached = true


func _on_released(impulse: Vector2) -> void:
	_saw_released = true
	_release_impulse = impulse


func _run() -> void:
	print("%s: start" % LABEL)

	if not _test_latch_selector():
		quit(1)
		return
	if not _test_request_guards():
		quit(1)
		return
	if not _test_full_cycle():
		quit(1)
		return
	if not _test_reset_on_death():
		quit(1)
		return
	if not _test_reject_behind():
		quit(1)
		return

	print("%s: PASS" % LABEL)
	quit(0)


func _phase_idle() -> int:
	return GrappleStateScr.Phase.IDLE


func _phase_seeking() -> int:
	return GrappleStateScr.Phase.SEEKING


func _phase_attached() -> int:
	return GrappleStateScr.Phase.ATTACHED


func _phase_released() -> int:
	return GrappleStateScr.Phase.RELEASED


func _test_latch_selector() -> bool:
	var player := Vector2(100.0, 800.0)
	var ahead_above = LatchPointScr.new(&"a", Vector2(250.0, 600.0))
	var behind = LatchPointScr.new(&"b", Vector2(50.0, 600.0))
	var too_far = LatchPointScr.new(&"c", Vector2(900.0, 500.0))
	var candidates: Array = [ahead_above, behind, too_far]
	## Typed Array[LatchPoint] for selector — rebuild.
	var typed: Array = []
	typed.assign(candidates)

	if LatchSelectorScr.is_valid_candidate(player, behind):
		push_error("%s: behind latch should be invalid" % LABEL)
		return false
	if LatchSelectorScr.is_valid_candidate(player, too_far):
		push_error("%s: out-of-range latch should be invalid" % LABEL)
		return false
	if not LatchSelectorScr.is_valid_candidate(player, ahead_above):
		push_error("%s: ahead+above latch should be valid" % LABEL)
		return false

	var best = LatchSelectorScr.select_best(player, typed)
	if best == null or best.id != &"a":
		push_error("%s: select_best failed (got %s)" % [LABEL, best])
		return false
	print("%s: latch selector OK" % LABEL)
	return true


func _test_request_guards() -> bool:
	var ctrl = GrappleControllerScr.new()
	ctrl.update_host_values(Vector2(100, 800), Vector2.ZERO, false, true)
	if ctrl.request_air_ability():
		push_error("%s: grounded request should fail" % LABEL)
		return false
	ctrl.update_host_values(Vector2(100, 700), Vector2(0, -200), true, true)
	## No latches — seek then fail.
	if not ctrl.request_air_ability():
		push_error("%s: airborne request should accept" % LABEL)
		return false
	if ctrl.get_phase() != _phase_seeking() and ctrl.get_phase() != _phase_idle():
		push_error("%s: unexpected phase after empty seek: %s" % [LABEL, ctrl.get_state_name()])
		return false
	## Drain seek timeout.
	var t := 0.0
	while ctrl.get_phase() == _phase_seeking() and t < 1.0:
		ctrl.process(0.02)
		t += 0.02
	if ctrl.get_phase() != _phase_idle():
		push_error("%s: empty seek should return IDLE" % LABEL)
		return false
	print("%s: request guards OK" % LABEL)
	return true


func _test_full_cycle() -> bool:
	var player := Vector2(100.0, 800.0)
	var latch = LatchPointScr.new(&"hook", Vector2(280.0, 520.0))
	var provider = ArrayLatchProviderScr.new([latch])
	var ctrl = GrappleControllerScr.new()
	ctrl.set_latch_provider(provider)
	ctrl.set_simulator(NullGrappleSimulatorScr.new())
	ctrl.update_host_values(player, Vector2(40, -300), true, true)

	_saw_attached = false
	_saw_released = false
	_release_impulse = Vector2.ZERO
	ctrl.attached.connect(_on_attached)
	ctrl.released.connect(_on_released)

	if not ctrl.request_air_ability():
		push_error("%s: full-cycle request failed" % LABEL)
		return false
	if ctrl.get_phase() != _phase_attached():
		push_error("%s: expected ATTACHED after successful seek, got %s" % [LABEL, ctrl.get_state_name()])
		return false
	if not _saw_attached:
		push_error("%s: attached signal missing" % LABEL)
		return false

	## Advance past MAX_ATTACH_DURATION via NullGrappleSimulator auto-release.
	var max_dur: float = GrappleConfigScr.MAX_ATTACH_DURATION_SEC
	var t := 0.0
	while ctrl.get_phase() == _phase_attached() and t < max_dur + 0.5:
		ctrl.process(1.0 / 60.0)
		t += 1.0 / 60.0

	if ctrl.get_phase() != _phase_released() and ctrl.get_phase() != _phase_idle():
		push_error("%s: expected RELEASED/IDLE after auto-release, got %s" % [LABEL, ctrl.get_state_name()])
		return false
	if not _saw_released:
		push_error("%s: released signal missing (indefinite hang?)" % LABEL)
		return false
	if _release_impulse == Vector2.ZERO:
		push_error("%s: release impulse should be non-zero" % LABEL)
		return false

	## Settle RELEASED → IDLE.
	t = 0.0
	while ctrl.get_phase() != _phase_idle() and t < 1.0:
		ctrl.process(1.0 / 60.0)
		t += 1.0 / 60.0
	if ctrl.get_phase() != _phase_idle():
		push_error("%s: did not return to IDLE" % LABEL)
		return false

	print("%s: full cycle OK (impulse=%s)" % [LABEL, _release_impulse])
	return true


func _test_reset_on_death() -> bool:
	var latch = LatchPointScr.new(&"hook", Vector2(280.0, 520.0))
	var ctrl = GrappleControllerScr.new()
	ctrl.set_latch_provider(ArrayLatchProviderScr.new([latch]))
	ctrl.update_host_values(Vector2(100, 800), Vector2.ZERO, true, true)
	ctrl.request_air_ability()
	if ctrl.get_phase() != _phase_attached():
		push_error("%s: reset test setup failed" % LABEL)
		return false
	ctrl.reset()
	if ctrl.get_phase() != _phase_idle():
		push_error("%s: reset should force IDLE" % LABEL)
		return false
	if ctrl.get_active_latch() != null:
		push_error("%s: reset should clear latch" % LABEL)
		return false
	print("%s: reset OK" % LABEL)
	return true


func _test_reject_behind() -> bool:
	var behind = LatchPointScr.new(&"back", Vector2(20.0, 500.0))
	var ctrl = GrappleControllerScr.new()
	ctrl.set_latch_provider(ArrayLatchProviderScr.new([behind]))
	ctrl.update_host_values(Vector2(100, 800), Vector2.ZERO, true, true)
	ctrl.request_air_ability()
	var t := 0.0
	while ctrl.is_busy() and t < 1.0:
		ctrl.process(0.02)
		t += 0.02
	if ctrl.get_phase() != _phase_idle():
		push_error("%s: behind-only seek should fail to IDLE" % LABEL)
		return false
	print("%s: reject behind OK" % LABEL)
	return true
