#!/usr/bin/env bash
# Export Run Infinity debug APK with Godot 4.7.2 headless --export-debug.
# Ensures export templates, applies optional RI_ANDROID_PACKAGE override, writes SHA-256.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

## Headless smokes redirect XDG_DATA_HOME under /tmp/ri-smoke-* which breaks
## Godot's lookup of ~/.local/share/godot/export_templates. Clear that pollution.
if [[ "${XDG_DATA_HOME:-}" == *ri-smoke* ]]; then
  unset XDG_DATA_HOME
fi

GODOT_BIN="${GODOT_BIN:-godot}"
GODOT_VERSION_EXPECTED="${GODOT_VERSION_EXPECTED:-4.7.2.stable}"
TEMPLATE_VERSION="${TEMPLATE_VERSION:-4.7.2.stable}"
TEMPLATES_DIR="${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/.local/share/godot/export_templates}"
TEMPLATE_DIR="$TEMPLATES_DIR/$TEMPLATE_VERSION"
TPZ_URL="${GODOT_EXPORT_TEMPLATES_URL:-https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz}"

ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/android-sdk}}"
export ANDROID_HOME
export ANDROID_SDK_ROOT="$ANDROID_HOME"

PRESET_NAME="Android"
OUT_DIR="build/android"
OUT_APK="$OUT_DIR/RunInfinity-debug.apk"
OUT_SHA="$OUT_APK.sha256"
PRESET_FILE="export_presets.cfg"
DEFAULT_PACKAGE="com.alcodestudio.runinfinity"
PACKAGE_ID="${RI_ANDROID_PACKAGE:-$DEFAULT_PACKAGE}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

need_cmd "$GODOT_BIN"
need_cmd curl
need_cmd unzip
need_cmd sha256sum
need_cmd python3

if [[ ! -f "$ROOT/project.godot" ]]; then
  echo "ERROR: project.godot not found in $ROOT" >&2
  exit 1
fi
if [[ ! -f "$ROOT/$PRESET_FILE" ]]; then
  echo "ERROR: $PRESET_FILE missing — commit the Android export preset first" >&2
  exit 1
fi

ver="$("$GODOT_BIN" --version 2>/dev/null || true)"
echo "Godot: $ver"
if [[ "$ver" != 4.7* ]]; then
  echo "ERROR: expected Godot 4.7.x, got: $ver" >&2
  exit 1
fi

ensure_templates() {
  if [[ -f "$TEMPLATE_DIR/android_debug.apk" && -f "$TEMPLATE_DIR/version.txt" ]]; then
    local tv
    tv="$(tr -d '[:space:]' <"$TEMPLATE_DIR/version.txt" || true)"
    if [[ "$tv" == "$TEMPLATE_VERSION" ]]; then
      echo "Export templates OK: $TEMPLATE_DIR"
      return
    fi
  fi
  echo "Installing export templates $TEMPLATE_VERSION..."
  mkdir -p "$TEMPLATES_DIR"
  tmp_tpz="$(mktemp /tmp/godot-templates-XXXXXX.tpz)"
  extract="$(mktemp -d /tmp/godot-templates-extract-XXXXXX)"
  curl -fsSL -L -o "$tmp_tpz" "$TPZ_URL"
  unzip -qo "$tmp_tpz" -d "$extract"
  # tpz contains templates/ with version.txt + platform binaries
  rm -rf "$TEMPLATE_DIR"
  if [[ -d "$extract/templates" ]]; then
    mv "$extract/templates" "$TEMPLATE_DIR"
  else
    echo "ERROR: unexpected export templates archive layout" >&2
    exit 1
  fi
  echo "$TEMPLATE_VERSION" >"$TEMPLATE_DIR/version.txt"
  rm -rf "$tmp_tpz" "$extract"
  [[ -f "$TEMPLATE_DIR/android_debug.apk" ]] || {
    echo "ERROR: android_debug.apk missing after template install" >&2
    exit 1
  }
  echo "Export templates installed: $TEMPLATE_DIR"
}

