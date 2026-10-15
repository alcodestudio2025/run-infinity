extends SceneTree

## Record real AnimatedSprite2D cycles for Kai/Nova (OpenGL, NOT --headless).
##   DISPLAY=:1 godot --path . --fixed-fps 30 -s res://scripts/ci/m6_1_c_anim_record.gd
## Writes PNG sequences under docs/previews/m6-1-c/raw/{id}/{anim}/

const LABEL := "M6.1-C anim record"
const OUT_ROOT := "res://docs/previews/m6-1-c/raw"
const IDS := ["kai", "nova"]
const ANIMS := ["idle", "run", "jump", "fall", "land", "slide", "grapple", "hit"]
const CANVAS := Vector2i(256, 256)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(512, 512))

	## Pure Node2D world — Controls would paint over Sprite2D.
	var world := Node2D.new()
	world.name = "AnimWorld"
	root.add_child(world)

	var camera := Camera2D.new()
	camera.position = Vector2(0, -40)
	camera.make_current()
	world.add_child(camera)

	## Background quad behind the character.
	var bg := Polygon2D.new()
	bg.color = Color(0.18, 0.18, 0.2, 1.0)
	bg.polygon = PackedVector2Array([
		Vector2(-300, -300), Vector2(300, -300), Vector2(300, 300), Vector2(-300, 300)
	])
	bg.z_index = -10
	world.add_child(bg)

	var animated := AnimatedSprite2D.new()
	animated.name = "AnimatedSprite2D"
	animated.centered = true
	animated.offset = Vector2(0.0, -48.0)
	animated.scale = Vector2(3.0, 3.0)
	animated.z_index = 1
	world.add_child(animated)

	## Ground line for foot reference.
	var ground := Line2D.new()
	ground.width = 2.0
	ground.default_color = Color(0.25, 0.55, 0.3, 1.0)
	ground.points = PackedVector2Array([Vector2(-200, 0), Vector2(200, 0)])
	ground.z_index = 0
	world.add_child(ground)

	await process_frame
	await process_frame
	await _force_draw()

	for id: String in IDS:
		var path := "res://assets/sprites/characters/%s/sprite_frames.tres" % id
		if not ResourceLoader.exists(path):
			push_error("%s: missing %s" % [LABEL, path])
			quit(1)
			return
		var frames: SpriteFrames = load(path) as SpriteFrames
		if frames == null:
			push_error("%s: load failed %s" % [LABEL, path])
			quit(1)
			return
		animated.sprite_frames = frames

		for anim: String in ANIMS:
			if not frames.has_animation(anim) or frames.get_frame_count(anim) < 1:
				push_error("%s: %s missing %s" % [LABEL, id, anim])
				quit(1)
				return
			var out_dir := "%s/%s/%s" % [OUT_ROOT, id, anim]
			_ensure_dir(out_dir)
			## Clear previous captures.
			var abs_dir := ProjectSettings.globalize_path(out_dir)
			for fname: String in DirAccess.get_files_at(abs_dir):
				DirAccess.remove_absolute(abs_dir.path_join(fname))

			var count: int = frames.get_frame_count(anim)
			## Discrete frames from SpriteFrames (Godot textures).
			for i: int in range(count):
				animated.animation = anim
				animated.frame = i
				animated.pause()
				await process_frame
				await _force_draw()
				var fname := "%s/frame_%02d.png" % [out_dir, i]
				if not await _capture_viewport(fname):
					push_error("%s: capture failed %s" % [LABEL, fname])
					quit(1)
					return
				## Sanity: reject solid-color captures.
				if not _png_has_variance(fname):
					push_error("%s: capture looks empty/solid %s" % [LABEL, fname])
					quit(1)
					return

			## Played cycle (AnimatedSprite2D advancing).
			animated.play(anim)
			var play_n: int = maxi(count * 3, 10)
			for i: int in range(play_n):
				await process_frame
				await _force_draw()
				var fname2 := "%s/play_%02d.png" % [out_dir, i]
				await _capture_viewport(fname2)
			print("%s: recorded %s/%s count=%d" % [LABEL, id, anim, count])

	print("%s PASS" % LABEL)
	quit(0)


func _ensure_dir(res_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(res_path))


func _force_draw() -> void:
	RenderingServer.viewport_set_update_mode(
		root.get_viewport().get_viewport_rid(),
		RenderingServer.VIEWPORT_UPDATE_ALWAYS
	)
	RenderingServer.force_draw(true)
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame


func _capture_viewport(res_path: String) -> bool:
	var vp := root.get_viewport()
	if vp == null:
		return false
	var img: Image = vp.get_texture().get_image()
	if img == null:
		return false
	var w: int = img.get_width()
	var h: int = img.get_height()
	var side: int = mini(w, h)
	var x0: int = int((w - side) / 2.0)
	var y0: int = int((h - side) / 2.0)
	img = img.get_region(Rect2i(x0, y0, side, side))
	img.resize(CANVAS.x, CANVAS.y, Image.INTERPOLATE_BILINEAR)
	return img.save_png(ProjectSettings.globalize_path(res_path)) == OK


func _png_has_variance(res_path: String) -> bool:
	var img := Image.load_from_file(ProjectSettings.globalize_path(res_path))
	if img == null:
		return false
	var c0: Color = img.get_pixel(0, 0)
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			if img.get_pixel(x, y) != c0:
				return true
	return false
