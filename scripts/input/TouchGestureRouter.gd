class_name TouchGestureRouter
extends Node

## Classifies pointer gestures into jump/slide intents. No physics.

signal jump_requested
signal slide_requested

const PRIMARY_TOUCH_INDEX: int = 0
const MOUSE_POINTER_INDEX: int = -1
const SWIPE_RATIO: float = 0.06
const SWIPE_FALLBACK_PX: float = 48.0
const TAP_SLOP_RATIO: float = 0.025
const TAP_SLOP_FALLBACK_PX: float = 24.0
const DEFAULT_VIEWPORT_SIZE: Vector2 = Vector2(720.0, 1280.0)

var _enabled: bool = false
## index -> start position
var _touch_starts: Dictionary = {}
## index -> latest position
var _touch_positions: Dictionary = {}
## True after a real ScreenTouch begins until all touches end (blocks emulated mouse).
var _touchscreen_gesture_active: bool = false


func reset() -> void:
	_touch_starts.clear()
	_touch_positions.clear()
	_touchscreen_gesture_active = false


func set_enabled(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	if not _enabled:
		reset()


func handle_input_event(event: InputEvent) -> bool:
	if not _enabled:
		return false

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.canceled:
			cancel_touch(touch.index)
			return true
		if touch.pressed:
			_touchscreen_gesture_active = true
			begin_touch(touch.index, touch.position)
		else:
			end_touch(touch.index, touch.position)
			if not _has_any_finger_touch():
				_touchscreen_gesture_active = false
		return true

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		update_touch(drag.index, drag.position)
		return true

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return false
		## Prefer touchscreen path: ignore mouse while fingers are active or emulated.
		if _should_ignore_mouse():
			return false
		if mouse.pressed:
			begin_touch(MOUSE_POINTER_INDEX, mouse.position)
		else:
			end_touch(MOUSE_POINTER_INDEX, mouse.position)
		return true

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if not _touch_starts.has(MOUSE_POINTER_INDEX):
			return false
		if _should_ignore_mouse():
			return false
		update_touch(MOUSE_POINTER_INDEX, motion.position)
		return true

	return false


func begin_touch(index: int, position: Vector2) -> void:
	_touch_starts[index] = position
	_touch_positions[index] = position


func update_touch(index: int, position: Vector2) -> void:
	if not _touch_starts.has(index):
		return
	_touch_positions[index] = position


func end_touch(index: int, position: Vector2) -> String:
	if not _touch_starts.has(index):
		return "none"

	_touch_positions[index] = position
	var start_pos: Vector2 = _touch_starts[index]
	_touch_starts.erase(index)
	_touch_positions.erase(index)

	## Only the primary finger emits actions (mouse uses reserved index).
	if not _is_action_index(index):
		return "none"

	var result: String = _classify_gesture(start_pos, position)
	if _enabled:
		_emit_result(result)
	return result


func cancel_touch(index: int) -> void:
	_touch_starts.erase(index)
	_touch_positions.erase(index)
	if index >= 0 and not _has_any_finger_touch():
		_touchscreen_gesture_active = false


func get_swipe_threshold_px(viewport_size: Vector2) -> float:
	var height: float = maxf(viewport_size.y, 1.0)
	return maxf(SWIPE_FALLBACK_PX, height * SWIPE_RATIO)


func get_tap_slop_px(viewport_size: Vector2) -> float:
	var height: float = maxf(viewport_size.y, 1.0)
	return maxf(TAP_SLOP_FALLBACK_PX, height * TAP_SLOP_RATIO)


func _classify_gesture(start_pos: Vector2, end_pos: Vector2) -> String:
	var delta: Vector2 = end_pos - start_pos
	var viewport_size: Vector2 = _viewport_size()
	var swipe_threshold: float = get_swipe_threshold_px(viewport_size)
	var tap_slop: float = get_tap_slop_px(viewport_size)
	var abs_x: float = absf(delta.x)
	var abs_y: float = absf(delta.y)
	var travel: float = delta.length()

	## Tap / small movement within slop → jump (any direction inside tolerance).
	if travel <= tap_slop:
		return "jump"

	## Beyond slop: horizontal-dominant → none.
	if abs_x >= abs_y:
		return "none"

	## Vertical-dominant beyond slop.
	## Clear downward swipe past threshold → slide.
	if delta.y >= swipe_threshold:
		return "slide"

	## Clear upward swipe past threshold → none (never jump).
	if delta.y <= -swipe_threshold:
		return "none"

	## Ambiguous mid-zone (past slop, short of a clear vertical swipe) → none.
	return "none"


func _emit_result(result: String) -> void:
	if result == "jump":
		jump_requested.emit()
	elif result == "slide":
		slide_requested.emit()


func _is_action_index(index: int) -> bool:
	return index == PRIMARY_TOUCH_INDEX or index == MOUSE_POINTER_INDEX


func _has_any_finger_touch() -> bool:
	for key in _touch_starts.keys():
		if int(key) >= 0:
			return true
	return false


func _should_ignore_mouse() -> bool:
	if _touchscreen_gesture_active or _has_any_finger_touch():
		return true
	## When a touchscreen is present, prefer ScreenTouch over emulated mouse.
	if DisplayServer.get_name() != "headless" and DisplayServer.is_touchscreen_available():
		return true
	return false


func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport != null:
		var size: Vector2 = viewport.get_visible_rect().size
		if size.x > 0.0 and size.y > 0.0:
			return size
	return DEFAULT_VIEWPORT_SIZE
