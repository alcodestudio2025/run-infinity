# Grapple miss diagnosis — M5.1.1 → M5.1.2-A

**Context:** Device / playtest reports of “Grapple not activating” on M5.1.1.  
**No smartphone playtest was claimed as PASS for M5.1.1.** This document captures engineering root causes and M5.1.2-A mitigations.

## Observed symptom

Player taps / presses JUMP in air near a teach latch and nothing visible happens; jump arc continues.

## Root causes (ranked)

1. **Silent seek miss**  
   Air ability always begins `SEEKING` when legal. With no latch in range, `seek_failed` fired within `SEEK_TIMEOUT_SEC` (0.08s) and **cleared with no VFX**. Feels identical to “input ignored.”

2. **Coyote stealing air intent**  
   `_handle_jump_or_air_intent` preferred `_can_jump()` (floor **or** coyote 0.26s). After walking off a ledge, JUMP was a second ground jump, not Grapple.

3. **Gesture ambiguity (pre-buttons)**  
   Full-screen tap/swipe classification: mid-zone → none; swipe → slide never Grapple; primary finger only. Easy to mis-fire on device.

4. **Latch range / teach pacing**  
   Valid latch must be ahead+above within `GrappleConfig` (range 480). Early latches at segments 4/8/11 — before that, air JUMP correctly misses.

5. **Gates**  
   Not PLAYING / dead / already grappling → `can_request_air_ability` false.

## M5.1.2-A corrections

| Fix | Change |
|-----|--------|
| Feedback | Empty cast Line2D + `EventBus.player_grapple_missed` on `seek_failed` (trajectory unchanged) |
| Intent | Floor → jump; walk-off coyote only when falling; mid-jump air → Grapple/miss |
| Input | LEFT SLIDE / RIGHT JUMP buttons; swipe disabled (`set_swipe_enabled(false)`), API kept |
| Feel | `PLAYER_FALL_GRAVITY_MULT=1.55` for faster descent |

## Still device-only

Button hit-box comfort, thumb reach in landscape, latch readability at speed — require a human Android pass after M5.1 FINAL APK authorization.
