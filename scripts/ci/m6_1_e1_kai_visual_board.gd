extends SceneTree

## M6.1-E.1 — Kai RUN Frame 00 visual evaluation boards (OpenGL, not --headless).
## Same scale + feet-aligned compare; 4×/8× nearest enlargements; light/dark/checker;
## Android-landscape gameplay-size still. No beauty filters.
##   DISPLAY=:1 godot --path . --fixed-fps 30 -s res://scripts/ci/m6_1_e1_kai_visual_board.gd

const LABEL := "M6.1-E.1 Kai visual board"
const LIVE := "res://assets/sprites/characters/kai/frames/run_00.png"
const EXP := "res://assets/sprites/characters/_experimental/kai/run_frame00/preview_64x96.png"
const EXP_HI := "res://assets/sprites/characters/_experimental/kai/run_frame00/package/00.png"
const OUT := "res://docs/previews/m6-1-e1"
const DISPLAY_SCALE := 1.75
const CANONICAL := Vector2(64, 96)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))

	var world := Node2D.new()
	world.name = "BoardWorld"
	root.add_child(world)

	var camera := Camera2D.new()
	camera.position = Vector2(0, -80)
	world.add_child(camera)
	camera.make_current()

	_ensure_dir(OUT)

	var live_tex: Texture2D = load(LIVE) as Texture2D
	var exp_tex: Texture2D = load(EXP) as Texture2D
	var exp_hi: Texture2D = load(EXP_HI) as Texture2D
	if live_tex == null or exp_tex == null or exp_hi == null:
		push_error("%s: missing textures" % LABEL)
		quit(1)
		return

	## --- 1) Same-scale feet-aligned comparative board ---
	await _clear_world(world, camera)
	_add_solid_bg(world, Color(0.18, 0.18, 0.2, 1.0), 600)
	_add_ground(world, 0.0, Color(0.2, 0.75, 0.35, 1.0))
	var live_s := _feet_sprite(live_tex, Vector2(-90, 0), 3.0)
	var exp_s := _feet_sprite(exp_tex, Vector2(90, 0), 3.0)
	world.add_child(live_s)
	world.add_child(exp_s)
	await _settle()
	await _capture("%s/01_compare_same_scale_feet.png" % OUT, Vector2i(960, 540))

	## --- 2) 4× nearest enlargements (side by side, feet aligned) ---
	await _clear_world(world, camera)
	_add_solid_bg(world, Color(0.18, 0.18, 0.2, 1.0), 900)
	_add_ground(world, 0.0, Color(0.2, 0.75, 0.35, 1.0))
	world.add_child(_feet_sprite(live_tex, Vector2(-140, 0), 4.0))
	world.add_child(_feet_sprite(exp_tex, Vector2(140, 0), 4.0))
	camera.position = Vector2(0, -120)
	await _settle()
	await _capture("%s/02_enlarge_4x_nearest.png" % OUT, Vector2i(1280, 720))

	## --- 3) 8× nearest ---
	await _clear_world(world, camera)
	_add_solid_bg(world, Color(0.18, 0.18, 0.2, 1.0), 1400)
	_add_ground(world, 0.0, Color(0.2, 0.75, 0.35, 1.0))
	## One character at a time for readable 8× crops — live then exp composited via two shots.
	world.add_child(_feet_sprite(live_tex, Vector2(0, 0), 8.0))
	camera.position = Vector2(0, -200)
	await _settle()
	await _capture("%s/03a_enlarge_8x_live_nearest.png" % OUT, Vector2i(1024, 1024))
	await _clear_world(world, camera)
	_add_solid_bg(world, Color(0.18, 0.18, 0.2, 1.0), 1400)
	_add_ground(world, 0.0, Color(0.2, 0.75, 0.35, 1.0))
	world.add_child(_feet_sprite(exp_tex, Vector2(0, 0), 8.0))
	camera.position = Vector2(0, -200)
	await _settle()
	await _capture("%s/03b_enlarge_8x_experimental_nearest.png" % OUT, Vector2i(1024, 1024))

	## --- 4) Background stress: light / dark / checker (experimental + live) ---
	for pair: Array in [
		["04a_bg_light_experimental.png", Color(0.92, 0.92, 0.9, 1.0), exp_tex],
		["04b_bg_dark_experimental.png", Color(0.08, 0.08, 0.1, 1.0), exp_tex],
		["04c_bg_light_live.png", Color(0.92, 0.92, 0.9, 1.0), live_tex],
		["04d_bg_dark_live.png", Color(0.08, 0.08, 0.1, 1.0), live_tex],
	]:
		await _clear_world(world, camera)
		_add_solid_bg(world, pair[1], 700)
		_add_ground(world, 0.0, Color(0.15, 0.55, 0.25, 1.0))
		world.add_child(_feet_sprite(pair[2], Vector2(0, 0), 4.0))
		camera.position = Vector2(0, -120)
		await _settle()
		await _capture("%s/%s" % [OUT, pair[0]], Vector2i(768, 768))

	await _clear_world(world, camera)
	_add_checker_bg(world, 32, 700)
	_add_ground(world, 0.0, Color(0.9, 0.2, 0.2, 1.0))
	world.add_child(_feet_sprite(exp_tex, Vector2(0, 0), 4.0))
	camera.position = Vector2(0, -120)
	await _settle()
	await _capture("%s/04e_bg_checker_experimental.png" % OUT, Vector2i(768, 768))

	await _clear_world(world, camera)
	_add_checker_bg(world, 32, 700)
	_add_ground(world, 0.0, Color(0.9, 0.2, 0.2, 1.0))
	world.add_child(_feet_sprite(live_tex, Vector2(0, 0), 4.0))
	camera.position = Vector2(0, -120)
	await _settle()
	await _capture("%s/04f_bg_checker_live.png" % OUT, Vector2i(768, 768))

	## --- 5) Android landscape gameplay size (1920×1080, DISPLAY_SCALE 1.75) ---
	await _clear_world(world, camera)
	camera.position = Vector2(960, 540)
	_add_solid_bg_rect(world, Color(0.12, 0.14, 0.18, 1.0), Rect2(0, 0, 1920, 1080))
	## Fake ground near bottom third (runner lane).
	var lane_y := 780.0
	var lane := Line2D.new()
	lane.width = 3.0
	lane.default_color = Color(0.25, 0.6, 0.35, 1.0)
	lane.points = PackedVector2Array([Vector2(0, lane_y), Vector2(1920, lane_y)])
	world.add_child(lane)
	## Place both at gameplay scale, feet on lane, spaced.
	var live_g := _feet_sprite(live_tex, Vector2(720, lane_y), DISPLAY_SCALE)
	var exp_g := _feet_sprite(exp_tex, Vector2(1200, lane_y), DISPLAY_SCALE)
	world.add_child(live_g)
	world.add_child(exp_g)
	await _settle()
	await _capture_full("%s/05_android_landscape_gameplay_scale.png" % OUT, Vector2i(1920, 1080))

	## --- 6) Hi-res experimental 128×192 nearest 4× for edge audit ---
	await _clear_world(world, camera)
	_add_checker_bg(world, 16, 900)
	var hi := Sprite2D.new()
	hi.texture = exp_hi
	hi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hi.centered = true
	## Feet of 128×192: use alpha foot align.
	hi.offset = Vector2(0, -_foot_offset_y(exp_hi))
	hi.position = Vector2(0, 0)
	hi.scale = Vector2(4, 4)
	world.add_child(hi)
	_add_ground(world, 0.0, Color(0.9, 0.2, 0.2, 1.0))
	camera.position = Vector2(0, -200)
	await _settle()
	await _capture("%s/06_experimental_128_x4_checker.png" % OUT, Vector2i(1024, 1280))

	print("%s PASS" % LABEL)
	quit(0)


