extends SceneTree

## M6.1-E.2 — Kai canon approval previews (OpenGL). Does not touch live sprites.
##   DISPLAY=:1 godot --path . --fixed-fps 30 -s res://scripts/ci/m6_1_e2_kai_canon_preview.gd

const LABEL := "M6.1-E.2 Kai canon preview"
const LIVE := "res://assets/sprites/characters/kai/frames/run_00.png"
const EXP64 := "res://assets/sprites/characters/_experimental/kai/run_frame00/preview_64x96.png"
const EXP128 := "res://assets/sprites/characters/_experimental/kai/run_frame00/package/00.png"
const OUT := "res://docs/previews/m6-1-e2"
const DISPLAY_SCALE := 1.75


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var world := Node2D.new()
	root.add_child(world)
	var camera := Camera2D.new()
	world.add_child(camera)
	camera.make_current()
	_ensure_dir(OUT)

	var live_tex: Texture2D = load(LIVE) as Texture2D
	var exp64: Texture2D = load(EXP64) as Texture2D
	var exp128: Texture2D = load(EXP128) as Texture2D
	if live_tex == null or exp64 == null or exp128 == null:
		push_error("%s: missing textures" % LABEL)
		quit(1)
		return

	## A) Gameplay-size compare (live vs candidate) on 1920×1080
	await _clear(world, camera)
	camera.position = Vector2(960, 540)
	_bg_rect(world, Color(0.11, 0.12, 0.15, 1.0), Rect2(0, 0, 1920, 1080))
	var lane := 780.0
	_ground(world, lane, Color(0.25, 0.7, 0.35, 1.0), 0, 1920)
	world.add_child(_feet(live_tex, Vector2(700, lane), DISPLAY_SCALE))
	world.add_child(_feet(exp64, Vector2(1220, lane), DISPLAY_SCALE))
	await _settle()
	await _capture_full("%s/01_gameplay_size_live_vs_candidate.png" % OUT, Vector2i(1920, 1080))

	## B) Candidate reference plate: 128 source + 64 game cell + pivot + silhouette box
	await _clear(world, camera)
	camera.position = Vector2(0, -80)
	_bg(world, Color(0.16, 0.17, 0.2, 1.0), 900)
	_ground(world, 0.0, Color(0.9, 0.25, 0.25, 1.0), -500, 500)
	## 128×192 at 2× (feet aligned)
	var hi := _feet(exp128, Vector2(-160, 0), 2.0)
	world.add_child(hi)
	## 64×96 at 4× (same visual height target ≈ 192*2 vs 96*4)
	var lo := _feet(exp64, Vector2(160, 0), 4.0)
	world.add_child(lo)
	## Pivot cross at ground origin under each
	_cross(world, Vector2(-160, 0), Color(0.3, 0.85, 1.0, 1.0))
	_cross(world, Vector2(160, 0), Color(0.3, 0.85, 1.0, 1.0))
	## Canonical canvas guides (64×96 at 4× = 256×384) around right sprite
	_rect_outline(world, Rect2(160 - 128, -384, 256, 384), Color(1.0, 0.85, 0.2, 0.9))
	await _settle()
	await _capture("%s/02_candidate_pivot_canvas_guide.png" % OUT, Vector2i(1280, 800))

	## C) Future-frame template: candidate silhouette + empty slots markers
	await _clear(world, camera)
	camera.position = Vector2(0, -60)
	_bg(world, Color(0.14, 0.15, 0.18, 1.0), 1100)
	_ground(world, 0.0, Color(0.25, 0.7, 0.35, 1.0), -600, 600)
	## Center candidate as master (scale 3)
	world.add_child(_feet(exp64, Vector2(0, 0), 3.0))
	_cross(world, Vector2(0, 0), Color(0.3, 0.85, 1.0, 1.0))
	_rect_outline(world, Rect2(-96, -288, 192, 288), Color(1.0, 0.85, 0.2, 0.85))
	## Six slot boxes for RUN 00-05 (00 filled conceptually by candidate)
	var slots := [-450, -270, -90, 90, 270, 450]
	for i in range(slots.size()):
		var x: float = slots[i]
		_rect_outline(world, Rect2(x - 40, -140, 80, 120), Color(0.55, 0.6, 0.7, 0.9))
		if i == 0:
			var mini := _feet(exp64, Vector2(x, 0), 1.0)
			world.add_child(mini)
	await _settle()
	await _capture("%s/03_future_run_frame_template.png" % OUT, Vector2i(1400, 700))

	## D) Silhouette readability: candidate solid-ish on light + dark (no filters)
	await _clear(world, camera)
	camera.position = Vector2(0, -100)
	_bg(world, Color(0.92, 0.92, 0.9, 1.0), 700)
	_ground(world, 0.0, Color(0.2, 0.55, 0.3, 1.0), -400, 400)
	world.add_child(_feet(exp64, Vector2(0, 0), 4.0))
	await _settle()
	await _capture("%s/04_candidate_silhouette_light.png" % OUT, Vector2i(768, 768))

	await _clear(world, camera)
	camera.position = Vector2(0, -100)
	_bg(world, Color(0.07, 0.07, 0.09, 1.0), 700)
	_ground(world, 0.0, Color(0.2, 0.55, 0.3, 1.0), -400, 400)
	world.add_child(_feet(exp64, Vector2(0, 0), 4.0))
	await _settle()
	await _capture("%s/05_candidate_silhouette_dark.png" % OUT, Vector2i(768, 768))

	print("%s PASS" % LABEL)
	quit(0)


