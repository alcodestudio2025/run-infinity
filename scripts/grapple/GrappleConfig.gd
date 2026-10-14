class_name GrappleConfig
extends RefCounted

## Tuning for Grapple search, attach, and auto-release.
## Motion math (oscillation) lives in GrappleSimulator — Agent B owns that.

# -- Latch search (world units, Y-down) ----------------------------------------

## Max horizontal reach ahead of the player (positive X = run direction).
const LATCH_MAX_AHEAD: float = 420.0
## Min horizontal ahead so we never latch on the player's current X.
const LATCH_MIN_AHEAD: float = 24.0
## How far above the player a latch may sit (player.y - latch.y).
const LATCH_MAX_ABOVE: float = 360.0
## Reject latches below the player's feet by more than this (rare / ground clutter).
const LATCH_MAX_BELOW: float = 40.0
## Absolute max distance from player to latch.
const LATCH_MAX_RANGE: float = 480.0

# -- Seek / attach -------------------------------------------------------------

## Max time spent seeking before failing back to IDLE (seconds).
const SEEK_TIMEOUT_SEC: float = 0.08
## Instant attach when a valid latch is found in the same frame (typical).
const SEEK_SAME_FRAME: bool = true

# -- Swing / auto-release (controller policy; simulator may also signal) -------

## Hard cap: never hang indefinitely even if the simulator misbehaves.
const MAX_ATTACH_DURATION_SEC: float = 0.85
## Minimum time attached before auto-release is allowed (feel / readability).
const MIN_ATTACH_DURATION_SEC: float = 0.18
## Brief RELEASED settle before returning to IDLE (impulse already applied).
const RELEASE_SETTLE_SEC: float = 0.05

# -- Default release boost (used when simulator returns zero impulse) ----------

const DEFAULT_RELEASE_IMPULSE: Vector2 = Vector2(180.0, -220.0)
