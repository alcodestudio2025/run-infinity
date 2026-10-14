# Android export (MA-006 / M4 first playable)

Reproducible **debug APK** flow for Godot **4.7.2.stable**.  
Output: `build/android/RunInfinity-debug.apk` + `RunInfinity-debug.apk.sha256`.

## Identifiers (proposed — not store-approved)

| Field | Default | Override |
|-------|---------|----------|
| Package / applicationId | `com.alcodestudio.runinfinity` | `RI_ANDROID_PACKAGE` when running `export_debug_apk.sh`, or edit `export_presets.cfg` |
| versionName | `0.4.0-debug` | `version/name` in `export_presets.cfg` |
| versionCode | `4` | `version/code` in `export_presets.cfg` |
| Preset name | `Android` | must match CLI `--export-debug "Android"` |
| Orientation | Landscape | from `project.godot` (`window/handheld/orientation=1`) |
| Permissions | none extra (`internet=false`) | flip flags in `export_presets.cfg` only if required |

The package ID is a **proposed** reverse-DNS id for first-playable / sideload testing. It is **not** Google Play–approved and may change before any store submission.

## Prerequisites

| Tool | Notes |
|------|-------|
| Godot **4.7.2** Standard | Same major as `project.godot` (`4.7`); on PATH as `godot` |
| JDK | OpenJDK 17+ (21 OK for debug). `java` + `keytool` on PATH |
| Android SDK | Installed by `scripts/android/setup_android_sdk.sh` |
| Export templates | `4.7.2.stable` (auto-installed by `export_debug_apk.sh` if missing) |
| Debug keystore | Generated locally (`android` / `android`); **never** commit |

## Exact commands (from repo root)

```bash
# 1) Android SDK (default ANDROID_HOME=$HOME/android-sdk)
./scripts/android/setup_android_sdk.sh
export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# 2) Editor settings 4.7 + debug keystore
./scripts/android/configure_godot_android.sh
# Optional: eval the export lines printed at the end, or re-export manually:
#   export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$HOME/.android/debug.keystore"
#   export GODOT_ANDROID_KEYSTORE_DEBUG_USER=android
#   export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android

# 3) Headless debug export
./scripts/android/export_debug_apk.sh
```

Optional package override:

```bash
RI_ANDROID_PACKAGE=com.example.runinfinity.debug ./scripts/android/export_debug_apk.sh
```

Equivalent raw Godot invocation (after SDK + templates + keystore are configured):

```bash
godot --headless --path . --export-debug "Android" build/android/RunInfinity-debug.apk
sha256sum build/android/RunInfinity-debug.apk | tee build/android/RunInfinity-debug.apk.sha256
```

## What `setup_android_sdk.sh` installs

Under `$ANDROID_HOME` (default `$HOME/android-sdk`):

- cmdline-tools (`latest`)
- `platform-tools`
- `platforms;android-34`
- `build-tools;34.0.0`
- Licenses accepted non-interactively

NDK is **not** required for the default (non-Gradle) export path.  
Install NDK only if you enable Gradle builds: `RI_ANDROID_INSTALL_NDK=1 ./scripts/android/setup_android_sdk.sh`.

## What stays out of git

- `*.keystore` / release passwords / aliases (already gitignored)
- `build/android/*.apk` and `*.sha256` (build artifacts)
- Absolute machine paths for release secrets

`export_presets.cfg` **is** committed: it holds the reproducible Android debug preset with empty keystore fields. Debug signing uses Editor Settings / `GODOT_ANDROID_KEYSTORE_DEBUG_*` env vars.

## QA / verify

After export, Agent B’s verifier (when present):

```bash
./scripts/ci/m4_apk_verify.sh build/android/RunInfinity-debug.apk
```

Manual device steps: see `docs/android-manual-checklist.md` (Agent B).

## Cloud / CI notes

Cloud bootstrap (`scripts/cloud-agent-install.sh`) installs Godot for headless smokes only — not the full Android SDK.  
Use this doc’s scripts locally or in a dedicated Android export job that installs SDK + templates and uploads the APK artifact (no public Release, no keystore secrets in the workflow).
