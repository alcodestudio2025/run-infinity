extends SceneTree

## Negative control for CI exit-code hardening (M5.1.1).
## Always fails: prints INTENTIONAL_FAIL and exits non-zero. Never prints PASS.
## Used by scripts/ci/m5_1_1_ci_exit_control.sh to prove || true cannot mask failures.

const LABEL := "M5.1.1 CI exit negative"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	push_error("%s: INTENTIONAL_FAIL (expected non-zero exit)" % LABEL)
	print("%s: INTENTIONAL_FAIL" % LABEL)
	quit(1)
