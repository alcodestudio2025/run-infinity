#!/usr/bin/env bash
# Point Godot 4.7 Editor Settings at Android SDK + debug keystore.
# Generates a debug keystore (android/android) if missing. Never commits secrets.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/android-sdk}}"
export ANDROID_HOME
export ANDROID_SDK_ROOT="$ANDROID_HOME"

GODOT_CONFIG_DIR="${GODOT_CONFIG_DIR:-$HOME/.config/godot}"
EDITOR_SETTINGS="${EDITOR_SETTINGS:-$GODOT_CONFIG_DIR/editor_settings-4.7.tres}"

# Prefer standard Android debug keystore location; fall back to Godot's keystores dir.
DEBUG_KEYSTORE="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-${RI_ANDROID_DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}}"
DEBUG_USER="${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-android}"
DEBUG_PASS="${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-android}"

# Resolve JAVA_HOME for Godot export/android/java_sdk_path
resolve_java_home() {
  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    echo "$JAVA_HOME"
    return
  fi
  local java_bin
  java_bin="$(readlink -f "$(command -v java)")"
  # .../bin/java -> JDK root
  dirname "$(dirname "$java_bin")"
}

JAVA_SDK_PATH="$(resolve_java_home)"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

need_cmd keytool
need_cmd python3

if [[ ! -d "$ANDROID_HOME/platform-tools" ]]; then
  echo "WARN: ANDROID_HOME looks incomplete ($ANDROID_HOME). Run scripts/android/setup_android_sdk.sh first." >&2
fi

mkdir -p "$(dirname "$DEBUG_KEYSTORE")"
mkdir -p "$GODOT_CONFIG_DIR"

if [[ ! -f "$DEBUG_KEYSTORE" ]]; then
  echo "Generating debug keystore at $DEBUG_KEYSTORE (alias=$DEBUG_USER)..."
  keytool -genkeypair \
    -v \
    -keystore "$DEBUG_KEYSTORE" \
    -storepass "$DEBUG_PASS" \
    -keypass "$DEBUG_PASS" \
    -alias "$DEBUG_USER" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US"
else
  echo "Debug keystore already exists: $DEBUG_KEYSTORE"
fi

# Ensure editor settings file exists (Godot creates it on first run)
if [[ ! -f "$EDITOR_SETTINGS" ]]; then
  echo "Creating minimal $EDITOR_SETTINGS..."
  cat >"$EDITOR_SETTINGS" <<'EOF'
[gd_resource type="EditorSettings" format=3]

[resource]
EOF
fi

python3 - "$EDITOR_SETTINGS" "$ANDROID_HOME" "$JAVA_SDK_PATH" "$DEBUG_KEYSTORE" "$DEBUG_USER" "$DEBUG_PASS" <<'PY'
import re
import sys
from pathlib import Path

settings_path, android_home, java_home, keystore, user, password = sys.argv[1:7]
text = Path(settings_path).read_text()

updates = {
    "export/android/android_sdk_path": android_home,
    "export/android/java_sdk_path": java_home,
    "export/android/debug_keystore": keystore,
    "export/android/debug_keystore_user": user,
    "export/android/debug_keystore_pass": password,
}

def set_prop(src: str, key: str, value: str) -> str:
    line = f'{key} = "{value}"'
    pattern = re.compile(rf'(?m)^{re.escape(key)}\s*=\s*.*$')
    if pattern.search(src):
        return pattern.sub(line, src)
    # Insert under [resource] section
    if "[resource]" in src:
        return src.replace("[resource]", "[resource]\n" + line, 1)
    return src.rstrip() + "\n[resource]\n" + line + "\n"

for key, value in updates.items():
    text = set_prop(text, key, value)

Path(settings_path).write_text(text)
print(f"Updated {settings_path}")
for key, value in updates.items():
    # Do not echo password in CI logs beyond confirmation of key presence
    if key.endswith("_pass"):
        print(f"  {key}=***")
    else:
        print(f"  {key}={value}")
PY

# Also export env vars used by Godot during headless export (override preset blanks)
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DEBUG_KEYSTORE"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="$DEBUG_USER"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="$DEBUG_PASS"

cat <<EOF
configure_godot_android: OK
  EDITOR_SETTINGS=$EDITOR_SETTINGS
  ANDROID_HOME=$ANDROID_HOME
  JAVA_SDK_PATH=$JAVA_SDK_PATH
  DEBUG_KEYSTORE=$DEBUG_KEYSTORE
EOF

# Emit exports for eval/source callers
echo "export ANDROID_HOME=\"$ANDROID_HOME\""
echo "export ANDROID_SDK_ROOT=\"$ANDROID_HOME\""
echo "export JAVA_HOME=\"$JAVA_SDK_PATH\""
echo "export GODOT_ANDROID_KEYSTORE_DEBUG_PATH=\"$DEBUG_KEYSTORE\""
echo "export GODOT_ANDROID_KEYSTORE_DEBUG_USER=\"$DEBUG_USER\""
echo "export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=\"$DEBUG_PASS\""
