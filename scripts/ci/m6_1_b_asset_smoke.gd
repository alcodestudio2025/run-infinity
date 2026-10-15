extends SceneTree

## Headless M6.1-B: SpriteFrames present for kai/nova; no proxy in normal path.
## Usage: source scripts/ci/smoke_env.sh && ri_smoke_env_setup && \
##   godot --headless --path . --fixed-fps 60 -s res://scripts/ci/m6_1_b_asset_smoke.gd

const Guard := preload("res://scripts/ci/smoke_userdata_guard.gd")
const Catalog := preload("res://scripts/characters/CharacterCatalog.gd")

const LABEL := "M6.1-B asset smoke"
const WARMUP: int = 60
const POST: int = 40


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Guard.require_isolated(self, LABEL):
		return

	for id: String in Catalog.all_ids():
		var path: String = Catalog.get_definition(id).sprite_frames_path
		if not ResourceLoader.exists(path):
			push_error("%s: missing SpriteFrames %s" % [LABEL, path])
			quit(1)
			return
		var frames: SpriteFrames = load(path) as SpriteFrames
		if frames == null:
			push_error("%s: failed to load %s" % [LABEL, path])
			quit(1)
			return
		for anim: String in Catalog.all_anims():
			if not frames.has_animation(anim) or frames.get_frame_count(anim) < 1:
				push_error("%s: %s missing anim %s" % [LABEL, id, anim])
				quit(1)
				return
		print("%s: R0 PASS %s frames OK" % [LABEL, id])

	var err: Error = change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("%s: Main load failed." % LABEL)
		quit(1)
		return
	await _wait_frames(WARMUP)

	var main: Node = root.get_node_or_null("Main")
	var gsm: Node = root.get_node_or_null("GameStateManager")
	var save_manager: Node = root.get_node_or_null("SaveManager")
	if main == null or gsm == null or save_manager == null:
		push_error("%s: autoloads/Main missing." % LABEL)
		quit(1)
		return

	for id: String in ["kai", "nova"]:
		save_manager.call("set_selected_character_id", id)
		## Boot into play via title → select confirm path.
		if int(gsm.get("current_state")) != 1:
			## Restart scene between characters for clean state.
			err = change_scene_to_file("res://scenes/Main.tscn")
			if err != OK:
				quit(1)
				return
			await _wait_frames(WARMUP)
			main = root.get_node_or_null("Main")
			gsm = root.get_node_or_null("GameStateManager")
			save_manager = root.get_node_or_null("SaveManager")
			save_manager.call("set_selected_character_id", id)

		var title: Node = main.get_node_or_null("TitleScreen")
		title.emit_signal("play_pressed")
		await _wait_frames(8)
		var select: Node = main.get_node_or_null("CharacterSelectionScreen")
		if select != null and select.has_method("_select"):
			select.call("_select", id)
		select.emit_signal("character_confirmed", id)
		await _wait_frames(POST)

		var container: Node = main.get_node_or_null("GameSceneContainer")
		var game_scene: Node = container.get_child(0) if container and container.get_child_count() > 0 else null
		var player: Node = null
		if game_scene != null:
			var root_player: Node = game_scene.get_node_or_null("PlayerRoot")
			if root_player != null:
				for child: Node in root_player.get_children():
					if child.has_method("is_alive"):
						player = child
						break
		var visual: Node = player.get_node_or_null("CharacterVisual") if player else null
		if visual == null:
			push_error("%s: CharacterVisual missing for %s" % [LABEL, id])
			quit(1)
			return
		if str(visual.get("character_id")) != id:
			push_error("%s: character_id=%s expected %s" % [LABEL, visual.get("character_id"), id])
			quit(1)
			return
		if not bool(visual.call("is_using_sprite_frames")):
			push_error("%s: PROXY still active for %s — integration incomplete." % [LABEL, id])
			quit(1)
			return
		## Proxy nodes must be hidden on the normal path.
		var proxy: CanvasItem = visual.get_node_or_null("ProxyBody") as CanvasItem
		if proxy != null and proxy.visible:
			push_error("%s: ProxyBody visible for %s" % [LABEL, id])
			quit(1)
			return
		var animated: AnimatedSprite2D = visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if animated == null or not animated.visible:
			push_error("%s: AnimatedSprite2D not visible for %s" % [LABEL, id])
			quit(1)
			return
		print("%s: G1 PASS gameplay %s uses SpriteFrames (proxy hidden)" % [LABEL, id])

	print("%s PASS" % LABEL)
	quit(0)


func _wait_frames(n: int) -> void:
	for _i in range(maxi(n, 0)):
		await physics_frame
