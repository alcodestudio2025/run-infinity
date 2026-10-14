# Run Infinity — M5.1.2-C Balance sheet

Configurable progression / scoring for the M5.1 cycle. Source of truth: `GameConfig.gd`.

## Speed curve

| Param | Value | Intent |
|-------|------:|--------|
| `BASE_WORLD_SPEED` | 340 | Accessible start, not empty crawl |
| `MAX_WORLD_SPEED` | 620 | Peak progression (boost ceiling separate at 900) |
| `WORLD_ACCELERATION` | 220 | Current speed catches target quickly enough to feel the ramp |
| `SPEED_RAMP_DISTANCE` | 9000 | Reach peak ~mid-run |
| `SPEED_RAMP_EASE_POWER` | 1.35 | Ease-out: readable early, clearer mid acceleration |

`get_target_speed_for_distance(d)` → ease-out lerp base→max.

**Reaction window at max:** `SEGMENT_LENGTH / MAX_WORLD_SPEED` ≈ 1920/620 ≈ **3.1 s** per segment — enough for JUMP / SLIDE / Grapple.

## Difficulty

| Param | Value | Intent |
|-------|------:|--------|
| `DIFFICULTY_DISTANCE_PER_LEVEL` | 1200 | Levels tick a bit faster than M5.1.1 |
| `DIFFICULTY_FACTOR_PER_LEVEL` | 0.12 | Mild factor growth |
| `HAZARD_STRIDE_SHRINK_LEVELS` | 2 | Stride 3→2→1 every 2 levels |
| Overhead/tall unlock | level 1 | SLIDE/JUMP variety after first curbs |

## Scoring

| Param | Value |
|-------|------:|
| `SCORE_PER_DISTANCE` | 1.0 |
| `COIN_SCORE_VALUE` | 300 |
| `COIN_COMPAT_PERIOD` | 3 |

A short teach coin sequence (~8 coins ≈ 2400) is noticeable next to ~8–12k distance points in a full run.  
Late-run coins use compatible co-placement when stride→1 — see [`docs/COIN_DENSITY_M5_1.md`](COIN_DENSITY_M5_1.md).

## Player feel (from 5.1.2-A)

| Param | Value |
|-------|------:|
| Jump velocity | 1050 |
| Gravity | 1350 |
| Fall mult | 1.55 |
| Max fall | 1600 |
| Slide duration | 0.45 s |

## Criteria

1. First hazard still after safe-start (index 3 at base stride).
2. Speed at 2k / 5k / 9k distance shows clear steps (smoke).
3. At max speed, segment gap ≥ ~3s.
4. Boost never exceeds `MAX_BOOST_WORLD_SPEED`.
5. No intermediate APK until FINAL authorization.
