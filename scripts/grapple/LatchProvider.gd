class_name LatchProvider
extends RefCounted

## Interface: supply world latch candidates for GrappleController seek.
## Override collect_latches() in tests or future module scanners.
## Default returns empty — Grapple is not wired to live modules in M5.0.


func collect_latches() -> Array[LatchPoint]:
	return []
