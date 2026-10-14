# Grapple Design — M5.0 Architecture

Standalone ability component for Run Infinity. **Not wired** into `Main` / `GameScene` / `PlayerMovement` in this milestone.

**Package:** `res://scripts/grapple/`  
**Owners:** Agent A (controller / latch / FSM), Agent B (deterministic `GrappleSimulator` motion math)

---

## 1. Goals

1. Air-ability **request** API independent of jump/slide classification.
2. Latch search ahead + above the player; reject behind / out of range.
3. Clear FSM: `IDLE → SEEKING → ATTACHED → RELEASED → IDLE`.
4. Attach → oscillation (via simulator) → **auto-release** (no indefinite hang).
5. `reset()` on death / restart.
6. Usable from headless tests without attaching to the player scene.

Non-goals (M5.0): rope IK/Verlet art, combo multipliers, generic ability plugin registry, live Main wiring, touch router changes.

---

## 2. Layering

| Layer | Role | Lives in |
|-------|------|----------|
| Input intents | Tap/swipe → jump / slide / **air ability** | Future host (`TouchGestureRouter` or façade) — **not modified here** |
| GrappleController | Policy FSM, seek, attach, auto-release, reset | `scripts/grapple/GrappleController.gd` |
| LatchProvider / LatchSelector | Candidate supply + filter/rank | `LatchProvider.gd`, `ArrayLatchProvider.gd`, `LatchSelector.gd` |
| GrappleSimulator | Deterministic swing step/query | Interface `GrappleSimulator.gd`; stub `NullGrappleSimulator.gd` |
| Player locomotion | Apply pose/impulse while grappling | Future — keep `PlayerMovement` free of Grapple internals |

`PlayerState` may later mirror `SWINGING` / `LAUNCHED` for animation; Grapple **phase** stays in `GrappleState.Phase`.

---

## 3. State machine

```
IDLE
  └─ request_air_ability() [armed + airborne + alive]
       → SEEKING
            ├─ valid latch → ATTACHED (begin_swing)
            └─ timeout / none → IDLE (seek_failed)
ATTACHED
  ├─ simulator.step(delta)
  ├─ auto-release (sim hint OR hard max duration)
  └─ release_now() → RELEASED
RELEASED
  └─ settle → IDLE (impulse already emitted)
Any → reset() → IDLE
```

Hard caps (`GrappleConfig.MAX_ATTACH_DURATION_SEC`) guarantee no hang even if the simulator never signals release.

---

## 4. Public API surface

### GrappleController

```gdscript
signal air_ability_requested
signal state_changed(from_phase: int, to_phase: int)
signal seek_failed
signal attached(latch: LatchPoint)
signal released(impulse: Vector2)
signal swing_pose_updated(position: Vector2, velocity: Vector2)

func request_air_ability() -> bool
func can_request_air_ability() -> bool
func update_host(snapshot: GrappleHostSnapshot) -> void
func update_host_values(position, velocity, is_airborne, is_alive) -> void
func process(delta: float) -> void
func force_attach(latch: LatchPoint) -> bool
func release_now() -> void
func reset() -> void
func set_simulator(simulator: GrappleSimulator) -> void
func set_latch_provider(provider: LatchProvider) -> void
func get_phase() -> int  # GrappleState.Phase
```

### GrappleSimulator (Agent B contract)

```gdscript
func begin_swing(anchor, player_position, initial_velocity, params: GrappleSwingParams) -> void
func step(delta: float) -> void
func get_player_position() -> Vector2
func get_player_velocity() -> Vector2
func get_anchor_position() -> Vector2
func get_rope_angle() -> float
func get_rope_length() -> float
func get_elapsed_sec() -> float
func is_active() -> bool
func should_auto_release() -> bool
func compute_release_impulse() -> Vector2
func reset() -> void
```

Implement under the same path or as a subclass (e.g. `DeterministicGrappleSimulator` extending `GrappleSimulator`). Controller default is `NullGrappleSimulator` (timer-based placeholder only).

### LatchSelector

- `is_valid_candidate(player_pos, latch)` — ahead (`LATCH_MIN_AHEAD`…`MAX_AHEAD`), height band, max range.
- `select_best(player_pos, candidates)` — closest with slight height bias.
- `filter_valid(...)`.

World latches should use group `Tags.ANCHOR` when modules land later; M5.0 does not spawn them.

---

## 5. Integration sketch (later milestone)

```
TouchGestureRouter  --air_action_requested-->  (host)
PlayerMovement / thin façade
        │
        ├─ update_host_values(...)
        ├─ request_air_ability()   # airborne second tap
        ├─ process(delta)
        ├─ on swing_pose_updated → set player position/velocity
        └─ on released(impulse) → apply impulse, resume fall
Death / GameScene restart → grapple.reset()
```

Do **not** overload `jump_requested` if an explicit air-ability signal can be added. Do **not** put latch physics in the router.

---

## 6. Test entry

`scripts/ci/m5_0_grapple_arch_smoke.gd` — headless FSM + selector checks, no Main scene.

```bash
godot --headless --path . -s res://scripts/ci/m5_0_grapple_arch_smoke.gd
```

---

## 7. File map

| File | Purpose |
|------|---------|
| `GrappleController.gd` | FSM + policy |
| `GrappleState.gd` | `Phase` enum |
| `GrappleConfig.gd` | Search / duration constants |
| `GrappleHostSnapshot.gd` | Per-frame host pose |
| `GrappleSwingParams.gd` | Oscillation params for simulator |
| `LatchPoint.gd` | Candidate data |
| `LatchProvider.gd` / `ArrayLatchProvider.gd` | Candidate supply |
| `LatchSelector.gd` | Filter + rank |
| `GrappleSimulator.gd` | Motion interface (Agent B) |
| `NullGrappleSimulator.gd` | Placeholder integrator |

Legacy placeholders `scripts/systems/SwingComponent.gd` / `SwingComboManager.gd` remain unused; Grapple does not depend on them.
