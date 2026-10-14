class_name ArrayLatchProvider
extends LatchProvider

## Test / stub latch source: fixed candidate list. Not used by live Main in M5.0.

var latches: Array[LatchPoint] = []


func _init(p_latches: Array = []) -> void:
	latches.assign(p_latches)


func set_latches(p_latches: Array) -> void:
	latches.clear()
	latches.assign(p_latches)


func collect_latches() -> Array[LatchPoint]:
	return latches
