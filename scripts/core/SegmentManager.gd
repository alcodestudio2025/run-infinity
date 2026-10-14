class_name SegmentManager
extends Node

## Owns segment lifecycle: create, pool, recycle, and provide active terrain slices.
## Delegates module attachment to ModuleSpawner. Does not move segments or set difficulty.

const SEGMENT_SCENE: PackedScene = preload("res://scenes/segments/Segment.tscn")

@export var active_segment_count: int = GameConfig.SEGMENT_ACTIVE_COUNT
@export var segment_length: float = GameConfig.SEGMENT_LENGTH

var _world: World
var _container: Node2D
var _module_spawner: ModuleSpawner
var _pool: Array[Segment] = []
var _active_segments: Array[Segment] = []
var _ground_y: float = GameConfig.GROUND_Y
var _spawn_counter: int = 0


func setup(world: World, module_spawner: ModuleSpawner) -> void:
	_world = world
	_container = world.get_chunk_root()
	_module_spawner = module_spawner


func request_segment() -> Segment:
	var segment: Segment = _acquire_segment()

	if segment.get_parent() != _container:
		_container.add_child(segment)

	segment.configure(segment_length, _ground_y, _spawn_counter)
	segment.reset_segment()
	if _module_spawner != null:
		_module_spawner.populate_segment(segment, _spawn_counter)
	_spawn_counter += 1

	if not _active_segments.has(segment):
		_active_segments.append(segment)

	segment.visible = true
	return segment


func release_segment(segment: Segment) -> void:
	if segment == null or not _active_segments.has(segment):
		return

	_active_segments.erase(segment)
	segment.reset_segment()
	segment.visible = false

	if segment.get_parent() == _container:
		_container.remove_child(segment)

	_pool.append(segment)


func get_active_segments() -> Array[Segment]:
	return _active_segments.duplicate()


func reset_all() -> void:
	for segment: Segment in _active_segments.duplicate():
		release_segment(segment)
	_spawn_counter = 0


## Pooled segments are removed from the tree; free them so SceneTree exit
## does not leave orphan Node2D/CanvasItem RIDs (CI ERROR / exit noise).
func _exit_tree() -> void:
	_free_pooled_segments()


func free_pooled_segments() -> void:
	_free_pooled_segments()


func _free_pooled_segments() -> void:
	for segment: Segment in _pool:
		if segment != null and is_instance_valid(segment):
			segment.free()
	_pool.clear()


func _acquire_segment() -> Segment:
	if _pool.is_empty():
		return SEGMENT_SCENE.instantiate() as Segment
	return _pool.pop_back() as Segment
