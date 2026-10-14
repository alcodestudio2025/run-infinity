# Run Infinity — Gameplay Design Document

Living document for AL Code Studio. Update when mechanics are confirmed, deferred, or changed.

**Engine:** Godot 4.7.2 · **Target:** Android landscape · **Last updated:** M5.1.2-A

---

## 1. Gameplay currently implemented

- Endless auto-run to the right; player stays near a fixed screen X ratio.
- **Title / MAIN_MENU** with PLAY; run starts only from the menu (`start_game` guarded).
- **Jump** (tap / keyboard) with coyote time and jump buffer.
- **Slide** (swipe down / keys) with temporary shorter hitbox and squash visual.
- Obstacles: low curb, tall, overhead; coins; modular segment spawning with difficulty scaling.
- **Game Over** on obstacle hit; restart continues a new run.
- **Best score** persisted via `SaveManager` / `user://save_data.json`.
- Touch via `TouchGestureRouter` (primary finger / mouse); UI Controls consume PLAY.

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

### Grapple (M5.1 playable prototype)

**Live in game (prototype):**

1. First tap on ground → jump.
2. Second tap while airborne → Grapple request (not a second jump).
3. Valid latch ahead+above (`LatchModule` / `Tags.ANCHOR`) → attach + rope visual.
4. Short auto swing → auto-release → upward velocity + world speed burst.
5. Miss → jump continues. Death/restart clears Grapple.

**Still future:** latch chains, multipliers, final art. Spec: [`docs/GRAPPLE_DESIGN.md`](GRAPPLE_DESIGN.md).

**M4.1 note:** second physical playtest for touch latency still pending — not device-validated here.

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
| Grapple search range | 480 px (`GrappleConfig`) | Live LatchSelector |
| Swing duration | 0.45 s | Auto-release window |
| Latch early segments | 4, 8, 11 | Teach sequence |
| `MAX_BOOST_WORLD_SPEED` | 900 | Grapple release scroll ceiling (vs max 580) |

## 6. Architectural decisions

1. **Intent vs movement:** `TouchGestureRouter` classifies gestures; `PlayerMovement` maps tap → jump or air ability. No Grapple logic in the router.
2. **M4.1 jump latency:** Early tap dwell (~48ms); early slide on swipe threshold; immediate jump apply when legal.
3. **M5.1 Grapple live:** `PlayerGrappleDriver` hosts controller+sim; forward release = world speed boost; live latch globals while scrolling; search params from `GrappleConfig`.
4. **M5.1.1 safety:** path-swept obstacle queries during swing; boost hard-cap; latch recycle abort; CI exit codes not masked.
5. **Saves:** smokes use isolated XDG userdata; never write developer saves from CI.

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

---

*M5.1 cycle continues through B/C/D content/balance/stabilize. No M5.2 until FINAL APK authorization.*