func _feet_sprite(tex: Texture2D, feet_pos: Vector2, scale: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	## Offset so the bottom opaque band sits on feet_pos.y when scale applied.
	var foot_local_y := _foot_offset_y(tex)
	s.offset = Vector2(0, -foot_local_y)
	s.position = feet_pos
	s.scale = Vector2(scale, scale)
	s.z_index = 2
	return s


func _foot_offset_y(tex: Texture2D) -> float:
	## Distance from texture center to bottom opaque row (centered sprite space).
	var img: Image = tex.get_image()
	if img == null:
		return tex.get_height() * 0.5
	var w: int = img.get_width()
	var h: int = img.get_height()
	var bottom := -1
	for y in range(h - 1, -1, -1):
		for x in range(w):
			if img.get_pixel(x, y).a >= 0.2:
				bottom = y
				break
		if bottom >= 0:
			break
	if bottom < 0:
		return h * 0.5
	## Centered: center at h/2; bottom pixel is at (bottom+0.5) from top.
	return float(bottom) + 0.5 - float(h) * 0.5


func _add_solid_bg(world: Node2D, color: Color, half: float) -> void:
	var bg := Polygon2D.new()
	bg.color = color
	bg.polygon = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)
	])
	bg.z_index = -20
	world.add_child(bg)


