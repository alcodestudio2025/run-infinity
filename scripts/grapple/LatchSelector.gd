class_name LatchSelector
extends RefCounted

## Pure latch search + selection. Ahead+above preferred; behind / OOR rejected.
## No scene-tree dependency — safe for headless unit smokes.


static func is_valid_candidate(player_pos: Vector2, latch: LatchPoint) -> bool:
	if latch == null:
		return false
	var delta: Vector2 = latch.position - player_pos
	## Behind or not far enough ahead (run direction = +X).
	if delta.x < GrappleConfig.LATCH_MIN_AHEAD:
		return false
	if delta.x > GrappleConfig.LATCH_MAX_AHEAD:
		return false
	## Above = smaller Y in Godot 2D.
	var above: float = player_pos.y - latch.position.y
	if above > GrappleConfig.LATCH_MAX_ABOVE:
		return false
	if above < -GrappleConfig.LATCH_MAX_BELOW:
		return false
	if delta.length() > GrappleConfig.LATCH_MAX_RANGE:
		return false
	return true


## Score: prefer ahead+above, closer, higher. Higher score wins.
static func score_candidate(player_pos: Vector2, latch: LatchPoint) -> float:
	if not is_valid_candidate(player_pos, latch):
		return -INF
	var delta: Vector2 = latch.position - player_pos
	var dist: float = maxf(delta.length(), 1.0)
	var above: float = maxf(player_pos.y - latch.position.y, 0.0)
	## Closer is better; slight bias for height so overhead anchors win ties.
	return (1000.0 / dist) + above * 0.02 + delta.x * 0.001


## Returns the best valid latch, or null.
## Accepts Array or Array[LatchPoint] for headless smoke friendliness.
static func select_best(player_pos: Vector2, candidates: Array) -> LatchPoint:
	var best: LatchPoint = null
	var best_score: float = -INF
	for item in candidates:
		var latch: LatchPoint = item as LatchPoint
		if latch == null:
			continue
		var score: float = score_candidate(player_pos, latch)
		if score > best_score:
			best_score = score
			best = latch
	return best


## Filter only — preserves input order among valid candidates.
static func filter_valid(player_pos: Vector2, candidates: Array) -> Array[LatchPoint]:
	var out: Array[LatchPoint] = []
	for item in candidates:
		var latch: LatchPoint = item as LatchPoint
		if latch != null and is_valid_candidate(player_pos, latch):
			out.append(latch)
	return out
