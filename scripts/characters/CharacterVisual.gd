class_name CharacterVisual
extends Node2D

## Visual representation independent of Player collision / movement physics.
## Plays catalog anim names; falls back to colored proxy when frames are missing.

const LAND_HOLD_SEC: float = 0.12
## Canonical draw size for proxy + imported frames (pivot at feet / body origin).
const CANONICAL_SIZE: Vector2 = Vector2(64.0, 96.0)
## Visual-only upscale so 64×96 sheets read on 1920×1080 (does not touch hitboxes).
const DISPLAY_SCALE: float = 1.75

var character_id: String = CharacterCatalog.DEFAULT_ID
var current_anim: String = CharacterCatalog.ANIM_IDLE

var _definition: CharacterDefinition
var _animated: AnimatedSprite2D
var _proxy_body: ColorRect
var _proxy_accent: ColorRect
var _proxy_label: Label
var _using_frames: bool = false
var _sliding: bool = false
var _land_timer: float = 0.0
var _default_position: Vector2 = Vector2.ZERO
var _default_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_ensure_nodes()
	_default_position = position
	_default_scale = scale
	if character_id.is_empty():
		character_id = CharacterCatalog.DEFAULT_ID
	apply_character(character_id)
	play(CharacterCatalog.ANIM_IDLE)


func _process(delta: float) -> void:
	if _land_timer <= 0.0:
		return
	_land_timer = maxf(_land_timer - delta, 0.0)
	if _land_timer <= 0.0 and current_anim == CharacterCatalog.ANIM_LAND:
		play(CharacterCatalog.ANIM_RUN)


func apply_character(new_id: String) -> void:
	character_id = CharacterCatalog.normalize_id(new_id)
	_definition = CharacterCatalog.get_definition(character_id)
	_ensure_nodes()
	_using_frames = _try_load_sprite_frames(_definition.sprite_frames_path)
	_refresh_proxy_look()
	if _animated != null:
		_animated.visible = _using_frames
	if _proxy_body != null:
		_proxy_body.visible = not _using_frames
	if _proxy_accent != null:
		_proxy_accent.visible = not _using_frames
	if _proxy_label != null:
		_proxy_label.visible = not _using_frames
		_proxy_label.text = _definition.display_name
	## Re-apply current anim so frames/proxy stay in sync after swap.
	play(current_anim if not current_anim.is_empty() else CharacterCatalog.ANIM_IDLE)


func get_character_id() -> String:
	return character_id


func is_using_sprite_frames() -> bool:
	return _using_frames


func play(anim_name: String) -> void:
	var resolved: String = _resolve_anim(anim_name)
	if _sliding and resolved != CharacterCatalog.ANIM_SLIDE and resolved != CharacterCatalog.ANIM_HIT:
		## Slide pose owns the visual until cleared; ignore conflicting poses.
		return
	current_anim = resolved
	if _using_frames and _animated != null and _animated.sprite_frames != null:
		if _animated.sprite_frames.has_animation(resolved):
			if _animated.animation != resolved or not _animated.is_playing():
				_animated.play(resolved)
		elif _animated.sprite_frames.has_animation(CharacterCatalog.ANIM_IDLE):
			_animated.play(CharacterCatalog.ANIM_IDLE)
	_update_proxy_pose(resolved)


func on_player_state_changed(new_state: PlayerState.State, previous_state: PlayerState.State) -> void:
	match new_state:
		PlayerState.State.IDLE:
			play(CharacterCatalog.ANIM_IDLE)
		PlayerState.State.RUNNING:
			if (
				previous_state == PlayerState.State.FALLING
				or previous_state == PlayerState.State.JUMPING
				or previous_state == PlayerState.State.LAUNCHED
			):
				_land_timer = LAND_HOLD_SEC
				play(CharacterCatalog.ANIM_LAND)
			else:
				play(CharacterCatalog.ANIM_RUN)
		PlayerState.State.JUMPING:
			play(CharacterCatalog.ANIM_JUMP)
		PlayerState.State.FALLING, PlayerState.State.LAUNCHED:
			play(CharacterCatalog.ANIM_FALL)
		PlayerState.State.SLIDING:
			play(CharacterCatalog.ANIM_SLIDE)
		PlayerState.State.SWINGING:
			play(CharacterCatalog.ANIM_GRAPPLE)
		PlayerState.State.HIT, PlayerState.State.DEAD:
			play(CharacterCatalog.ANIM_HIT)
		PlayerState.State.SWING_AVAILABLE:
			play(CharacterCatalog.ANIM_RUN)
		_:
			play(CharacterCatalog.ANIM_IDLE)


func set_sliding(active: bool) -> void:
	_sliding = active
	if active:
		play(CharacterCatalog.ANIM_SLIDE)
		## Pose offset only — never touches CollisionShape2D.
		position = _default_position + Vector2(0.0, 18.0)
		scale = Vector2(_default_scale.x * 1.15, _default_scale.y * 0.55)
	else:
		position = _default_position
		scale = _default_scale
		if current_anim == CharacterCatalog.ANIM_SLIDE:
			play(CharacterCatalog.ANIM_RUN)


