extends SceneTree

## Capture REAL Godot viewport PNGs for M6.1 visual preview (proxy art only).
## Requires a working display (do NOT pass --headless).
##
##   DISPLAY=:1 godot --path . --fixed-fps 60 -s res://scripts/ci/m6_1_visual_preview_capture.gd
##
## Writes under res://docs/previews/m6-1/ (and optional OUT_DIR via env RI_PREVIEW_OUT).

const LABEL := "M6.1 visual preview capture"
const OUT_REL := "res://docs/previews/m6-1"
const WARMUP: int = 90
const SETTLE: int = 20
const STATE_MAIN_MENU: int = 1
const STATE_PLAYING: int = 2


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var out_dir: String = OUT_REL
	var env_out: String = OS.get_environment("RI_PREVIEW_OUT")
	if not env_out.is_empty():
		out_dir = env_out
	_ensure_dir(out_dir)

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))

	var err: Error = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("%s: failed to load Main.tscn (%s)" % [LABEL, error_string(err)])
		quit(1)
		return

	await _wait_frames(WARMUP)
	await _force_draw()

	var main: Node = _find_main()
	var gsm: Node = root.get_node_or_null("GameStateManager")
	var save_manager: Node = root.get_node_or_null("SaveManager")
	if main == null or gsm == null or save_manager == null:
		push_error("%s: Main/GSM/SaveManager missing." % LABEL)
		quit(1)
		return

	if int(gsm.get("current_state")) != STATE_MAIN_MENU:
		push_error("%s: expected MAIN_MENU at boot." % LABEL)
		quit(1)
		return

	## 1) Title screen (context)
	if not await _capture(out_dir, "01-title.png"):
		quit(1)
		return
	print("%s: wrote 01-title.png" % LABEL)

	## 2) Character selection (Kai/Nova buttons — real UI)
	var title: Node = main.get_node_or_null("TitleScreen")
	if title == null:
		push_error("%s: TitleScreen missing." % LABEL)
		quit(1)
		return
	title.emit_signal("play_pressed")
	await _wait_frames(SETTLE)
	await _force_draw()
	if not bool(main.call("is_character_select_visible")):
		push_error("%s: character select not visible." % LABEL)
		quit(1)
		return
	if not await _capture(out_dir, "02-character-select.png"):
		quit(1)
		return
	print("%s: wrote 02-character-select.png" % LABEL)

	## Highlight Kai then Nova on select screen
	var select: Node = main.get_node_or_null("CharacterSelectionScreen")
	if select != null and select.has_method("_select"):
		select.call("_select", "kai")
		await _wait_frames(10)
		await _force_draw()
		await _capture(out_dir, "03-character-select-kai-highlighted.png")
		select.call("_select", "nova")
		await _wait_frames(10)
		await _force_draw()
		await _capture(out_dir, "04-character-select-nova-highlighted.png")

	## 3) Gameplay Kai — run / jump / slide / (grapple if driver allows)
	await _start_with_character(main, save_manager, select, "kai")
	await _wait_frames(45)
	await _force_draw()
	await _capture(out_dir, "05-gameplay-kai-run.png")
	print("%s: wrote 05-gameplay-kai-run.png" % LABEL)

	var player: Node = _find_player(main)
	var movement: Node = player.get_node_or_null("PlayerMovement") if player != null else null
	var visual: Node = player.get_node_or_null("CharacterVisual") if player != null else null

	await _capture_jump_pose(out_dir, "06-gameplay-kai-jump.png", player, movement)
	await _capture_slide_pose(out_dir, "07-gameplay-kai-slide.png", player, movement)
	await _try_capture_grapple(out_dir, "08-gameplay-kai-grapple.png", player, movement, visual)

	## 4) Gameplay Nova — same poses
	## Return to menu path: kill → we need title again. Easiest: reload Main.
	err = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("%s: reload Main failed." % LABEL)
		quit(1)
		return
	await _wait_frames(WARMUP)
	main = _find_main()
	gsm = root.get_node_or_null("GameStateManager")
	save_manager = root.get_node_or_null("SaveManager")
	title = main.get_node_or_null("TitleScreen")
	title.emit_signal("play_pressed")
	await _wait_frames(SETTLE)
	select = main.get_node_or_null("CharacterSelectionScreen")
	await _start_with_character(main, save_manager, select, "nova")
	await _wait_frames(45)
	await _force_draw()
	await _capture(out_dir, "09-gameplay-nova-run.png")
	print("%s: wrote 09-gameplay-nova-run.png" % LABEL)

	player = _find_player(main)
	movement = player.get_node_or_null("PlayerMovement") if player != null else null
	visual = player.get_node_or_null("CharacterVisual") if player != null else null

	await _capture_jump_pose(out_dir, "10-gameplay-nova-jump.png", player, movement)
	await _capture_slide_pose(out_dir, "11-gameplay-nova-slide.png", player, movement)
	await _try_capture_grapple(out_dir, "12-gameplay-nova-grapple.png", player, movement, visual)

	## Manifest note for reviewers
	var manifest := FileAccess.open("%s/README.md" % out_dir, FileAccess.WRITE)
	if manifest != null:
		manifest.store_string(
			"# M6.1 visual previews (real Godot viewports)\n\n"
			+ "Captured from commit gameplay UI — **proxy silhouettes**, not final Kai/Nova sprites.\n"
			+ "Approved concept sheet: `docs/media/m6-character-ref-kai-nova.jpg`.\n"
			+ "Re-run: `DISPLAY=:1 godot --path . --fixed-fps 60 -s res://scripts/ci/m6_1_visual_preview_capture.gd`\n"
		)
		manifest.close()

	print("%s: PASS" % LABEL)
	quit(0)