func _feet(tex: Texture2D, feet_pos: Vector2, scale: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	s.offset = Vector2(0, -_foot_offset_y(tex))
	s.position = feet_pos
	s.scale = Vector2(scale, scale)
	s.z_index = 2
	return s


func _foot_offset_y(tex: Texture2D) -> float:
	var img: Image = tex.get_image()
	if img == null:
		return tex.get_height() * 0.5
	var w := img.get_width()
	var h := img.get_height()
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
	return float(bottom) + 0.5 - float(h) * 0.5


func _cross(world: Node2D, origin: Vector2, color: Color) -> void:
	var h := Line2D.new()
	h.width = 2.0
	h.default_color = color
	h.points = PackedVector2Array([origin + Vector2(-18, 0), origin + Vector2(18, 0)])
	h.z_index = 5
	world.add_child(h)
	var v := Line2D.new()
	v.width = 2.0
	v.default_color = color
	v.points = PackedVector2Array([origin + Vector2(0, -18), origin + Vector2(0, 18)])
	v.z_index = 5
	world.add_child(v)


func _rect_outline(world: Node2D, r: Rect2, color: Color) -> void:
	var l := Line2D.new()
	l.width = 2.0
	l.default_color = color
	l.closed = true
	l.points = PackedVector2Array([
		r.position,
		r.position + Vector2(r.size.x, 0),
		r.position + r.size,
		r.position + Vector2(0, r.size.y),
	])
	l.z_index = 4
	world.add_child(l)


func _bg(world: Node2D, color: Color, half: float) -> void:
	var bg := Polygon2D.new()
	bg.color = color
	bg.polygon = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)
	])
	bg.z_index = -20
	world.add_child(bg)


func _bg_rect(world: Node2D, color: Color, rect: Rect2) -> void:
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


func _ground(world: Node2D, y: float, color: Color, x0: float, x1: float) -> void:
	var g := Line2D.new()
	g.width = 2.0
	g.default_color = color
	g.points = PackedVector2Array([Vector2(x0, y), Vector2(x1, y)])
	g.z_index = 1
	world.add_child(g)


func _clear(world: Node2D, camera: Camera2D) -> void:
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


func _capture(path: String, size: Vector2i) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var aspect := float(size.x) / float(size.y)
	var rw: int
	var rh: int
	if float(w) / float(h) > aspect:
		rh = h
		rw = int(h * aspect)
	else:
		rw = w
		rh = int(w / aspect)
	img = img.get_region(Rect2i(int((w - rw) / 2.0), int((h - rh) / 2.0), rw, rh))
	img.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(path))
	print("%s wrote %s" % [LABEL, path])


func _capture_full(path: String, size: Vector2i) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(path))
	print("%s wrote %s" % [LABEL, path])


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
