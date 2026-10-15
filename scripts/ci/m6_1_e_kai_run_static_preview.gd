extends SceneTree

## M6.1-E: capture experimental Kai RUN frame 00 as a static Godot preview.
## Does NOT modify gameplay SpriteFrames. OpenGL required (not --headless).
##   DISPLAY=:1 godot --path . --fixed-fps 30 -s res://scripts/ci/m6_1_e_kai_run_static_preview.gd

const LABEL := "M6.1-E Kai RUN static preview"
const SRC := "res://assets/sprites/characters/_experimental/kai/run_frame00/preview_64x96.png"
const SRC_HI := "res://assets/sprites/characters/_experimental/kai/run_frame00/package/00.png"
const LIVE_RUN0 := "res://assets/sprites/characters/kai/frames/run_00.png"
const OUT_DIR := "res://docs/previews/m6-1-e"
const CANVAS := Vector2i(512, 288)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1024, 576))

	var world := Node2D.new()
	world.name = "PreviewWorld"
	root.add_child(world)

	var camera := Camera2D.new()
	camera.position = Vector2(0, -20)
	world.add_child(camera)
	camera.make_current()

	var bg := Polygon2D.new()
	bg.color = Color(0.16, 0.16, 0.18, 1.0)
	bg.polygon = PackedVector2Array([
		Vector2(-400, -300), Vector2(400, -300), Vector2(400, 300), Vector2(-400, 300)
	])
	bg.z_index = -10
	world.add_child(bg)

	var ground := Line2D.new()
	ground.width = 2.0
	ground.default_color = Color(0.25, 0.55, 0.3, 1.0)
	ground.points = PackedVector2Array([Vector2(-220, 0), Vector2(220, 0)])
	world.add_child(ground)

	## Left: live gameplay run_00. Right: experimental preview (whole-canvas 64x96).
	var live := _make_sprite(LIVE_RUN0, Vector2(-90, -48), 3.0)
	world.add_child(live)
	var exp := _make_sprite(SRC, Vector2(90, -48), 3.0)
	world.add_child(exp)

	## Tiny labels via Polygon markers (no Control overlay bleed).
	var live_tag := _make_sprite(LIVE_RUN0, Vector2(-90, 40), 0.01)  # placeholder kept light
	live_tag.visible = false
	world.add_child(live_tag)

	await process_frame
	await process_frame
	await _force_draw()

	_ensure_dir(OUT_DIR)
	var compare_path := "%s/kai_run_live_vs_experimental.png" % OUT_DIR
	if not await _capture_viewport(compare_path, CANVAS):
		push_error("%s: compare capture failed" % LABEL)
		quit(1)
		return

	## Solo experimental at larger scale for debt review.
	live.visible = false
	exp.position = Vector2(0, -48)
	exp.scale = Vector2(4.0, 4.0)
	await process_frame
	await _force_draw()
	var solo := "%s/kai_run_experimental_frame00.png" % OUT_DIR
	if not await _capture_viewport(solo, Vector2i(384, 384)):
		push_error("%s: solo capture failed" % LABEL)
		quit(1)
		return

	## Also dump source 128x192 as Godot-loaded texture still (sanity).
	var hi := Sprite2D.new()
	var tex_hi: Texture2D = load(SRC_HI) as Texture2D
	if tex_hi == null:
		push_error("%s: missing %s" % [LABEL, SRC_HI])
		quit(1)
		return
	hi.texture = tex_hi
	hi.centered = true
	hi.position = Vector2(0, -20)
	hi.scale = Vector2(2.0, 2.0)
	exp.visible = false
	world.add_child(hi)
	await process_frame
	await _force_draw()
	var hi_out := "%s/kai_run_experimental_frame00_128.png" % OUT_DIR
	if not await _capture_viewport(hi_out, Vector2i(384, 512)):
		push_error("%s: hi capture failed" % LABEL)
		quit(1)
		return

	print("%s PASS (static preview only; gameplay RUN untouched)" % LABEL)
	quit(0)


func _make_sprite(path: String, pos: Vector2, scale: float) -> Sprite2D:
	var s := Sprite2D.new()
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_error("%s: missing texture %s" % [LABEL, path])
		quit(1)
		return s
	s.texture = tex
	s.centered = true
	s.offset = Vector2(0, 0)
	## Feet-ish: textures are already foot-bottom authored; offset up by half height visually via position.
	s.position = pos
	s.scale = Vector2(scale, scale)
	s.z_index = 1
	return s


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


func _capture_viewport(res_path: String, size: Vector2i) -> bool:
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
	img.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	return img.save_png(ProjectSettings.globalize_path(res_path)) == OK
