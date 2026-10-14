# Grapple Design — Live Prototype (M5.1)

**Package:** `res://scripts/grapple/` + `LatchModule`  
**Engine:** Godot 4.7.2 · **Milestone:** M5.1 (playable prototype)

Wired into live gameplay via `PlayerGrappleDriver`. Router still only classifies tap/swipe; player context chooses jump vs air ability.

---

## 1. Gameplay contract

1. Ground tap → jump.
2. New airborne tap → `request_air_ability()`.
3. Valid latch ahead+above → attach + short swing + visible rope.
4. Auto-release → upward `velocity.y` + forward **world speed boost** (not body.vx).
5. No latch → jump continues.
6. Death / restart → full reset.
7. No manual aim; no indefinite hang; no multi-attach.

---

## 2. Live integration architecture

```
TouchGestureRouter.jump_requested
        ↓
PlayerMovement._handle_jump_or_air_intent
   ├─ floor/coyote → jump
   └─ airborne → PlayerGrappleDriver.request_air_ability()
        ↓
GrappleController + DeterministicGrappleSimulator (scroll_speed=0)
        ↓
TreeLatchProvider ← Tags.ANCHOR (LatchModule)
        ↓
pose Y (+ small arc X) | release → WorldVelocityController.apply_speed_boost
```

| Layer | Owner |
|-------|--------|
| Gesture classify | `TouchGestureRouter` (unchanged) |
| Jump vs Grapple | `PlayerMovement` |
| Grapple host | `PlayerGrappleDriver` |
| Latch world objects | `LatchModule` on segments |
| Search params (live) | **`GrappleConfig`** |
| Standalone sim radii | `GrappleSimConfig` (mirrored max=480) |

---

## 3. State machine

`IDLE → SEEKING → ATTACHED → RELEASED → IDLE` (+ `reset()` anytime).  
Hard cap `MAX_ATTACH_DURATION_SEC=0.85`. Swing default `0.45s`.

---

## 4. Search vs rope length

| Concept | Source | Notes |
|---------|--------|-------|
| Live search | `GrappleConfig` ahead 24–420, above 360, **range 480** | LatchSelector |
| Standalone attach radius | `GrappleSimConfig.max_attach_radius=480` | Aligned with live |
| Rope length | Distance at attach | May be **shorter** than max search |

---

## 5. Scroll / release model

- **WorldScroller** owns horizontal world motion.
- Live sim `scroll_speed=0`; latch globals updated by scrolling segments.
- Swing pose uses **live latch world position** + sim rope offset.
- Release: `player.velocity.y = impulse.y`; `impulse.x` → `apply_speed_boost` (~0.35s).
- Constant-ω launch (not smoothstep′ at u=1). Pose sample `RELEASE_POSE_U=0.88`.

---

## 6. Latch spawn (deterministic)

Segments **4, 8, 11** force latch (teach sequence). Later: gap offset `stride==2`.  
Local pose: center X, `y=-220`. Visual: cyan/amber diamond. Group `Tags.ANCHOR` only while active.

---

## 7. Tests

| Smoke | Role |
|-------|------|
| `m5_0_grapple_*` | FSM + standalone sim |
| `m5_1_latch_module_smoke` | ANCHOR lifecycle |
| `m5_1_grapple_live_smoke` | Main/GameScene input path |
| `m5_1_grapple_fps_smoke` | 30/60/120 Hz tolerances |

---

## 8. Non-goals (still out)

Combo multipliers, Verlet rope, final art, ads/IAP. **M5.2+ only after ChatGPT review.**
