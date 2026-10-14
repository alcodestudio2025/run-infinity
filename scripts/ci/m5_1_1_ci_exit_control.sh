#!/usr/bin/env bash
# M5.1.1: prove Godot non-zero exits fail the step (no || true masking).
# Positive outcome of THIS script is that the intentional failing smoke exits != 0
# and does not print PASS.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=scripts/ci/smoke_env.sh
source scripts/ci/smoke_env.sh
export RI_SMOKE_ROOT="${RI_SMOKE_ROOT:-/tmp/ri-smoke-m511-exit-$$}"
ri_smoke_env_setup

LOG="${TMPDIR:-/tmp}/m5-1-1-ci-exit-negative.log"
set +e
godot --headless --path . --fixed-fps 60 \
  -s res://scripts/ci/m5_1_1_ci_exit_negative_smoke.gd 2>&1 | tee "$LOG"
GODOT_EXIT=${PIPESTATUS[0]}
set -e

if [[ "$GODOT_EXIT" -eq 0 ]]; then
  echo "M5.1.1 CI exit-code control FAIL: negative smoke exited 0" >&2
  exit 1
fi

if grep -qE 'smoke: PASS|smoke PASS' "$LOG"; then
  echo "M5.1.1 CI exit-code control FAIL: PASS must not appear" >&2
  exit 1
fi

if ! grep -q 'INTENTIONAL_FAIL' "$LOG"; then
  echo "M5.1.1 CI exit-code control FAIL: INTENTIONAL_FAIL marker missing" >&2
  exit 1
fi

echo "M5.1.1 CI exit-code control PASS (godot_exit=${GODOT_EXIT})"
