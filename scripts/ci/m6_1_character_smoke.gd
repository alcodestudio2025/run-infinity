extends SceneTree

## Headless M6.1 smoke: catalog, selection persist, visual anims, collision unchanged.
##   source scripts/ci/smoke_env.sh && ri_smoke_env_setup
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m6_1_character_smoke.gd

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const Catalog := preload("res://scripts/characters/CharacterCatalog.gd")

const LABEL := "M6.1 character smoke"
const SAVE_PATH := "user://save_data.json"
const WARMUP_FRAMES: int = 90
const POST_START_FRAMES: int = 60
const POST_KILL_FRAMES: int = 5
const POST_RESTART_FRAMES: int = 45
const STATE_MAIN_MENU: int = 1
const STATE_PLAYING: int = 2
const STATE_GAME_OVER: int = 4


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Guard.require_isolated(self, LABEL):
		return

	_clear_isolated_save_file()

	# --- Case 0: catalog contract ---
	var ids: PackedStringArray = Catalog.all_ids()
	if ids.size() != 2 or not Catalog.is_valid_id("kai") or not Catalog.is_valid_id("nova"):
		push_error("%s: catalog must expose kai + nova." % LABEL)
		quit(1)
		return
	if Catalog.normalize_id("missing") != Catalog.DEFAULT_ID:
		push_error("%s: normalize_id must fall back to default." % LABEL)
		quit(1)
		return
	var anims: PackedStringArray = Catalog.all_anims()
	if anims.size() != 8:
		push_error("%s: expected 8 anims, got %d." % [LABEL, anims.size()])
		quit(1)
		return
	for anim: String in anims:
		if anim.is_empty() or not Catalog.is_valid_anim(anim):
			push_error("%s: invalid anim '%s'." % [LABEL, anim])
			quit(1)
			return
	print("%s: case0 PASS (catalog kai/nova + %d anims)" % [LABEL, anims.size()])

	var save_manager: Node = root.get_node_or_null("SaveManager")
	if save_manager == null:
		push_error("%s: SaveManager missing." % LABEL)
		quit(1)
		return

	save_manager.call("reset_data")
	if str(save_manager.call("get_selected_character_id")) != "kai":
		push_error("%s: default selected_character_id should be kai." % LABEL)
		quit(1)
		return

	save_manager.call("set_selected_character_id", "nova")
	if str(save_manager.call("get_selected_character_id")) != "nova":
		push_error("%s: set_selected_character_id(nova) failed in-memory." % LABEL)
		quit(1)
		return

	## Simulate restart: reload from disk.
	save_manager.call("load_data")
	if str(save_manager.call("get_selected_character_id")) != "nova":
		push_error("%s: selected_character_id did not persist across load_data." % LABEL)
		quit(1)
		return
	print("%s: case1 PASS (persist nova across load_data)" % LABEL)

	var err: Error = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("%s: failed to load Main.tscn (%s)" % [LABEL, error_string(err)])
		quit(1)
		return

	await _wait_frames(WARMUP_FRAMES)

	var gsm: Node = root.get_node_or_null("GameStateManager")
	var main: Node = _find_main()
	if gsm == null or main == null:
		push_error("%s: Main / GameStateManager missing." % LABEL)
		quit(1)
		return

	if int(gsm.get("current_state")) != STATE_MAIN_MENU:
		push_error("%s: expected MAIN_MENU after warmup." % LABEL)
		quit(1)
		return

	if not bool(main.call("is_title_visible")):
		push_error("%s: title should be visible at boot." % LABEL)
		quit(1)
		return

	# --- Case 2: Title PLAY opens character select (not immediate start) ---
	var title: Node = main.get_node_or_null("TitleScreen")
	if title == null:
		push_error("%s: TitleScreen missing." % LABEL)
		quit(1)
		return
	title.emit_signal("play_pressed")
	await _wait_frames(10)

	if not main.has_method("is_character_select_visible"):
		push_error("%s: Main missing is_character_select_visible." % LABEL)
		quit(1)
		return
	if not bool(main.call("is_character_select_visible")):
		push_error("%s: character select should open after title play_pressed." % LABEL)
		quit(1)
		return
	if int(gsm.get("current_state")) != STATE_MAIN_MENU:
		push_error("%s: character select must keep MAIN_MENU." % LABEL)
		quit(1)
		return
	print("%s: case2 PASS (title → character select, still MAIN_MENU)" % LABEL)

	# --- Case 3: confirm selection starts game with Nova visual ---
	var select: Node = main.get_node_or_null("CharacterSelectionScreen")
	if select == null:
		push_error("%s: CharacterSelectionScreen missing." % LABEL)
		quit(1)
		return
	save_manager.call("set_selected_character_id", "nova")
	if select.has_method("_select"):
		select.call("_select", "nova")
	## Persist already done; signal drives Main.apply + start_game.
	select.emit_signal("character_confirmed", "nova")
	await _wait_frames(POST_START_FRAMES)

	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error(
			"%s: expected PLAYING after confirm/start, got %d."
			% [LABEL, int(gsm.get("current_state"))]
		)
		quit(1)
		return

	var game_scene: Node = _find_game_scene(main)
	var player: Node = _find_player(game_scene)
	if player == null:
		push_error("%s: Player missing." % LABEL)
		quit(1)
		return

	var visual: Node = player.get_node_or_null("CharacterVisual")
	if visual == null:
		push_error("%s: CharacterVisual missing under Player." % LABEL)
		quit(1)
		return
	if str(visual.get("character_id")) != "nova":
		if player.has_method("apply_character"):
			player.call("apply_character", "nova")
		await _wait_frames(2)
	if str(visual.get("character_id")) != "nova":
		push_error(
			"%s: visual character_id=%s expected nova."
			% [LABEL, str(visual.get("character_id"))]
		)
		quit(1)
		return

	## Collision must remain standing defaults (aesthetic must not alter hitbox).
	var collision: CollisionShape2D = player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		push_error("%s: CollisionShape2D missing." % LABEL)
		quit(1)
		return
	var rect: RectangleShape2D = collision.shape as RectangleShape2D
	if rect == null:
		push_error("%s: expected RectangleShape2D hitbox." % LABEL)
		quit(1)
		return
	if not rect.size.is_equal_approx(Vector2(48, 72)):
		push_error("%s: standing hitbox size changed (%s)." % [LABEL, str(rect.size)])
		quit(1)
		return
	if not collision.position.is_equal_approx(Vector2(0, -4)):
		push_error("%s: standing hitbox position changed (%s)." % [LABEL, str(collision.position)])
		quit(1)
		return
	print("%s: case3 PASS (PLAYING nova visual, hitbox unchanged)" % LABEL)

	# --- Case 4: animation transitions (all catalog anims) ---
	for anim: String in Catalog.all_anims():
		visual.call("play", anim)
		await _wait_frames(1)
		if str(visual.get("current_anim")) != anim:
			push_error(
				"%s: play(%s) → current_anim=%s"
				% [LABEL, anim, str(visual.get("current_anim"))]
			)
			quit(1)
			return
	## Slide pose API (visual only)
	visual.call("set_sliding", true)
	await _wait_frames(1)
	if str(visual.get("current_anim")) != "slide":
		push_error("%s: set_sliding should play slide." % LABEL)
		quit(1)
		return
	visual.call("set_standing")
	await _wait_frames(1)
	print("%s: case4 PASS (all anims + slide/standing visual API)" % LABEL)

	# --- Case 5: Game Over → restart keeps character + GO flow ---
	player.call("kill")
	await _wait_frames(POST_KILL_FRAMES)
	if int(gsm.get("current_state")) != STATE_GAME_OVER:
		push_error("%s: expected GAME_OVER after kill." % LABEL)
		quit(1)
		return
	game_scene.call("restart_run")
	await _wait_frames(POST_RESTART_FRAMES)
	if int(gsm.get("current_state")) != STATE_PLAYING:
		push_error("%s: expected PLAYING after restart_run." % LABEL)
		quit(1)
		return
	player = _find_player(game_scene)
	visual = player.get_node_or_null("CharacterVisual") if player != null else null
	if visual == null or str(visual.get("character_id")) != "nova":
		push_error("%s: character should remain nova after restart." % LABEL)
		quit(1)
		return
	if bool(main.call("is_title_visible")):
		push_error("%s: title must stay hidden after restart." % LABEL)
		quit(1)
		return
	print("%s: case5 PASS (GO/restart unchanged, nova persists)" % LABEL)

	# --- Case 6: Kai swap ---
	save_manager.call("set_selected_character_id", "kai")
	if player.has_method("apply_saved_character"):
		player.call("apply_saved_character")
	await _wait_frames(2)
	if str(visual.get("character_id")) != "kai":
		push_error("%s: apply_saved_character failed for kai." % LABEL)
		quit(1)
		return
	print("%s: case6 PASS (kai swap)" % LABEL)

	print("M6.1 character smoke PASS")
	quit(0)


func _clear_isolated_save_file() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _find_main() -> Node:
	var named: Node = root.get_node_or_null("Main")
	if named != null:
		return named
	var current: Node = get_current_scene()
	if current != null and current.has_method("start_game"):
		return current
	return null


func _find_game_scene(main: Node) -> Node:
	var container: Node = main.get_node_or_null("GameSceneContainer") if main != null else null
	if container == null or container.get_child_count() == 0:
		return null
	return container.get_child(0)


func _find_player(game_scene: Node) -> Node:
	if game_scene == null:
		return null
	var player_root: Node = game_scene.get_node_or_null("PlayerRoot")
	if player_root == null or player_root.get_child_count() == 0:
		return null
	return player_root.get_child(0)


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await physics_frame
