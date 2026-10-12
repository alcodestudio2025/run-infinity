class_name PlayerState
extends RefCounted

## High-level player states. Physics details live in PlayerMovement.

enum State {
	IDLE,
	RUNNING,
	JUMPING,
	FALLING,
	SLIDING,
	SWING_AVAILABLE,
	SWINGING,
	LAUNCHED,
	HIT,
	DEAD,
}
