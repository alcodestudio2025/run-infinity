extends RefCounted
class_name SmokeBootHelpers

## Shared helpers for headless smokes after M3.3 title gate.
## Main boots to MAIN_MENU; gameplay smokes must call Main.start_game() once.
## Does not auto-start in production — only invoked explicitly by smokes.

## Must match GameStateManager.GameState
const STATE_MAIN_MENU: int = 1
const STATE_PLAYING: int = 2


static func find_main(tree_root: Node) -> Node:
	var named: Node = tree_root.get_node_or_null("Main")
	if named != null:
		return named
	for child: Node in tree_root.get_children():
		if child.has_method("start_game") and child.has_method("is_title_visible"):
			return child
		if child.get_node_or_null("GameSceneContainer") != null:
			return child
	return null


static func ensure_playing_from_title(tree_root: Node, label: String) -> bool:
	## Call after Main is loaded. If already PLAYING, no-op success.
	## If MAIN_MENU, invoke Main.start_game(). Caller should await frames after.
	var gsm: Node = tree_root.get_node_or_null("GameStateManager")
	if gsm == null:
		push_error("%s: GameStateManager missing (ensure_playing)." % label)
		return false

	var state: int = int(gsm.get("current_state"))
	if state == STATE_PLAYING:
		return true

	if state != STATE_MAIN_MENU:
		push_error(
			"%s: expected MAIN_MENU or PLAYING before ensure_playing, got %d."
			% [label, state]
		)
		return false

	var main: Node = find_main(tree_root)
	if main == null or not main.has_method("start_game"):
		push_error("%s: Main.start_game missing (title gate)." % label)
		return false

	main.call("start_game")
	return true
