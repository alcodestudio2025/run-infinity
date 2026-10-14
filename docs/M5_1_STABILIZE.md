# M5.1.2-D Stabilize notes

Integration gate for the stacked M5.1.2 cycle (A controls → B content → C balance → D stabilize).

## Automated coverage

| Area | Smoke / CI step |
|------|-----------------|
| M1–M4.1 regressions | Existing smokes in `godot-ci.yml` |
| Grapple live + safety | `m5_1_grapple_live`, `m5_1_1_grapple_safety` |
| 30/60/120 Hz sim | `m5_1_grapple_fps_smoke` |
| Controls A | `m5_1_2_a_controls_smoke` |
| Content B | `m5_1_2_b_content_smoke` |
| Balance C | `m5_1_2_c_balance_smoke` |
| Stabilize D | `m5_1_2_d_stabilize_smoke` (landscape layouts, GO/restart, spawn, orphans) |
| CI exit integrity | `m5_1_1_ci_exit_control` (negative must fail; no `\|\| true`) |

## Device-only (not claimed by CI)

- Thumb reach / button comfort in landscape
- Latch readability at peak speed
- Perceived latency of JUMP→Grapple
- Battery / thermal / real multitouch hardware quirks
- Final APK install path

## APK policy

`android-apk.yml` does **not** trigger on `cursor/m5-1-2-*` branches. One FINAL APK only after ChatGPT/user authorization.
