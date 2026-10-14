# Grapple Design — Live Prototype (M5.1 → M5.1.2-D)

**Package:** `res://scripts/grapple/` + `LatchModule`  
**Engine:** Godot 4.7.2 · **Milestone:** M5.1.2-D (stabilize)

Wired into live gameplay via `PlayerGrappleDriver`. On-screen JUMP/SLIDE buttons are primary; swipe is dormant.

---

## 1. Gameplay contract

1. Ground JUMP → jump.
2. Airborne JUMP → Grapple request (not a second jump).
3. Valid latch ahead+above → attach + short swing + visible rope.
4. Auto-release → upward `velocity.y` + forward **world speed boost** (not body.vx).
5. No latch → empty miss cast VFX; jump arc continues unchanged.
6. Death / restart → full reset.
7. No manual aim; no indefinite hang; no multi-attach.

---

## 2. Live integration architecture

```
TouchControls JUMP (right) / SLIDE (left)
   + keyboard (swipe dormant via set_swipe_enabled(false))
        ↓
PlayerMovement._handle_jump_or_air_intent
   ├─ floor → jump
   ├─ walk-off coyote → jump
   └─ airborne → Grapple seek → attach OR miss cast VFX
        ↓
GrappleController + DeterministicGrappleSimulator (scroll_speed=0)
        ↓
TreeLatchProvider ← Tags.ANCHOR (LatchModule)
```

| Layer | Owner |
|-------|--------|
| On-screen buttons | `TouchControls` |
| Swipe (dormant) | `TouchGestureRouter.set_swipe_enabled` |
| Jump vs Grapple | `PlayerMovement` |
| Grapple host | `PlayerGrappleDriver` |
| Search params (live) | **`GrappleConfig`** |

Miss diagnosis: [`docs/GRAPPLE_MISS_DIAGNOSIS_M5_1_1.md`](GRAPPLE_MISS_DIAGNOSIS_M5_1_1.md).

---

## 3–8

See prior M5.1 / M5.1.1 sections in git history for FSM, search vs rope, scroll model, and safety notes.

**Teach / density (M5.1.2-B):** early latch indices **4, 5, 8, 10, 11, 14** plus periodic denser latch stride; exclusive slot classifier prevents latch+hazard stacks. Balance: [`docs/BALANCE_M5_1.md`](BALANCE_M5_1.md).

**Gate:** No intermediate APK on 5.1.2 branches. No M5.2 until M5.1 FINAL APK authorization after stacked PR review.
