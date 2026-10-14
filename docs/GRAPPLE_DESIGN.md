# Grapple Design — M5.0 Architecture & Simulation

Standalone Grapple package for Run Infinity. **Not wired** into `Main` / `GameScene` / `PlayerMovement` / `TouchGestureRouter` in this milestone.

**Package:** `res://scripts/grapple/`  
**Engine:** Godot 4.7.2 · **Milestone:** M5.0

---

## 1. Goals

1. First ground tap → jump (existing). Second airborne tap → **air-ability request** (Grapple).
2. Automatic latch search ahead + above; reject behind / out of range / absent.
3. Fast attach → brief automatic oscillation → **mandatory auto-release** with forward launch.
4. No manual aim; no indefinite hang.
5. Miss → normal jump trajectory continues.
6. Future: chain latches + multipliers (not in M5.0).
7. Deterministic headless simulation for design validation.

Non-goals (M5.0): live player integration, rope IK art, combo multipliers, generic ability framework, ads/IAP/backend.

---

## 2. Layering

| Layer | Role | Lives in |
|-------|------|----------|
| Input intents | Jump / slide / **air ability** | Future host — **not modified in M5.0** |
| `GrappleController` | Policy FSM, seek, attach, auto-release, reset | `GrappleController.gd` |
| Latch supply / select | Candidates + filter/rank | `LatchProvider`, `ArrayLatchProvider`, `LatchSelector`, `LatchPoint` |
| Motion contract | Swing step/query interface | `GrappleSimulator.gd` |
| Deterministic sim | Fixed-dt arc + launch | `DeterministicGrappleSimulator.gd` + `GrappleSimConfig.gd` |
| Null stub | Timer placeholder for FSM-only tests | `NullGrappleSimulator.gd` |
| Player locomotion | Apply pose/impulse | **Future M5.1** — keep `PlayerMovement` free of Grapple internals |

`PlayerState` already has unused `SWING_*` / `LAUNCHED` foreshadowing; Grapple **phase** stays in `GrappleState.Phase`.

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

Hard caps (`GrappleConfig.MAX_ATTACH_DURATION_SEC`) guarantee no hang even if the simulator misbehaves.

---

## 4. Latch selection criteria

### Controller / world (`LatchSelector` + `GrappleConfig`)

| Rule | Default |
|------|---------|
| Ahead (+X) | `LATCH_MIN_AHEAD` 24 … `LATCH_MAX_AHEAD` 420 |
| Above (−Y) | up to `LATCH_MAX_ABOVE` 360 |
| Max below | `LATCH_MAX_BELOW` 40 |
| Max range | `LATCH_MAX_RANGE` 480 |
| Rank | Closest with slight height bias |

### Standalone sim (`GrappleLatchQuery` + `GrappleSimConfig`)

| Rule | Default |
|------|---------|
| Radius | min 48 … max 280 |
| Require ahead / above | true |
| Rank | Nearest valid |

Behind / far / below → miss (jump continues).

---

## 5. Oscillation & release model

**Deterministic kinematic arc** (not Verlet rope):

1. On attach: rope length = distance player→latch; record start angle.
2. Over `swing_duration` (default **0.45s**, band 0.35–0.55): angle lerps by `swing_arc_radians` (default 1.75) with **smoothstep** easing.
3. Runner model (standalone): latches scroll −X at `scroll_speed` (320) so screen-X stays fixed.
4. Controller mode: world scroll owned by host; anchor held fixed during swing.
5. At duration end: **auto-release once** → tangential velocity + boost (`+420` x, `−120` y) → free flight with gravity.
6. No further input required to leave the latch.

---

## 6. Balancing parameters (configurable, not final)

### Policy (`GrappleConfig`)

| Param | Value | Role |
|-------|-------|------|
| `SEEK_TIMEOUT_SEC` | 0.08 | Fail seek quickly |
| `MIN_ATTACH_DURATION_SEC` | 0.18 | Readability floor |
| `MAX_ATTACH_DURATION_SEC` | 0.85 | Hard hang cap |
| `RELEASE_SETTLE_SEC` | 0.05 | RELEASED → IDLE |
| `DEFAULT_RELEASE_IMPULSE` | (180, −220) | Fallback impulse |

### Simulation (`GrappleSimConfig`)

| Param | Value | Role |
|-------|-------|------|
| `FIXED_DT` | 1/60 | Determinism |
| `swing_duration` | 0.45 | Oscillation window |
| `swing_arc_radians` | 1.75 | Arc size |
| `release_forward_boost` | 420 | Forward launch |
| `release_upward_boost` | 120 | Up launch |
| `scroll_speed` | 320 | Runner scroll model |
| `gravity` / `max_fall_speed` | 1350 / 1400 | Post-release |

---

## 7. Public API

### GrappleController

```gdscript
func request_air_ability() -> bool
func can_request_air_ability() -> bool
func update_host_values(position, velocity, is_airborne, is_alive) -> void
func process(delta: float) -> void
func reset() -> void
func set_simulator(simulator: GrappleSimulator) -> void
func set_latch_provider(provider: LatchProvider) -> void
# signals: air_ability_requested, attached, released(impulse), seek_failed, swing_pose_updated
```

### GrappleSimulator contract

```gdscript
func begin_swing(anchor, player_position, initial_velocity, params: GrappleSwingParams) -> void
func step(delta: float) -> void
func get_player_position() / get_player_velocity() / …
func should_auto_release() -> bool
func compute_release_impulse() -> Vector2
func reset() -> void
```

### DeterministicGrappleSimulator (also standalone)

```gdscript
func try_attach() -> bool
func set_player_state(pos, vel)
func set_latches(positions)
func step() / step_n(n)
func sample() -> Dictionary
func reset_after_death(spawn_pos)
```

---

## 8. Integration sketch (M5.1 — not this PR)

```
TouchGestureRouter  --air_action_requested-->  host
        │
        ├─ update_host_values(...)
        ├─ request_air_ability()   # airborne second tap
        ├─ process(delta)
        ├─ on swing_pose_updated → apply pose
        └─ on released(impulse) → apply impulse
Death / restart → grapple.reset()
```

Do **not** overload `jump_requested` if an explicit air-ability signal can be added.

---

## 9. Tests

| Smoke | Covers |
|-------|--------|
| `m5_0_grapple_arch_smoke.gd` | FSM, guards, seek fail, reset, reject behind |
| `m5_0_grapple_sim_smoke.gd` | Attach/miss, duration, auto-release launch, death reset, determinism |

```bash
source scripts/ci/smoke_env.sh && ri_smoke_env_setup
godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m5_0_grapple_arch_smoke.gd
godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m5_0_grapple_sim_smoke.gd
```

---

## 10. File map

| File | Purpose |
|------|---------|
| `GrappleController.gd` | FSM + policy |
| `GrappleState.gd` | `Phase` enum |
| `GrappleConfig.gd` | Search / duration constants |
| `GrappleHostSnapshot.gd` | Per-frame host pose |
| `GrappleSwingParams.gd` | Params for `begin_swing` |
| `LatchPoint.gd` / `LatchProvider.gd` / `ArrayLatchProvider.gd` / `LatchSelector.gd` | Latch pipeline |
| `GrappleSimulator.gd` | Motion interface |
| `NullGrappleSimulator.gd` | Placeholder integrator |
| `DeterministicGrappleSimulator.gd` | Real fixed-dt sim |
| `GrappleSimConfig.gd` / `GrappleLatchQuery.gd` | Sim tuning + latch helpers |
