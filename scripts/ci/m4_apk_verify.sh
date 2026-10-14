#!/usr/bin/env bash
# M4 APK automated verify (existence, size, zip integrity, optional sha256 + aapt).
# Usage:
#   scripts/ci/m4_apk_verify.sh [path/to.apk]
# Default APK: build/android/RunInfinity-debug.apk
#
# Env:
#   RI_ANDROID_PACKAGE  expected package (default: com.alcodestudio.runinfinity)
#   ANDROID_HOME / ANDROID_SDK_ROOT  used to locate aapt/aapt2 under build-tools
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

APK_PATH="${1:-build/android/RunInfinity-debug.apk}"
EXPECTED_PACKAGE="${RI_ANDROID_PACKAGE:-com.alcodestudio.runinfinity}"
MIN_BYTES=102400

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

info() {
	echo "OK: $*"
}

# --- existence + size ---
if [[ ! -f "$APK_PATH" ]]; then
	fail "APK missing: $APK_PATH"
fi

SIZE="$(wc -c <"$APK_PATH" | tr -d ' ')"
if [[ "$SIZE" -lt "$MIN_BYTES" ]]; then
	fail "APK too small (${SIZE} bytes < ${MIN_BYTES}): $APK_PATH"
fi
info "APK present (${SIZE} bytes): $APK_PATH"

# --- zip integrity ---
command -v unzip >/dev/null 2>&1 || fail "unzip not found (required for integrity check)"
if ! unzip -t "$APK_PATH" >/tmp/m4-apk-unzip-t.log 2>&1; then
	echo "----- unzip -t output -----" >&2
	cat /tmp/m4-apk-unzip-t.log >&2 || true
	fail "unzip -t integrity check failed for $APK_PATH"
fi
info "zip integrity (unzip -t) passed"

# --- optional .sha256 sidecar ---
SHA_SIDE="${APK_PATH}.sha256"
if [[ -f "$SHA_SIDE" ]]; then
	command -v sha256sum >/dev/null 2>&1 || fail "sha256sum not found (required when sidecar present)"
	ACTUAL="$(sha256sum "$APK_PATH" | awk '{print $1}')"
	# Sidecar may be "HASH", "HASH  filename", or "HASH *filename"
	EXPECTED_HASH="$(awk '{print $1}' "$SHA_SIDE" | head -n1 | tr -d '[:space:]')"
	if [[ -z "$EXPECTED_HASH" ]]; then
		fail "empty hash in sidecar: $SHA_SIDE"
	fi
	if [[ "${#EXPECTED_HASH}" -ne 64 ]]; then
		fail "sidecar hash length ${#EXPECTED_HASH} (expected 64 hex chars): $SHA_SIDE"
	fi
	if [[ "$ACTUAL" != "$EXPECTED_HASH" ]]; then
		fail "SHA-256 mismatch: actual=$ACTUAL expected=$EXPECTED_HASH (sidecar $SHA_SIDE)"
	fi
	info "SHA-256 matches sidecar ($SHA_SIDE)"
else
	info "no .sha256 sidecar; skipped hash check"
fi

# --- optional aapt / aapt2 manifest checks ---
find_aapt() {
	local candidate=""
	local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
	if command -v aapt2 >/dev/null 2>&1; then
		echo "aapt2"
		return 0
	fi
	if command -v aapt >/dev/null 2>&1; then
		echo "aapt"
		return 0
	fi
	if [[ -n "$sdk" && -d "$sdk/build-tools" ]]; then
		# Prefer newest build-tools version that has aapt2 or aapt
		while IFS= read -r dir; do
			if [[ -x "$dir/aapt2" ]]; then
				echo "$dir/aapt2"
				return 0
			fi
			if [[ -x "$dir/aapt" ]]; then
				echo "$dir/aapt"
				return 0
			fi
		done < <(find "$sdk/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V -r)
	fi
	return 1
}

dump_badging() {
	local tool="$1"
	local apk="$2"
	case "$(basename "$tool")" in
	aapt2)
		# aapt2 dump badging works like aapt on recent build-tools
		"$tool" dump badging "$apk" 2>/dev/null || "$tool" dump --values badging "$apk"
		;;
	*)
		"$tool" dump badging "$apk"
		;;
	esac
}

