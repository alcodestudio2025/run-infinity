# Run Infinity — Gameplay Design Document

Living document for AL Code Studio. Update when mechanics are confirmed, deferred, or changed.

**Engine:** Godot 4.7.2 · **Target:** Android landscape · **Last updated:** M4.1

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

## 3. Mechanics approved for future (not implemented)

### Grapple (M5 design-approved)

Approved for **M5 design**, **not implemented** in M4.1:

1. First tap on ground → jump.
2. Second tap while airborne → Grapple **request**.
3. Automatic search for a valid latch ahead and above the player.
4. Attach + short swing.
5. Automatic release with forward boost.
6. Future: chain latches + multipliers (later than first Grapple ship).

See architecture notes in §6 and Agent C review (`internal/m4-1-agent-c-grapple-arch-review.md` in the project agent store).

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

## 6. Architectural decisions

1. **Intent vs movement:** `TouchGestureRouter` classifies gestures and emits intents; `PlayerMovement` applies physics. No rope/ability logic in the router.
2. **M4.1 jump latency:** Early tap dwell (~48ms) while within tap slop; early slide when drag crosses swipe threshold; immediate `_perform_jump()` when legal on touch jump. **Rejected:** irrevocable jump on press (would break swipe-down).
3. **M5 Grapple (planned):** add explicit air-ability intent + thin `PlayerAbilities`/Grapple runtime; keep `PlayerState` small; latch data on world modules. Do not build a generic ability framework in M4.1.
4. **Saves:** smokes use isolated XDG userdata; never write developer saves from CI.

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

---

*Do not start M5 implementation until ChatGPT review of M4.1.*
