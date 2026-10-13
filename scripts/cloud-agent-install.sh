#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap: Godot 4.7.x Standard (GDScript) on PATH.
# Safe to re-run. Does not install Android SDK, export templates, or keystores.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2-stable}"
INSTALL_DIR="${GODOT_INSTALL_DIR:-/opt/godot}"
BIN_LINK="/usr/local/bin/godot"

need_install=1
if command -v godot >/dev/null 2>&1; then
  ver="$(godot --version 2>/dev/null || true)"
  if [[ "$ver" == 4.7* ]]; then
    echo "Godot already on PATH: $ver"
    need_install=0
  fi
fi

if [[ "$need_install" -eq 1 ]]; then
  echo "Installing Godot ${GODOT_VERSION} (Standard linux.x86_64)..."
  sudo mkdir -p "$INSTALL_DIR"
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    unzip curl ca-certificates \
    libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1 libfontconfig1 \
    libdbus-1-3
  # ALSA package name varies by Ubuntu release
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libasound2t64 2>/dev/null \
    || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libasound2 2>/dev/null \
    || true

  url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  tmp_zip="$(mktemp /tmp/godot-XXXXXX.zip)"
  extract="$(mktemp -d /tmp/godot-extract-XXXXXX)"
  curl -fsSL -L -o "$tmp_zip" "$url"
  unzip -qo "$tmp_zip" -d "$extract"
  bin="$(find "$extract" -type f -name 'Godot_v*_linux.x86_64' | head -1)"
  if [[ -z "$bin" ]]; then
    echo "ERROR: Godot binary not found in archive" >&2
    exit 1
  fi
  sudo install -m 755 "$bin" "$INSTALL_DIR/godot"
  sudo ln -sfn "$INSTALL_DIR/godot" "$BIN_LINK"
  rm -rf "$tmp_zip" "$extract"
  echo "Installed: $(godot --version)"
fi

# Optional: reimport project cache when checked out (non-fatal if display libs missing mid-CI)
if [[ -f "${PWD}/project.godot" ]]; then
  echo "Importing Godot project at ${PWD}..."
  godot --headless --path "$PWD" --import --quit
fi

echo "cloud-agent-install: OK"
