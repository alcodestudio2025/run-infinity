# Run Infinity — M5.1.2-E Coin density & reachability

Addresses late-run coin starvation when hazard stride shrinks to 1 (exclusive gap slots disappear).

## Problem

`ModuleSpawner` used mutually exclusive primary slots: latch / hazard / gap-coin.  
At advanced difficulty `HAZARD_STRIDE_MIN = 1`, every segment is a hazard (or latch), so `_is_coin_gap_slot` never matches → **0 coins** in M5.1.2-B level-6 scans.

## Fix (compatible co-placement)

Without removing hazards:

1. Keep gap coins when `stride > 1` (`index % stride == 1`).
2. On a deterministic period (`COIN_COMPAT_PERIOD = 3`, offset 0), also place a **compatible** coin on hazard or latch slices:
   - **Low / tall curb** → jump lane, X left/right of the curb anchor
   - **Double curb** → jump lane at mid X (between the pair)
   - **Overhead** → ground lane, X clear of the bar (slide clear path)
   - **Latch** → grapple lane, X right of the diamond

`COIN_SCORE_VALUE` remains **300**.

## Config

| Param | Value |
|-------|------:|
| `COIN_SCORE_VALUE` | 300 |
| `COIN_COMPAT_PERIOD` | 3 |
| `COIN_COMPAT_OFFSET` | 0 |
| Lanes | ground −56 / jump −130 / grapple −210 |

## Expected density (100 segments, deterministic)

| Band | Level | Stride | Min coin slots |
|------|------:|-------:|---------------:|
| Early | 0 | 3 | ≥20 |
| Mid | 3 | 2 | ≥20 |
| Advanced | 6 | 1 | ≥25 |

Advanced still keeps high hazard count (≥70/100). Smoke: `m5_1_2_e_coins_smoke.gd`.

## Reachability rules

| Primary | Coin lane | Clear action |
|---------|-----------|--------------|
| overhead | ground | SLIDE |
| low / tall / double | jump | JUMP |
| latch | grapple | Grapple swing |
| gap (stride>1) | rotating 0/1/2 | stand / jump / swing |

Coins are never placed as the sole reason to eat a hazard: lane+X avoid obstacle AABBs.

## Gate

No APK on this branch. FINAL APK only after ChatGPT/user authorization.
