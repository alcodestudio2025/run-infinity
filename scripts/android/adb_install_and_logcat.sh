#!/usr/bin/env bash
# Manual helper: adb install -r + filtered Godot logcat.
# Requires a connected device/emulator. Not used by automated CI.
#
# Usage:
#   scripts/android/adb_install_and_logcat.sh [path/to.apk]
# Default APK: build/android/RunInfinity-debug.apk
#
# Env:
#   RI_ANDROID_PACKAGE  package for optional force-stop before install (default: com.alcodestudio.runinfinity)
#   RI_ADB_LOGCAT_SEC   if set to a positive integer, run logcat that many seconds then exit
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

APK_PATH="${1:-build/android/RunInfinity-debug.apk}"
PKG="${RI_ANDROID_PACKAGE:-com.alcodestudio.runinfinity}"

if ! command -v adb >/dev/null 2>&1; then
	echo "FAIL: adb not found on PATH (install Android SDK platform-tools)." >&2
	exit 1
fi

if [[ ! -f "$APK_PATH" ]]; then
	echo "FAIL: APK missing: $APK_PATH" >&2
	exit 1
fi

echo "=== adb devices ==="
adb devices

echo "=== force-stop $PKG (ignore errors if not installed) ==="
adb shell am force-stop "$PKG" 2>/dev/null || true

echo "=== adb install -r $APK_PATH ==="
adb install -r "$APK_PATH"

echo "=== clear logcat ==="
adb logcat -c

echo "=== launching $PKG (monkey) ==="
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || {
	echo "WARN: monkey launch failed; open the app manually from the launcher." >&2
}

echo "=== logcat filter: godot:V Godot:V *:S ==="
echo "(Ctrl+C to stop; this is MANUAL device QA — not an automated pass)"

if [[ -n "${RI_ADB_LOGCAT_SEC:-}" ]] && [[ "$RI_ADB_LOGCAT_SEC" =~ ^[1-9][0-9]*$ ]]; then
	timeout "${RI_ADB_LOGCAT_SEC}s" adb logcat -s godot:V Godot:V *:S || true
else
	adb logcat -s godot:V Godot:V *:S
fi
