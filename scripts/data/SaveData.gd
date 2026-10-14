class_name SaveData
extends Resource

@export var player_id: String = ""
@export var display_name: String = "Player"
## Stable CharacterCatalog id (`kai` | `nova`). Default Kai.
@export var selected_character_id: String = "kai"
@export var total_runs: int = 0
@export var level: int = 1
@export var xp: int = 0
@export var soft_currency: int = 0
@export var premium_currency: int = 0
@export var high_score: int = 0
@export var total_distance: float = 0.0
@export var total_coins_collected: int = 0
@export var best_swing_combo: int = 0
@export var total_swings: int = 0
@export var total_perfect_swings: int = 0
@export var swing_mechanic_unlocked: bool = false
@export var ads_removed: bool = false
@export var sfx_volume: float = 1.0
@export var music_volume: float = 1.0
@export var haptic_enabled: bool = true


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": display_name,
		"selected_character_id": selected_character_id,
		"total_runs": total_runs,
		"level": level,
		"xp": xp,
		"soft_currency": soft_currency,
		"premium_currency": premium_currency,
		"high_score": high_score,
		"total_distance": total_distance,
		"total_coins_collected": total_coins_collected,
		"best_swing_combo": best_swing_combo,
		"total_swings": total_swings,
		"total_perfect_swings": total_perfect_swings,
		"swing_mechanic_unlocked": swing_mechanic_unlocked,
		"ads_removed": ads_removed,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"haptic_enabled": haptic_enabled,
	}


static func from_dict(dict: Dictionary) -> SaveData:
	var data := SaveData.new()
	data.player_id = dict.get("player_id", "")
	data.display_name = dict.get("display_name", "Player")
	data.selected_character_id = str(dict.get("selected_character_id", "kai"))
	data.total_runs = dict.get("total_runs", 0)
	data.level = dict.get("level", 1)
	data.xp = dict.get("xp", 0)
	data.soft_currency = dict.get("soft_currency", 0)
	data.premium_currency = dict.get("premium_currency", 0)
	data.high_score = dict.get("high_score", 0)
	data.total_distance = dict.get("total_distance", 0.0)
	data.total_coins_collected = dict.get("total_coins_collected", 0)
	data.best_swing_combo = dict.get("best_swing_combo", 0)
	data.total_swings = dict.get("total_swings", 0)
	data.total_perfect_swings = dict.get("total_perfect_swings", 0)
	data.swing_mechanic_unlocked = dict.get("swing_mechanic_unlocked", false)
	data.ads_removed = dict.get("ads_removed", false)
	data.sfx_volume = dict.get("sfx_volume", 1.0)
	data.music_volume = dict.get("music_volume", 1.0)
	data.haptic_enabled = dict.get("haptic_enabled", true)
	return data