ensure_templates

# Optional package override without permanently rewriting the committed preset
PRESET_BACKUP=""
restore_preset() {
  if [[ -n "${PRESET_BACKUP:-}" && -f "$PRESET_BACKUP" ]]; then
    mv -f "$PRESET_BACKUP" "$ROOT/$PRESET_FILE"
    PRESET_BACKUP=""
  fi
}
trap restore_preset EXIT

current_pkg="$(python3 - <<'PY'
from pathlib import Path
import re
text = Path("export_presets.cfg").read_text()
m = re.search(r'(?m)^package/unique_name="([^"]*)"', text)
print(m.group(1) if m else "")
PY
)"

if [[ "$PACKAGE_ID" != "$current_pkg" ]]; then
  echo "Applying RI_ANDROID_PACKAGE override: $PACKAGE_ID (was $current_pkg)"
  PRESET_BACKUP="$(mktemp /tmp/export_presets.backup.XXXXXX)"
  cp "$ROOT/$PRESET_FILE" "$PRESET_BACKUP"
  python3 - "$PACKAGE_ID" <<'PY'
import re, sys
from pathlib import Path
pkg = sys.argv[1]
path = Path("export_presets.cfg")
text = path.read_text()
text2, n = re.subn(r'(?m)^package/unique_name="[^"]*"', f'package/unique_name="{pkg}"', text, count=1)
if n != 1:
    raise SystemExit("failed to patch package/unique_name in export_presets.cfg")
path.write_text(text2)
PY
fi

# Ensure debug keystore env is set (configure_godot_android.sh is the primary writer)
if [[ -z "${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-}" ]]; then
  if [[ -f "$HOME/.android/debug.keystore" ]]; then
    export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$HOME/.android/debug.keystore"
  elif [[ -f "$HOME/.local/share/godot/keystores/debug.keystore" ]]; then
    export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$HOME/.local/share/godot/keystores/debug.keystore"
  fi
fi
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-androiddebugkey}"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-android}"

if [[ -z "${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-}" || ! -f "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" ]]; then
  echo "Debug keystore missing — running configure_godot_android.sh..."
  cfg_out="$(mktemp /tmp/ri-configure-godot-XXXXXX.log)"
  "$ROOT/scripts/android/configure_godot_android.sh" | tee "$cfg_out"
  # shellcheck disable=SC1091
  eval "$(grep -E '^export ' "$cfg_out" || true)"
  rm -f "$cfg_out"
fi
if [[ -z "${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-}" || ! -f "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" ]]; then
  echo "ERROR: debug keystore still missing after configure_godot_android.sh" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
rm -f "$OUT_APK" "$OUT_SHA"

echo "Exporting debug APK → $OUT_APK"
set +e
"$GODOT_BIN" --headless --path "$ROOT" --export-debug "$PRESET_NAME" "$OUT_APK"
export_rc=$?
set -e

if [[ "$export_rc" -ne 0 ]]; then
  echo "ERROR: godot --export-debug exited $export_rc" >&2
  exit "$export_rc"
fi

if [[ ! -f "$OUT_APK" ]]; then
  echo "ERROR: APK not produced at $OUT_APK" >&2
  exit 1
fi

size="$(wc -c <"$OUT_APK" | tr -d ' ')"
if [[ "$size" -lt 100000 ]]; then
  echo "ERROR: APK suspiciously small ($size bytes)" >&2
  exit 1
fi

# sha256sum -c compatible sidecar: "<hash>  <path>"
sha256sum "$OUT_APK" >"$OUT_SHA"

echo "export_debug_apk: OK"
echo "  apk=$OUT_APK"
echo "  size=$size"
echo "  sha256=$(awk '{print $1}' "$OUT_SHA")"
echo "  package=$PACKAGE_ID"
