class_name TouchGestureRouter
extends Node

## Classifies pointer gestures into jump/slide intents. No physics.
##
## M4.1 latency path:
## - Early slide: emit once when drag crosses downward swipe threshold.
## - Early tap: emit once after EARLY_TAP_DWELL_SEC while travel ≤ tap slop.
## - Release path still classifies if nothing committed yet (rapid taps).
## - Holding still past dwell then swiping is an accepted edge case (jump already fired).

signal jump_requested
signal slide_requested

const PRIMARY_TOUCH_INDEX: int = 0
const MOUSE_POINTER_INDEX: int = -1
const SWIPE_RATIO: float = 0.06
const SWIPE_FALLBACK_PX: float = 48.0
const TAP_SLOP_RATIO: float = 0.025
const TAP_SLOP_FALLBACK_PX: float = 24.0
## Dwell before committing a still/low-travel press as jump (process-delta seconds).
const EARLY_TAP_DWELL_SEC: float = 0.048
const DEFAULT_VIEWPORT_SIZE: Vector2 = Vector2(720.0, 1280.0)

var _enabled: bool = false
## index -> start position
var _touch_starts: Dictionary = {}
## index -> latest position
var _touch_positions: Dictionary = {}
## index -> committed result ("jump"|"slide") after a single emit for that gesture
var _gesture_committed: Dictionary = {}
## True after a real ScreenTouch begins until all touches end (blocks emulated mouse).
var _touchscreen_gesture_active: bool = false
## Accumulated process time for early-tap candidate (primary/mouse only).
var _early_tap_elapsed: float = 0.0
var _early_tap_index: int = -999
var _early_tap_active: bool = false


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not _early_tap_active:
		set_process(false)
		return
	if not _enabled:
		_clear_early_tap()
		return
	_early_tap_elapsed += delta
	_try_early_tap(_early_tap_index)


func reset() -> void:
	_touch_starts.clear()
	_touch_positions.clear()
	_gesture_committed.clear()
	_clear_early_tap()
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
	_gesture_committed.erase(index)
	if _is_action_index(index):
		_arm_early_tap(index)


func update_touch(index: int, position: Vector2) -> void:
	if not _touch_starts.has(index):
		return
	_touch_positions[index] = position
	if not _is_action_index(index):
		return
	if _gesture_committed.has(index):
		return
	_evaluate_early_commit(index)


func end_touch(index: int, position: Vector2) -> String:
	if not _touch_starts.has(index):
		return "none"

	_touch_positions[index] = position
	var start_pos: Vector2 = _touch_starts[index]
	_touch_starts.erase(index)
	_touch_positions.erase(index)

	## Only the primary finger emits actions (mouse uses reserved index).
	if not _is_action_index(index):
		_clear_early_tap_if(index)
		_gesture_committed.erase(index)
		return "none"

	if _gesture_committed.has(index):
		var committed: String = str(_gesture_committed[index])
		_gesture_committed.erase(index)
		_clear_early_tap_if(index)
		## Already emitted once during drag/dwell — no double emit.
		return committed

	_clear_early_tap_if(index)
	var result: String = _classify_gesture(start_pos, position)
	if _enabled:
		_emit_result(result)
	return result


func cancel_touch(index: int) -> void:
	_touch_starts.erase(index)
	_touch_positions.erase(index)
	_gesture_committed.erase(index)
	_clear_early_tap_if(index)
	if index >= 0 and not _has_any_finger_touch():
		_touchscreen_gesture_active = false


func get_swipe_threshold_px(viewport_size: Vector2) -> float:
	var height: float = maxf(viewport_size.y, 1.0)
	return maxf(SWIPE_FALLBACK_PX, height * SWIPE_RATIO)


func get_tap_slop_px(viewport_size: Vector2) -> float:
	var height: float = maxf(viewport_size.y, 1.0)
	return maxf(TAP_SLOP_FALLBACK_PX, height * TAP_SLOP_RATIO)


func _evaluate_early_commit(index: int) -> void:
	if not _touch_starts.has(index) or _gesture_committed.has(index):
		return

	var start_pos: Vector2 = _touch_starts[index]
	var pos: Vector2 = _touch_positions[index]
	var delta: Vector2 = pos - start_pos
	var viewport_size: Vector2 = _viewport_size()
	var swipe_threshold: float = get_swipe_threshold_px(viewport_size)
	var tap_slop: float = get_tap_slop_px(viewport_size)
	var abs_x: float = absf(delta.x)
	var abs_y: float = absf(delta.y)
	var travel: float = delta.length()

	## Movement past slop cancels early-tap candidate (may still become slide/none).
	if travel > tap_slop:
		_clear_early_tap_if(index)

	## Horizontal-dominant past slop → never early-commit; end will return none.
	if travel > tap_slop and abs_x >= abs_y:
		return

	## Vertical-dominant clear downward swipe → early slide commit.
	if abs_y > abs_x and delta.y >= swipe_threshold:
		_commit_gesture(index, "slide")
		return

	## Clear upward swipe → cancel early tap; end classifies as none.
	if abs_y > abs_x and delta.y <= -swipe_threshold:
		_clear_early_tap_if(index)
		return

	## Still within slop: may early-tap once dwell elapses.
	_try_early_tap(index)


func _try_early_tap(index: int) -> void:
	if not _early_tap_active or index != _early_tap_index:
		return
	if not _enabled or _gesture_committed.has(index):
		_clear_early_tap()
		return
	if not _touch_starts.has(index):
		_clear_early_tap()
		return

	var travel: float = (_touch_positions[index] - _touch_starts[index]).length()
	var tap_slop: float = get_tap_slop_px(_viewport_size())
	if travel > tap_slop:
		_clear_early_tap()
		return

	if _early_tap_elapsed >= EARLY_TAP_DWELL_SEC:
		_commit_gesture(index, "jump")


func _commit_gesture(index: int, result: String) -> void:
	if _gesture_committed.has(index):
		return
	_gesture_committed[index] = result
	_clear_early_tap_if(index)
	if _enabled:
		_emit_result(result)


func _arm_early_tap(index: int) -> void:
	_early_tap_index = index
	_early_tap_elapsed = 0.0
	_early_tap_active = true
	set_process(true)


func _clear_early_tap() -> void:
	_early_tap_active = false
	_early_tap_elapsed = 0.0
	_early_tap_index = -999
	set_process(false)


func _clear_early_tap_if(index: int) -> void:
	if index == _early_tap_index:
		_clear_early_tap()


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
