#!/usr/bin/env bash
# Positive + negative save-safety checks for M3.1.1.
# - Positive: isolated M3 smoke PASS
# - Negative: without isolation, smoke refuses AND a real-userdata sentinel is unchanged
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=scripts/ci/smoke_env.sh
source "$ROOT_DIR/scripts/ci/smoke_env.sh"

REAL_UD="${HOME}/.local/share/godot/app_userdata/RunInfinity"
SENTINEL_PATH="${REAL_UD}/ri_smoke_sentinel.txt"
SENTINEL_TOKEN="RI-SMOKE-SENTINEL-$(date +%s)-$$"
SAVE_SENTINEL_PATH="${REAL_UD}/save_data.json"
SAVE_BACKUP=""
HAD_SAVE=0
PLANTED_SAVE=0

cleanup() {
	if [[ "$HAD_SAVE" -eq 1 && -n "$SAVE_BACKUP" && -f "$SAVE_BACKUP" ]]; then
		mv -f "$SAVE_BACKUP" "$SAVE_SENTINEL_PATH"
	elif [[ "$PLANTED_SAVE" -eq 1 ]]; then
		rm -f "$SAVE_SENTINEL_PATH"
	fi
	rm -f "$SENTINEL_PATH"
}
trap cleanup EXIT

mkdir -p "$REAL_UD"
printf '%s\n' "$SENTINEL_TOKEN" >"$SENTINEL_PATH"

if [[ -f "$SAVE_SENTINEL_PATH" ]]; then
	HAD_SAVE=1
	SAVE_BACKUP="$(mktemp)"
	cp -a "$SAVE_SENTINEL_PATH" "$SAVE_BACKUP"
else
	# Plant a fake save so a buggy smoke that deletes would be observable.
	printf '%s\n' '{"high_score":424242,"display_name":"RI-SMOKE-SENTINEL"}' >"$SAVE_SENTINEL_PATH"
	PLANTED_SAVE=1
fi

assert_sentinel_intact() {
	local ctx="$1"
	if [[ "$(cat "$SENTINEL_PATH")" != "$SENTINEL_TOKEN" ]]; then
		echo "FAIL ($ctx): sentinel file altered/deleted under real userdata." >&2
		exit 1
	fi
	if [[ ! -f "$SAVE_SENTINEL_PATH" ]]; then
		echo "FAIL ($ctx): real save_data.json deleted." >&2
		exit 1
	fi
	if [[ "$HAD_SAVE" -eq 1 ]]; then
		cmp -s "$SAVE_BACKUP" "$SAVE_SENTINEL_PATH" || {
			echo "FAIL ($ctx): real save_data.json changed." >&2
			exit 1
		}
	elif ! grep -q '424242\|RI-SMOKE-SENTINEL' "$SAVE_SENTINEL_PATH"; then
		echo "FAIL ($ctx): planted save sentinel content missing." >&2
		exit 1
	fi
}

run_negative_case() {
	local name="$1"
	local log="$2"
	shift 2
	echo "=== NEGATIVE: $name ==="
	ri_smoke_unset
	# Apply case-specific env after unset
	if [[ "$#" -gt 0 ]]; then
		export "$@"
	fi
	set +e
	godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m3_best_score_smoke.gd \
		2>&1 | tee "$log"
	local ec=${PIPESTATUS[0]}
	set -e
	if [[ "$ec" -eq 0 ]]; then
		echo "FAIL ($name): exited 0 (expected refuse)." >&2
		exit 1
	fi
	grep -q 'refuse' "$log" || {
		echo "FAIL ($name): expected refuse message." >&2
		exit 1
	}
	grep -q 'M3 best-score smoke PASS' "$log" && {
		echo "FAIL ($name): printed PASS." >&2
		exit 1
	}
	assert_sentinel_intact "$name"
	echo "NEGATIVE PASS ($name, exit=$ec, sentinel intact)"
}

run_negative_case "no isolation env" /tmp/m3-smoke-negative.log

run_negative_case "flag only without USER_DATA_DIR" /tmp/m3-smoke-negative-flag-only.log \
	RI_SMOKE_ISOLATED=1

# Flag + dir pointing at REAL userdata — must refuse (not a dedicated ri-smoke temp).
run_negative_case "flag+dir pointing at real userdata" /tmp/m3-smoke-negative-realdir.log \
	RI_SMOKE_ISOLATED=1 \
	RI_SMOKE_USER_DATA_DIR="$REAL_UD"

echo "=== POSITIVE: M3 smoke with dedicated ri-smoke userdata ==="
ri_smoke_env_setup
set +e
godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m3_best_score_smoke.gd \
	2>&1 | tee /tmp/m3-smoke-positive.log
POS_EC=${PIPESTATUS[0]}
set -e

if [[ "$POS_EC" -ne 0 ]]; then
	echo "FAIL: isolated M3 smoke exited $POS_EC" >&2
	exit 1
fi
grep -q 'userdata isolation OK' /tmp/m3-smoke-positive.log
grep -q 'M3 best-score smoke PASS' /tmp/m3-smoke-positive.log

# Real userdata sentinel must still be untouched after positive run.
if [[ "$(cat "$SENTINEL_PATH")" != "$SENTINEL_TOKEN" ]]; then
	echo "FAIL: sentinel altered during isolated positive run." >&2
	exit 1
fi

echo "POSITIVE PASS"
echo "M3 smoke save-safety check PASS"
