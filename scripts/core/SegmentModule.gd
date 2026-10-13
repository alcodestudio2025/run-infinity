class_name SegmentModule
extends Node2D

## Abstract base for attachable segment content.
## Concrete modules: low/tall/overhead obstacles, coins; swing later.


func setup(_context: Dictionary = {}) -> void:
	pass


func activate() -> void:
	pass


func deactivate() -> void:
	pass


func reset() -> void:
	pass
