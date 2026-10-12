class_name IAchievementService
extends RefCounted


func unlock(_achievement_id: String) -> void:
	pass


func is_unlocked(_achievement_id: String) -> bool:
	return false


func get_progress(_achievement_id: String) -> float:
	return 0.0