if AAPT_BIN="$(find_aapt)"; then
	info "using aapt tool: $AAPT_BIN"
	BADGING="$(dump_badging "$AAPT_BIN" "$APK_PATH" 2>/tmp/m4-apk-aapt.err)" || {
		cat /tmp/m4-apk-aapt.err >&2 || true
		fail "aapt dump badging failed for $APK_PATH"
	}
	printf '%s\n' "$BADGING" > /tmp/m4-apk-badging.txt

	PKG_LINE="$(printf '%s\n' "$BADGING" | grep -E "^package:" | head -n1 || true)"
	[[ -n "$PKG_LINE" ]] || fail "no package: line in aapt badging"

	PKG_NAME="$(printf '%s\n' "$PKG_LINE" | sed -n "s/.*name='\([^']*\)'.*/\1/p")"
	VERSION_CODE="$(printf '%s\n' "$PKG_LINE" | sed -n "s/.*versionCode='\([^']*\)'.*/\1/p")"
	VERSION_NAME="$(printf '%s\n' "$PKG_LINE" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")"

	echo "  package=$PKG_NAME versionCode=$VERSION_CODE versionName=$VERSION_NAME"

	[[ -n "$PKG_NAME" ]] || fail "could not parse package name from badging"
	[[ "$PKG_NAME" == "$EXPECTED_PACKAGE" ]] || fail "package mismatch: got '$PKG_NAME' expected '$EXPECTED_PACKAGE'"

	[[ -n "$VERSION_CODE" ]] || fail "could not parse versionCode from badging"
	[[ -n "$VERSION_NAME" ]] || fail "could not parse versionName from badging"
	info "package/versionCode/versionName OK"

	# Landscape / screenOrientation: prefer badging screens line; also scan binary XML via aapt dump xmltree if present
	ORIENT_OK=0
	if printf '%s\n' "$BADGING" | grep -qiE "landscape|screenOrientation[^ ]*landscape|orientations?:.*landscape"; then
		ORIENT_OK=1
	fi

	# dump xmltree AndroidManifest.xml for android:screenOrientation
	MANIFEST_DUMP=""
	if [[ "$(basename "$AAPT_BIN")" == "aapt2" ]]; then
		MANIFEST_DUMP="$("$AAPT_BIN" dump xmltree "$APK_PATH" --file AndroidManifest.xml 2>/dev/null || true)"
	else
		MANIFEST_DUMP="$("$AAPT_BIN" dump xmltree "$APK_PATH" AndroidManifest.xml 2>/dev/null || true)"
	fi
	if [[ -n "$MANIFEST_DUMP" ]]; then
		printf '%s\n' "$MANIFEST_DUMP" > /tmp/m4-apk-manifest-xmltree.txt
		if printf '%s\n' "$MANIFEST_DUMP" | grep -qiE "screenOrientation.*landscape|A: android:screenOrientation\(.*\)=.*\(0x0\)|SCREEN_ORIENTATION_LANDSCAPE|landscape"; then
			ORIENT_OK=1
		fi
		# Numeric: SCREEN_ORIENTATION_LANDSCAPE = 0, SENSOR_LANDSCAPE = 6, USER_LANDSCAPE = 11, REVERSE_LANDSCAPE = 8
		if printf '%s\n' "$MANIFEST_DUMP" | grep -qiE 'screenOrientation[^0-9]*\(0x0\)|screenOrientation[^0-9]*=0([^0-9]|$)|=0x0\b|=6([^0-9]|$)|=\(0x6\)|=11([^0-9]|$)|=\(0xb\)|=8([^0-9]|$)|=\(0x8\)'; then
			ORIENT_OK=1
		fi
	fi

	# Godot often sets orientation via godot project; still require an explicit landscape signal in badging or manifest
	if [[ "$ORIENT_OK" -ne 1 ]]; then
		# Fallback: search raw APK strings (best-effort) for landscape token in binary resources
		if unzip -p "$APK_PATH" AndroidManifest.xml 2>/dev/null | strings 2>/dev/null | grep -qi landscape; then
			ORIENT_OK=1
		fi
	fi

	if [[ "$ORIENT_OK" -ne 1 ]]; then
		echo "----- badging (package/screens) -----" >&2
		printf '%s\n' "$BADGING" | grep -iE "package:|screen|orient|native-code" >&2 || true
		fail "landscape / screenOrientation not found in manifest/badging (expected landscape)"
	fi
	info "landscape / screenOrientation check OK"
else
	info "aapt/aapt2 not found (ANDROID_HOME unset or no build-tools); skipped package/orientation checks"
fi

echo "M4 APK verify PASS"
