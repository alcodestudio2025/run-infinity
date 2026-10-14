# Android manual device checklist (M4)

**MANUAL ONLY — requires a physical device or emulator with `adb`.**  
This document is a human QA checklist. It does **not** claim an automated pass.  
Do not mark CI green based on this file alone. Automated APK checks live in `scripts/ci/m4_apk_verify.sh`.

## Prerequisites

| Item | Note |
|------|------|
| APK | `build/android/RunInfinity-debug.apk` (from Agent A / CI artifact) |
| Optional hash | `build/android/RunInfinity-debug.apk.sha256` — run `scripts/ci/m4_apk_verify.sh` first |
| Device | USB debugging on, or emulator running |
| Tools | `adb` from Android SDK `platform-tools` |

Package (default): `com.alcodestudio.runinfinity` — override with `RI_ANDROID_PACKAGE` if the export used a different id.

## Install + logcat

```bash
# Optional helper (install -r + filtered logcat):
scripts/android/adb_install_and_logcat.sh build/android/RunInfinity-debug.apk

# Or manual:
adb devices
adb install -r build/android/RunInfinity-debug.apk
adb logcat -c
adb logcat -s godot:V Godot:V *:S
# Launch the app from the device launcher, then reproduce steps below.
```

Stop logcat with Ctrl+C. Save a capture if filing a bug:

```bash
adb logcat -d -s godot:V Godot:V *:S > /tmp/ri-m4-logcat.txt
```

## Smartphone play checklist

Mark each row only after observing it on device. Leave unchecked if not tested.

| # | Step | Expected | Pass? |
|---|------|----------|-------|
| 1 | Cold launch | App opens in **landscape**; Title / main menu visible (PLAY), not mid-run | ☐ |
| 2 | Title → Play | Tap/press **PLAY**; run starts (world scrolls, score ticks) | ☐ |
| 3 | Jump | Swipe up / jump input; player clears a low obstacle | ☐ |
| 4 | Slide | Swipe down / slide input; player ducks under an overhead hazard | ☐ |
| 5 | Collisions | Hitting an uncleared obstacle ends the run (Game Over) | ☐ |
| 6 | Game Over | Game Over UI shows with score; controls stop advancing the run | ☐ |
| 7 | Restart | Restart / Play again returns to a fresh run (or Title → Play per UI) | ☐ |
| 8 | Best persist | Beat a score, note **BEST**; finish run; BEST on HUD/menu matches | ☐ |
| 9 | Kill / reopen | Force-stop app (`adb shell am force-stop <package>`), relaunch; BEST still present | ☐ |

Force-stop + relaunch helper:

```bash
PKG="${RI_ANDROID_PACKAGE:-com.alcodestudio.runinfinity}"
adb shell am force-stop "$PKG"
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
```

## M4.1 second playtest (input + slide)

Use a fresh CI APK from the M4.1 PR after installing. Compare feel to M4.

| # | Step | Expected | Pass? |
|---|------|----------|-------|
| A | Rapid tap jump | Jump feels snappier than M4; clears low curb | ☐ |
| B | Still-press jump | Brief still press (no swipe) still jumps once | ☐ |
| C | Swipe down → slide | Squash visual + clears **overhead** without dying | ☐ |
| D | Swipe down never jumps | Clear downward swipes do not launch the player | ☐ |
| E | Swipe up / sideways | No jump, no slide | ☐ |
| F | Tap then immediate swipe | No double action; no stuck slide/jump | ☐ |
| G | Game Over + restart | Gestures idle on GO; restart accepts fresh taps | ☐ |
| H | Best persist | Still correct after force-stop (regression) | ☐ |

**Do not claim latency PASS in CI** — only after this human device pass.  
**M4.1 is technically approved but second physical playtest may still be pending.**

## M5.1 / M5.1.1 Grapple playtest

Use CI APK from the M5.1.1 PR (stacked on M5.1). Teach latches spawn on early segments (cyan/amber diamonds).

| # | Step | Expected | Pass? |
|---|------|----------|-------|
| G1 | Ground tap | Jump only | ☐ |
| G2 | Second tap in air near latch | Attach + visible rope | ☐ |
| G3 | Oscillation | Brief readable swing | ☐ |
| G4 | Auto-release | One release + forward speed burst / upward pop | ☐ |
| G5 | No latch air tap | No attach; jump arc continues | ☐ |
| G6 | Swipe down | Slide, never Grapple | ☐ |
| G7 | Hit obstacle while swinging | Game Over; restart clean (no tunnel) | ☐ |
| G8 | Restart then Grapple again | No stuck rope/state | ☐ |
| G9 | Release boost feel | Fast forward burst, not runaway speed | ☐ |
| G10 | Latch scrolls off / recycled mid-swing | Grapple ends cleanly; no stuck rope | ☐ |

**Do not claim Grapple feel PASS without this human pass.**  
**No smartphone playtest is claimed by CI for M5.1.1.**

## Out of scope for this checklist

- Release signing / Play Store upload
- Performance profiling / battery
- Automated UI tests (Espresso / Maestro)
- Grapple chains / multipliers (M5.2+)

## Sign-off (human)

| Field | Value |
|-------|-------|
| Tester | |
| Device / OS | |
| APK SHA-256 | |
| Date | |
| Result | PASS / FAIL / PARTIAL — **manual only** |
| Notes | |
