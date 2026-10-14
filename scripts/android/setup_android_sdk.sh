#!/usr/bin/env bash
# Install Android SDK cmdline-tools + packages needed for Godot 4.7.x debug APK export.
# Idempotent. Does not install Godot or export templates (see export_debug_apk.sh).
set -euo pipefail

ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/android-sdk}}"
export ANDROID_HOME
export ANDROID_SDK_ROOT="$ANDROID_HOME"

CMDLINE_TOOLS_VERSION="${CMDLINE_TOOLS_VERSION:-11076708}"
# Packages required for Godot Android export without Gradle custom builds.
# NDK is optional here (Gradle builds only); install if RI_ANDROID_INSTALL_NDK=1.
SDK_PACKAGES=(
  "platform-tools"
  "platforms;android-34"
  "build-tools;34.0.0"
)
if [[ "${RI_ANDROID_INSTALL_NDK:-0}" == "1" ]]; then
  SDK_PACKAGES+=("ndk;26.1.10909125")
fi

echo "ANDROID_HOME=$ANDROID_HOME"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

need_cmd curl
need_cmd unzip
need_cmd java

mkdir -p "$ANDROID_HOME/cmdline-tools"

SDKMANAGER=""
if [[ -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
  SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
elif [[ -x "$ANDROID_HOME/cmdline-tools/bin/sdkmanager" ]]; then
  SDKMANAGER="$ANDROID_HOME/cmdline-tools/bin/sdkmanager"
fi

if [[ -z "$SDKMANAGER" ]]; then
  echo "Installing Android cmdline-tools (${CMDLINE_TOOLS_VERSION})..."
  tmp_zip="$(mktemp /tmp/android-cmdline-tools-XXXXXX.zip)"
  url="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
  curl -fsSL -L -o "$tmp_zip" "$url"
  extract="$(mktemp -d /tmp/android-cmdline-extract-XXXXXX)"
  unzip -qo "$tmp_zip" -d "$extract"
  # Zip contains a top-level "cmdline-tools/" directory; Godot expects .../cmdline-tools/latest/
  rm -rf "$ANDROID_HOME/cmdline-tools/latest"
  mkdir -p "$ANDROID_HOME/cmdline-tools/latest"
  if [[ -d "$extract/cmdline-tools" ]]; then
    # Move contents of cmdline-tools into latest/
    shopt -s dotglob
    mv "$extract/cmdline-tools"/* "$ANDROID_HOME/cmdline-tools/latest/"
    shopt -u dotglob
  else
    echo "ERROR: unexpected cmdline-tools archive layout" >&2
    exit 1
  fi
  rm -rf "$tmp_zip" "$extract"
  SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
fi

if [[ ! -x "$SDKMANAGER" ]]; then
  echo "ERROR: sdkmanager not found at $SDKMANAGER" >&2
  exit 1
fi

echo "Using sdkmanager: $SDKMANAGER"

# Accept licenses non-interactively
yes | "$SDKMANAGER" --sdk_root="$ANDROID_HOME" --licenses >/tmp/android-sdk-licenses.log 2>&1 || true

echo "Installing SDK packages: ${SDK_PACKAGES[*]}"
"$SDKMANAGER" --sdk_root="$ANDROID_HOME" --install "${SDK_PACKAGES[@]}"

# Verify expected binaries
ADB="$ANDROID_HOME/platform-tools/adb"
AAPT2="$ANDROID_HOME/build-tools/34.0.0/aapt2"
PLATFORM="$ANDROID_HOME/platforms/android-34/android.jar"

[[ -x "$ADB" ]] || { echo "ERROR: adb missing after install: $ADB" >&2; exit 1; }
[[ -x "$AAPT2" ]] || { echo "ERROR: aapt2 missing after install: $AAPT2" >&2; exit 1; }
[[ -f "$PLATFORM" ]] || { echo "ERROR: android-34 platform missing: $PLATFORM" >&2; exit 1; }

cat <<EOF
setup_android_sdk: OK
  ANDROID_HOME=$ANDROID_HOME
  adb=$ADB
  aapt2=$AAPT2
  platform=$PLATFORM
EOF

# Hint for shells that did not export ANDROID_HOME yet
echo "export ANDROID_HOME=\"$ANDROID_HOME\""
echo "export ANDROID_SDK_ROOT=\"$ANDROID_HOME\""
echo "export PATH=\"\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH\""
