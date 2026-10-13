extends Node

enum GameState {
	BOOT,
	MAIN_MENU,
	PLAYING,
	PAUSED,
	GAME_OVER,
	SHOP,
	LEADERBOARD,
	SETTINGS,
}

var current_state: GameState = GameState.BOOT
var previous_state: GameState = GameState.BOOT


func transition_to(new_state: GameState) -> void:
	if current_state == new_state:
		return

	previous_state = current_state
	current_state = new_state
	if GameConfig.DEBUG_LOG:
		print_debug(
			"GameState: %s -> %s" % [
				GameState.keys()[previous_state],
				GameState.keys()[new_state],
			]
		)


func is_playing() -> bool:
	return current_state == GameState.PLAYING
