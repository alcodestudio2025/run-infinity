class_name GrappleSwingParams
extends RefCounted

## Oscillation / swing parameters passed into GrappleSimulator.begin_swing().
## Agent B's deterministic simulator interprets these; the controller only owns policy.

## Rest length of the rope (distance player↔anchor at attach, or tuned override).
var rope_length: float = 0.0
## Gravity used by the swing integrator (may differ from player fall gravity).
var gravity: float = 1350.0
## Damping on angular velocity (0 = none).
var damping: float = 0.15
## Max swing half-angle from vertical (radians); soft clamp for feel.
var max_swing_angle: float = 1.15
## Preferred auto-release when angle crosses this past the bottom (radians).
var release_angle: float = 0.55
## Prefer release on the forward-rising side of the arc.
var prefer_forward_release: bool = true
## Hard time cap mirrored from GrappleConfig (simulator may use for should_auto_release).
var max_duration_sec: float = GrappleConfig.MAX_ATTACH_DURATION_SEC
## Minimum time before simulator may signal release.
var min_duration_sec: float = GrappleConfig.MIN_ATTACH_DURATION_SEC


static func from_config() -> GrappleSwingParams:
	var params := GrappleSwingParams.new()
	params.max_duration_sec = GrappleConfig.MAX_ATTACH_DURATION_SEC
	params.min_duration_sec = GrappleConfig.MIN_ATTACH_DURATION_SEC
	return params
