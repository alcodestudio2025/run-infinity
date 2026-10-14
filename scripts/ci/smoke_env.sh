#!/usr/bin/env bash
# Shared isolation env for Run Infinity headless smokes.
# Usage:
#   source scripts/ci/smoke_env.sh
#   ri_smoke_env_setup            # creates /tmp/ri-smoke-*/xdg and exports vars
#   ri_smoke_run godot ...        # optional helper
#
# On Linux, XDG_DATA_HOME redirects Godot user://. Windows is NOT assumed isolated:
# smokes call SmokeUserdataGuard and abort unless OS.get_user_data_dir() exactly
# matches RI_SMOKE_USER_DATA_DIR under a dedicated ri-smoke temp path.

ri_smoke_env_setup() {
	local root="${RI_SMOKE_ROOT:-}"
	if [[ -z "$root" ]]; then
		root="/tmp/ri-smoke-${GITHUB_RUN_ID:-local}-$$"
	fi
	# Require path marker for Guard._is_dedicated_smoke_temp
	if [[ "$root" != *ri-smoke* ]]; then
		echo "ri_smoke_env_setup: RI_SMOKE_ROOT must contain 'ri-smoke' (got: $root)" >&2
		return 1
	fi

	export RI_SMOKE_ROOT="$root"
	export XDG_DATA_HOME="$root/xdg"
	rm -rf "$XDG_DATA_HOME"
	mkdir -p "$XDG_DATA_HOME"

	# Verified on Godot 4.7 Linux: user_data_dir = $XDG_DATA_HOME/godot/app_userdata/<ProjectName>
	export RI_SMOKE_USER_DATA_DIR="$XDG_DATA_HOME/godot/app_userdata/RunInfinity"
	export RI_SMOKE_ISOLATED=1

	mkdir -p "$RI_SMOKE_USER_DATA_DIR"
	echo "ri_smoke_env_setup: ROOT=$RI_SMOKE_ROOT"
	echo "ri_smoke_env_setup: USER_DATA_DIR=$RI_SMOKE_USER_DATA_DIR"
}

ri_smoke_unset() {
	unset RI_SMOKE_ISOLATED RI_SMOKE_USER_DATA_DIR XDG_DATA_HOME RI_SMOKE_ROOT || true
}