func _add_solid_bg_rect(world: Node2D, color: Color, rect: Rect2) -> void:
	var bg := Polygon2D.new()
	bg.color = color
	bg.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
	])
	bg.z_index = -20
	world.add_child(bg)


func _add_checker_bg(world: Node2D, cell: int, half: float) -> void:
	var origin := -half
	var n: int = int((half * 2.0) / float(cell)) + 2
	for iy in range(n):
		for ix in range(n):
			var light: bool = ((ix + iy) % 2) == 0
			var c := Color(0.85, 0.85, 0.85, 1.0) if light else Color(0.45, 0.45, 0.48, 1.0)
			var x0 := origin + ix * cell
			var y0 := origin + iy * cell
			var tile := Polygon2D.new()
			tile.color = c
			tile.polygon = PackedVector2Array([
				Vector2(x0, y0), Vector2(x0 + cell, y0),
				Vector2(x0 + cell, y0 + cell), Vector2(x0, y0 + cell)
			])
			tile.z_index = -20
			world.add_child(tile)


func _add_ground(world: Node2D, y: float, color: Color) -> void:
	var ground := Line2D.new()
	ground.width = 2.0
	ground.default_color = color
	ground.points = PackedVector2Array([Vector2(-500, y), Vector2(500, y)])
	ground.z_index = 1
	world.add_child(ground)


func _clear_world(world: Node2D, camera: Camera2D) -> void:
	for c in world.get_children():
		if c == camera:
			continue
		world.remove_child(c)
		c.free()
	await process_frame


func _settle() -> void:
	await process_frame
	await process_frame
	RenderingServer.viewport_set_update_mode(
		root.get_viewport().get_viewport_rid(),
		RenderingServer.VIEWPORT_UPDATE_ALWAYS
	)
	RenderingServer.force_draw(true)
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame


func _capture(res_path: String, size: Vector2i) -> void:
	var vp := root.get_viewport()
	var img: Image = vp.get_texture().get_image()
	if img == null:
		push_error("%s: null image %s" % [LABEL, res_path])
		quit(1)
		return
	## Center square-ish crop then resize — keep proportions of requested size via letterbox crop.
	var w: int = img.get_width()
	var h: int = img.get_height()
	var target_aspect: float = float(size.x) / float(size.y)
	var src_aspect: float = float(w) / float(h)
	var rw: int
	var rh: int
	if src_aspect > target_aspect:
		rh = h
		rw = int(h * target_aspect)
	else:
		rw = w
		rh = int(w / target_aspect)
	var x0: int = int((w - rw) / 2.0)
	var y0: int = int((h - rh) / 2.0)
	img = img.get_region(Rect2i(x0, y0, rw, rh))
	## Nearest resize to avoid softening defect evidence.
	img.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	if img.save_png(ProjectSettings.globalize_path(res_path)) != OK:
		push_error("%s: save failed %s" % [LABEL, res_path])
		quit(1)
		return
	print("%s wrote %s" % [LABEL, res_path])


func _capture_full(res_path: String, size: Vector2i) -> void:
	var vp := root.get_viewport()
	var img: Image = vp.get_texture().get_image()
	if img == null:
		push_error("%s: null image %s" % [LABEL, res_path])
		quit(1)
		return
	img.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	if img.save_png(ProjectSettings.globalize_path(res_path)) != OK:
		push_error("%s: save failed %s" % [LABEL, res_path])
		quit(1)
		return
	print("%s wrote %s" % [LABEL, res_path])


func _ensure_dir(res_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(res_path))
