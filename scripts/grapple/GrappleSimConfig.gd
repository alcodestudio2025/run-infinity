class_name GrappleSimConfig
extends RefCounted

## Tunable parameters for the isolated Grapple simulator (M5.0).
## Values are starting proposals — not final balance.

## Fixed timestep used by smokes and recommended for live consumers.
const FIXED_DT: float = 1.0 / 60.0

## Max / min rope distance for a valid attach (px, world / player-relative).
@export var max_attach_radius: float = 280.0
@export var min_attach_radius: float = 48.0

## Latch must sit ahead (+X) and above (−Y in Godot) of the player.
@export var require_ahead: bool = true
@export var require_above: bool = true
@export var ahead_epsilon: float = 1.0
@export var above_epsilon: float = 1.0

## Prefer the nearest valid latch; ties break by smaller |index|.
@export var prefer_nearest: bool = true

## Brief swing window (proposed band ~0.35–0.55s).
@export var swing_duration: float = 0.45

## Arc swept around the latch during the swing (radians, clockwise in Godot Y-down).
## Positive = swing "forward" (increasing angle from initial attach).
@export var swing_arc_radians: float = 1.75

## Extra launch impulses applied once at auto-release (px/s).
## +X is run-forward; −Y is upward (Godot Y-down).
@export var release_forward_boost: float = 420.0
@export var release_upward_boost: float = 120.0

## World scroll rate while free-running / seeking (px/s).
## Models a scrolling runner: latches approach from +X at this speed while
## the player's screen-X stays roughly fixed.
@export var scroll_speed: float = 320.0

## Gravity applied after release (px/s², +Y down). 0 disables.
@export var gravity: float = 1350.0

## Clamp fall speed after release (px/s).
@export var max_fall_speed: float = 1400.0


func duplicate_config() -> RefCounted:
	## Avoid self class_name identity inside this file so -s smokes compile
	## before global_script_class_cache is refreshed.
	var copy: RefCounted = (load("res://scripts/grapple/GrappleSimConfig.gd") as GDScript).new()
	copy.set("max_attach_radius", max_attach_radius)
	copy.set("min_attach_radius", min_attach_radius)
	copy.set("require_ahead", require_ahead)
	copy.set("require_above", require_above)
	copy.set("ahead_epsilon", ahead_epsilon)
	copy.set("above_epsilon", above_epsilon)
	copy.set("prefer_nearest", prefer_nearest)
	copy.set("swing_duration", swing_duration)
	copy.set("swing_arc_radians", swing_arc_radians)
	copy.set("release_forward_boost", release_forward_boost)
	copy.set("release_upward_boost", release_upward_boost)
	copy.set("scroll_speed", scroll_speed)
	copy.set("gravity", gravity)
	copy.set("max_fall_speed", max_fall_speed)
	return copy
