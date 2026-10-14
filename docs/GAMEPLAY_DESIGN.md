# Run Infinity — Gameplay Design Document

Living document for AL Code Studio. Update when mechanics are confirmed, deferred, or changed.

**Engine:** Godot 4.7.2 · **Target:** Android landscape · **Last updated:** M5.1.2-D

---

## 1. Gameplay currently implemented

- Endless auto-run to the right; player stays near a fixed screen X ratio.
- **Title / MAIN_MENU** with PLAY; run starts only from the menu (`start_game` guarded).
- **On-screen JUMP (right) / SLIDE (left)** primary touch; swipe dormant (re-armable).
- **Jump** (button / keyboard) with coyote time and jump buffer; faster fall (×1.55).
- **Slide** (button / keys) with temporary shorter hitbox and squash visual.
- **Grapple** (air JUMP near latch): attach → short swing → auto-release; miss cast VFX otherwise.
- Obstacles: low curb, tall, overhead; multi-lane coins; denser latches; modular spawn + difficulty.
- Progressive speed ease (340→620 over 9k distance); coin bonus 300.
- **Game Over** on obstacle hit; restart continues a new run.
- **Best score** persisted via `SaveManager` / `user://save_data.json`.
- Touch via buttons + `TouchGestureRouter` (swipe off); UI Controls consume PLAY.

## 2. Mechanics confirmed

| Mechanic | Status | Notes |
|----------|--------|-------|
| Auto-run + distance score | Confirmed | |
| Jump over low obstacles | Confirmed (playtest + smokes) | |
| Slide under overhead | Confirmed in physics smokes (M4.1); device clear still for playtest | Geometry clears ~12px while sliding |
| Swipe up / horizontal | Confirmed inactive | |
| Best score persist across kill/reopen | Confirmed on device (M4 playtest) | |
| Title → Play gate | Confirmed | |
| Debug Android APK install | Confirmed (M4) | |

## 3. Mechanics in prototype / approved future

### Grapple (M5.1 → M5.1.2 playable prototype)

**Live in game (prototype):**

1. Ground JUMP button → jump.
2. Airborne JUMP → Grapple request (not a second jump).
3. Valid latch ahead+above (`LatchModule` / `Tags.ANCHOR`) → attach + rope visual.
4. Short auto swing → auto-release → upward velocity + world speed burst (capped).
5. No latch → miss cast VFX; jump arc unchanged. Death/restart clears Grapple.

**Still future:** latch chains, multipliers, final art. Spec: [`docs/GRAPPLE_DESIGN.md`](GRAPPLE_DESIGN.md).  
Balance sheet: [`docs/BALANCE_M5_1.md`](BALANCE_M5_1.md). Miss diagnosis: [`docs/GRAPPLE_MISS_DIAGNOSIS_M5_1_1.md`](GRAPPLE_MISS_DIAGNOSIS_M5_1_1.md).

**Device note:** human Android playtest for buttons/Grapple feel awaits M5.1 FINAL APK authorization.

## 4. Experimental mechanics

None active in tree. Ideas only — not scheduled:

- Variable jump height / hold-to-jump
- Manual grappling aim
- Slide cancel into jump

## 5. Balancing parameters

Source of truth: `scripts/core/GameConfig.gd` + `PlayerConfig` exports.

| Parameter | Typical value | Role |
|-----------|---------------|------|
| `PLAYER_JUMP_VELOCITY` | 1050 | Jump impulse |
| `PLAYER_GRAVITY` | 1350 | Arc |
| `COYOTE_TIME` / `JUMP_BUFFER` | 0.26 / 0.24 s | Input forgiveness |
| `SLIDE_DURATION` | 0.45 s | Slide window |
| Standing hitbox | 48×72 @ (0,−4) | |
| Sliding hitbox | 64×38 @ (0,13) | Clears overhead |
| Touch swipe / tap slop | 6% / 2.5% of viewport height (min 48 / 24 px) | Classification |
| `EARLY_TAP_DWELL_SEC` | 0.048 s | M4.1 early jump commit |
| `PLAYER_FALL_GRAVITY_MULT` | 1.55 | Faster descent only |
| `BASE_WORLD_SPEED` → `MAX` | 340 → 620 | Ease ramp 9000 px, power 1.35 |
| `WORLD_ACCELERATION` | 220 | Perceptible chase |
| `COIN_SCORE_VALUE` | 300 | Teach sequence meaningful vs distance |
| Grapple search range | 480 px (`GrappleConfig`) | Live LatchSelector |
| Swing duration | 0.45 s | Auto-release window |
| Latch early segments | 4, 5, 8, 10, 11, 14 | Denser teach (M5.1.2-B) |
| `MAX_BOOST_WORLD_SPEED` | 900 | Grapple release scroll ceiling (vs max 620) |

## 6. Architectural decisions

1. **Intent vs movement:** `TouchGestureRouter` classifies gestures; `PlayerMovement` maps tap → jump or air ability. No Grapple logic in the router.
2. **M4.1 jump latency:** Early tap dwell (~48ms); early slide on swipe threshold; immediate jump apply when legal.
3. **M5.1 Grapple live:** `PlayerGrappleDriver` hosts controller+sim; forward release = world speed boost; live latch globals while scrolling; search params from `GrappleConfig`.
4. **M5.1.1 safety:** path-swept obstacle queries during swing; boost hard-cap; latch recycle abort; CI exit codes not masked.
5. **M5.1.2 controls:** on-screen JUMP/SLIDE; swipe off via `set_swipe_enabled(false)`; miss cast on empty air JUMP.
6. **M5.1.2 content/balance:** denser exclusive-slot spawn; configurable ease speed curve; see `BALANCE_M5_1.md`.
7. **Saves:** smokes use isolated XDG userdata; never write developer saves from CI.

## 7. Gameplay change log

| Milestone | Change |
|-----------|--------|
| M1 | Core loop: run, jump, death, restart |
| M2 | Modules, difficulty, overhead/tall variety |
| M3 | Best score persistence |
| M3.2–M3.3 | HUD best + title/PLAY flow |
| M3.4 | TouchGestureRouter tap/swipe |
| M4 | First Android debug APK |
| **M4.1** | Touch early-commit + immediate jump apply; slide overhead physics smoke; Grapple recorded as M5-approved design only; this GDD created |
| **M5.0** | Grapple architecture + deterministic simulator + docs/smokes; gameplay behavior unchanged; live integration deferred |
| **M5.1** | Live Grapple prototype: PlayerGrappleDriver, LatchModule teach sequence, rope placeholder, live/FPS smokes |
| **M5.1.1** | Grapple safety: path-swept collisions, boost cap, latch recycle abort, CI exit hardening |
| **M5.1.2-A** | On-screen JUMP/SLIDE buttons; swipe dormant; miss cast VFX; faster fall; coyote/air intent fix |
| **M5.1.2-B** | Denser hazards/latches; multi-lane coins; deterministic content smoke |
| **M5.1.2-C** | Perceptible speed ramp; difficulty tick; coin 300; balance sheet + smoke |
| **M5.1.2-D** | Stabilize: landscape layouts, GO/restart, full CI suite; no APK until FINAL auth |

---

*M5.1 cycle complete pending FINAL APK authorization. No M5.2 until then.*
