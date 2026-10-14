class_name GrappleLatchQuery
extends RefCounted

## Pure helpers: pick a valid Grapple latch relative to the player.
## No scene tree, physics queries, or RNG.


static func is_valid_latch(
	player_pos: Vector2,
	latch_pos: Vector2,
	config: RefCounted,
) -> bool:
	if config == null:
		return false
	var min_r: float = float(config.min_attach_radius)
	var max_r: float = float(config.max_attach_radius)
	var dist: float = player_pos.distance_to(latch_pos)
	if dist < min_r or dist > max_r:
		return false
	if bool(config.require_ahead) and latch_pos.x < player_pos.x + float(config.ahead_epsilon):
		return false
	if bool(config.require_above) and latch_pos.y > player_pos.y - float(config.above_epsilon):
		return false
	return true


## Returns { ok, index, position, distance }. ok=false when nothing qualifies.
static func find_best_latch(
	player_pos: Vector2,
	latches: Array,
	config: RefCounted,
) -> Dictionary:
	var best_ok := false
	var best_index: int = -1
	var best_pos := Vector2.ZERO
	var best_dist: float = INF

	if config == null:
		return _miss()

	var prefer_nearest: bool = bool(config.prefer_nearest)

	for i in range(latches.size()):
		var latch_pos: Vector2 = latches[i] as Vector2
		if not is_valid_latch(player_pos, latch_pos, config):
			continue
		var dist: float = player_pos.distance_to(latch_pos)
		var take := false
		if not best_ok:
			take = true
		elif prefer_nearest:
			if dist < best_dist - 0.0001:
				take = true
			elif absf(dist - best_dist) <= 0.0001 and i < best_index:
				take = true
		elif i < best_index or best_index < 0:
			take = true
		if take:
			best_ok = true
			best_index = i
			best_pos = latch_pos
			best_dist = dist

	if not best_ok:
		return _miss()
	return {
		"ok": true,
		"index": best_index,
		"position": best_pos,
		"distance": best_dist,
	}


static func _miss() -> Dictionary:
	return {
		"ok": false,
		"index": -1,
		"position": Vector2.ZERO,
		"distance": -1.0,
	}