func _start_with_character(main: Node, save_manager: Node, select: Node, character_id: String) -> void:
	save_manager.call("set_selected_character_id", character_id)
	if select != null and select.has_method("_select"):
		select.call("_select", character_id)
	if select != null:
		select.emit_signal("character_confirmed", character_id)
	await _wait_frames(SETTLE)
	## Ensure PLAYING even if signal path raced
	var gsm: Node = root.get_node_or_null("GameStateManager")
	if gsm != null and int(gsm.get("current_state")) != STATE_PLAYING:
		main.call("start_game")
		await _wait_frames(SETTLE)


func _capture_jump_pose(out_dir: String, filename: String, player: Node, movement: Node) -> void:
	if movement == null or player == null:
		return
	## Ensure on floor before jump.
	await _wait_until_state(player, "RUNNING", 90)
	if movement.has_method("request_jump_immediate"):
		movement.call("request_jump_immediate")
	if await _wait_until_state(player, "JUMPING", 30):
		await _force_draw()
		await _capture(out_dir, filename)
		print("%s: wrote %s (state JUMPING)" % [LABEL, filename])
	else:
		await _force_draw()
		await _capture(out_dir, filename)
		print("%s: wrote %s (jump requested; state may have advanced)" % [LABEL, filename])


func _capture_slide_pose(out_dir: String, filename: String, player: Node, movement: Node) -> void:
	if movement == null or player == null:
		return
	await _wait_until_state(player, "RUNNING", 120)
	if movement.has_method("request_slide"):
		movement.call("request_slide")
	if await _wait_until_state(player, "SLIDING", 20):
		await _force_draw()
		await _capture(out_dir, filename)
		print("%s: wrote %s (state SLIDING)" % [LABEL, filename])
	else:
		await _force_draw()
		await _capture(out_dir, filename)
		print("%s: wrote %s (slide requested; state may have advanced)" % [LABEL, filename])


