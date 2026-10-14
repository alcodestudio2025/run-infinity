class_name GrappleState
extends RefCounted

## Ability-local FSM for Grapple. Separate from PlayerState locomotion.
## Flow: IDLE → SEEKING → ATTACHED → RELEASED → IDLE

enum Phase {
	IDLE,
	SEEKING,
	ATTACHED,
	RELEASED,
}
