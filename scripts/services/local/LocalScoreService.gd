class_name LocalScoreService
extends IScoreService

const SCORES_PATH := "user://scores.json"


func add_score(score: int, player_name: String = "") -> void:
	var scores := get_leaderboard()
	scores.append({
		"score": score,
		"player_name": player_name,
		"timestamp": Time.get_unix_time_from_system(),
	})
	scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	_write_scores(scores)


func get_leaderboard() -> Array:
	if not FileAccess.file_exists(SCORES_PATH):
		return []

	var file := FileAccess.open(SCORES_PATH, FileAccess.READ)
	if file == null:
		push_error("LocalScoreService: failed to read %s" % SCORES_PATH)
		return []

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()

	if parse_error != OK:
		push_error("LocalScoreService: invalid JSON in %s" % SCORES_PATH)
		return []

	return json.data if json.data is Array else []


func clear_scores() -> void:
	if FileAccess.file_exists(SCORES_PATH):
		DirAccess.remove_absolute(SCORES_PATH)


func _write_scores(scores: Array) -> void:
	var file := FileAccess.open(SCORES_PATH, FileAccess.WRITE)
	if file == null:
		push_error("LocalScoreService: failed to write %s" % SCORES_PATH)
		return

	file.store_string(JSON.stringify(scores))
	file.close()