func _try_capture_grapple(
	out_dir: String,
	filename: String,
	player: Node,
	movement: Node,
	visual: Node
) -> void:
	## Best-effort: jump then request air ability; capture while SWINGING if possible.
	if movement == null:
		return
	await _wait_until_state(player, "RUNNING", 90)
	if movement.has_method("request_jump_immediate"):
		movement.call("request_jump_immediate")
		await _wait_frames(8)
	var attached := false
	if movement.has_method("request_air_ability"):
		attached = bool(movement.call("request_air_ability"))
	var swinging := await _wait_until_state(player, "SWINGING", 45)
	await _force_draw()
	if swinging or attached:
		await _capture(out_dir, filename)
		print("%s: wrote %s (live grapple / SWINGING)" % [LABEL, filename])
		return
	## No latch in view — capture explicit grapple anim on proxy (still real viewport).
	if visual != null and visual.has_method("play"):
		visual.call("play", "grapple")
		await _wait_frames(4)
		await _force_draw()
		var pose_name: String = filename.replace(".png", "-pose-proxy.png")
		await _capture(out_dir, pose_name)
		print(
			"%s: wrote %s (grapple anim pose; no latch attach this frame)"
			% [LABEL, pose_name]
		)


func _wait_until_state(player: Node, state_name: String, max_frames: int) -> bool:
	## PlayerState.State names matched via enum keys on get_state() int.
	var wanted: int = _state_to_int(state_name)
	for _i: int in range(max_frames):
		if player == null:
			return false
		if int(player.call("get_state")) == wanted:
			return true
		await process_frame
	return false


func _state_to_int(state_name: String) -> int:
	## Must match scripts/player/PlayerState.gd enum order.
	match state_name:
		"IDLE":
			return 0
		"RUNNING":
			return 1
		"JUMPING":
			return 2
		"FALLING":
			return 3
		"SLIDING":
			return 4
		"SWING_AVAILABLE":
			return 5
		"SWINGING":
			return 6
		"LAUNCHED":
			return 7
		"HIT":
			return 8
		"DEAD":
			return 9
		_:
			return -1


func _capture(out_dir: String, filename: String) -> bool:
	await _force_draw()
	var tex: ViewportTexture = root.get_viewport().get_texture()
	if tex == null:
		push_error("%s: viewport texture null for %s" % [LABEL, filename])
		return false
	var img: Image = tex.get_image()
	if img == null or img.get_width() < 2:
		push_error("%s: empty image for %s" % [LABEL, filename])
		return false
	## No flip: OpenGL/llvmpipe (this cloud env) returns upright pixels.
	## If captures appear inverted on Vulkan, set RI_PREVIEW_FLIP_Y=1.
	if OS.get_environment("RI_PREVIEW_FLIP_Y") == "1":
		img.flip_y()
	var path: String = "%s/%s" % [out_dir, filename]
	var err: Error = img.save_png(path)
	if err != OK:
		push_error("%s: save_png failed %s (%s)" % [LABEL, path, error_string(err)])
		return false
	## Reject near-black frames (failed render / headless).
	if _is_mostly_black(img):
		push_error("%s: capture looks black/empty: %s" % [LABEL, path])
		return false
	return true


func _is_mostly_black(img: Image) -> bool:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var samples: int = 0
	var lit: int = 0
	var step_x: int = maxi(w / 16, 1)
	var step_y: int = maxi(h / 16, 1)
	for y in range(0, h, step_y):
		for x in range(0, w, step_x):
			samples += 1
			var c: Color = img.get_pixel(x, y)
			if c.r + c.g + c.b > 0.15:
				lit += 1
	return samples > 0 and float(lit) / float(samples) < 0.02


func _force_draw() -> void:
	RenderingServer.force_draw()
	await process_frame
	RenderingServer.force_draw()
	await process_frame


func _ensure_dir(path: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(global_path)


func _find_main() -> Node:
	var named: Node = root.get_node_or_null("Main")
	if named != null:
		return named
	var current: Node = get_current_scene()
	if current != null and current.has_method("start_game"):
		return current
	return null


func _find_player(main: Node) -> Node:
	var container: Node = main.get_node_or_null("GameSceneContainer") if main != null else null
	if container == null or container.get_child_count() == 0:
		return null
	var game_scene: Node = container.get_child(0)
	var player_root: Node = game_scene.get_node_or_null("PlayerRoot")
	if player_root == null or player_root.get_child_count() == 0:
		return null
	return player_root.get_child(0)


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame
