class_name WorldScroller
extends Node

## Scrolls Segment instances provided by SegmentManager.
## Handles motion and screen-edge recycling only.

@export var segment_count: int = GameConfig.SEGMENT_ACTIVE_COUNT
@export var recycle_margin: float = GameConfig.SEGMENT_RECYCLE_MARGIN

var _world: World
var _velocity_controller: WorldVelocityController
var _segment_manager: SegmentManager
var _is_active: bool = false
var _ground_y: float = GameConfig.GROUND_Y
var _ground_height: float = GameConfig.SEGMENT_GROUND_HEIGHT


func setup(
	world: World,
	velocity_controller: WorldVelocityController,
	segment_manager: SegmentManager,
) -> void:
	_world = world
	_velocity_controller = velocity_controller
	_segment_manager = segment_manager
	_initialize_segments()


func start() -> void:
	_is_active = true


func stop() -> void:
	_is_active = false


func reset() -> void:
	stop()
	if _segment_manager != null:
		_segment_manager.reset_all()
	_initialize_segments()


func _physics_process(delta: float) -> void:
	if not _is_active or not GameStateManager.is_playing():
		return
	if _velocity_controller == null or _segment_manager == null:
		return

	var scroll_offset: float = _velocity_controller.current_speed * delta
	for segment: Segment in _segment_manager.get_active_segments():
		segment.position.x -= scroll_offset
	_recycle_segments()


func _initialize_segments() -> void:
	var safe_count: int = maxi(segment_count, 3)
	for _index: int in range(safe_count):
		_segment_manager.request_segment()
	_layout_segments()


func _layout_segments() -> void:
	var segments: Array[Segment] = _segment_manager.get_active_segments()
	var center_y: float = _ground_y + _ground_height * 0.5
	for index: int in range(segments.size()):
		var length: float = segments[index].get_length()
		segments[index].position = Vector2(
			index * length + length * 0.5,
			center_y,
		)


func _recycle_segments() -> void:
	var left_bound: float = _get_recycle_left_bound()
	var segments: Array[Segment] = _segment_manager.get_active_segments()
	var rightmost_edge: float = _get_rightmost_right_edge(segments)

	for segment: Segment in segments.duplicate():
		var segment_length: float = segment.get_length()
		var segment_right: float = segment.position.x + segment_length * 0.5
		if segment_right >= left_bound:
			continue

		_segment_manager.release_segment(segment)
		var recycled_segment: Segment = _segment_manager.request_segment()
		recycled_segment.position = Vector2(
			rightmost_edge + segment_length * 0.5,
			_get_segment_center_y(),
		)
		rightmost_edge = recycled_segment.position.x + segment_length * 0.5


func _get_rightmost_right_edge(segments: Array[Segment]) -> float:
	var rightmost: float = -INF
	for segment: Segment in segments:
		rightmost = maxf(rightmost, segment.position.x + segment.get_length() * 0.5)
	return rightmost


func _get_segment_center_y() -> float:
	return _ground_y + _ground_height * 0.5


func _get_recycle_left_bound() -> float:
	var camera: Camera2D = get_viewport().get_camera_2d()
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	if camera == null:
		return -recycle_margin
	return camera.get_screen_center_position().x - viewport_width * 0.5 - recycle_margin