func set_standing() -> void:
	set_sliding(false)


func _ensure_nodes() -> void:
	if _animated == null:
		_animated = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if _animated == null:
			_animated = AnimatedSprite2D.new()
			_animated.name = "AnimatedSprite2D"
			add_child(_animated)
		_animated.centered = true
		_animated.offset = Vector2(0.0, -CANONICAL_SIZE.y * 0.5)
		_animated.scale = Vector2(DISPLAY_SCALE, DISPLAY_SCALE)
		_animated.visible = false

	if _proxy_body == null:
		_proxy_body = get_node_or_null("ProxyBody") as ColorRect
		if _proxy_body == null:
			_proxy_body = ColorRect.new()
			_proxy_body.name = "ProxyBody"
			_proxy_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_proxy_body)
		_proxy_body.size = CANONICAL_SIZE
		_proxy_body.position = Vector2(-CANONICAL_SIZE.x * 0.5, -CANONICAL_SIZE.y)

	if _proxy_accent == null:
		_proxy_accent = get_node_or_null("ProxyAccent") as ColorRect
		if _proxy_accent == null:
			_proxy_accent = ColorRect.new()
			_proxy_accent.name = "ProxyAccent"
			_proxy_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_proxy_accent)
		_proxy_accent.size = Vector2(CANONICAL_SIZE.x * 0.55, 18.0)
		_proxy_accent.position = Vector2(-CANONICAL_SIZE.x * 0.275, -CANONICAL_SIZE.y + 10.0)

	if _proxy_label == null:
		_proxy_label = get_node_or_null("ProxyLabel") as Label
		if _proxy_label == null:
			_proxy_label = Label.new()
			_proxy_label.name = "ProxyLabel"
			_proxy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			add_child(_proxy_label)
		_proxy_label.position = Vector2(-40.0, -CANONICAL_SIZE.y - 28.0)
		_proxy_label.size = Vector2(80.0, 24.0)
		_proxy_label.add_theme_font_size_override("font_size", 18)
		_proxy_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		_proxy_label.add_theme_constant_override("outline_size", 4)


func _try_load_sprite_frames(path: String) -> bool:
	if path.is_empty() or not ResourceLoader.exists(path):
		if _animated != null:
			_animated.sprite_frames = null
		return false
	var frames: SpriteFrames = load(path) as SpriteFrames
	if frames == null:
		return false
	## Require the full catalog set so we never mix proxy + partial sheets.
	for anim: String in CharacterCatalog.all_anims():
		if not frames.has_animation(anim) or frames.get_frame_count(anim) < 1:
			push_warning(
				"CharacterVisual: %s missing anim '%s' — using emergency proxy."
				% [path, anim]
			)
			_animated.sprite_frames = null
			return false
	_animated.sprite_frames = frames
	return true


func _refresh_proxy_look() -> void:
	if _definition == null:
		return
	if _proxy_body != null:
		_proxy_body.color = _definition.accent_primary
	if _proxy_accent != null:
		_proxy_accent.color = _definition.accent_secondary


func _resolve_anim(anim_name: String) -> String:
	if CharacterCatalog.is_valid_anim(anim_name):
		return anim_name
	return CharacterCatalog.ANIM_IDLE


func _update_proxy_pose(anim_name: String) -> void:
	if _using_frames or _proxy_body == null:
		return
	## Lightweight silhouette cues — not final art.
	var squash: Vector2 = Vector2.ONE
	var body_mod: Color = _definition.accent_primary if _definition != null else Color.WHITE
	match anim_name:
		CharacterCatalog.ANIM_SLIDE:
			squash = Vector2(1.2, 0.55)
		CharacterCatalog.ANIM_JUMP:
			squash = Vector2(0.9, 1.1)
		CharacterCatalog.ANIM_FALL:
			squash = Vector2(0.95, 1.05)
		CharacterCatalog.ANIM_GRAPPLE:
			squash = Vector2(1.05, 0.95)
			body_mod = body_mod.lightened(0.15)
		CharacterCatalog.ANIM_HIT:
			body_mod = body_mod.darkened(0.35)
		CharacterCatalog.ANIM_LAND:
			squash = Vector2(1.1, 0.85)
		CharacterCatalog.ANIM_IDLE:
			squash = Vector2(1.0, 1.0)
		_:
			squash = Vector2(1.0, 1.0)
	_proxy_body.size = Vector2(CANONICAL_SIZE.x * squash.x, CANONICAL_SIZE.y * squash.y)
	_proxy_body.position = Vector2(
		-CANONICAL_SIZE.x * squash.x * 0.5,
		-CANONICAL_SIZE.y * squash.y,
	)
	_proxy_body.color = body_mod
