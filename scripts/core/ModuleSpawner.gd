class_name ModuleSpawner
extends Node

## Attaches modules to segments for pipeline validation.
## Uses a simple even/odd distribution until DifficultyDirector owns spawning.

const PLACEHOLDER_SCENE: PackedScene = preload("res://scenes/modules/ModulePlaceholder.tscn")
const OBSTACLE_SCENE: PackedScene = preload("res://scenes/modules/ObstacleModule.tscn")


func populate_segment(segment: Segment, segment_index: int) -> void:
	if segment == null:
		return

	var module_root: Node2D = segment.get_module_root()
	if module_root == null:
		push_error("ModuleSpawner: segment is missing ModuleRoot.")
		return

	## Safe start: no hazards while the player settles on the first slices.
	if segment_index < GameConfig.SAFE_START_SEGMENT_COUNT:
		_attach_placeholder(segment, module_root, 0)
		return

	## Sparse hazards for M1 (every 3rd segment) — denser patterns land in M2.
	if segment_index % 3 == 0:
		_attach_obstacle(segment, module_root)
	else:
		_attach_placeholder(segment, module_root, 0)


func _attach_placeholder(
	segment: Segment,
	module_root: Node2D,
	slot_index: int,
) -> void:
	var module: ModulePlaceholder = PLACEHOLDER_SCENE.instantiate() as ModulePlaceholder
	if module == null:
		push_error("ModuleSpawner: failed to instantiate ModulePlaceholder.")
		return

	var local_position: Vector2 = GameConfig.get_module_placeholder_local_position(
		slot_index,
		segment.get_length(),
	)

	module_root.add_child(module)
	module.setup({"local_position": local_position})
	module.activate()


func _attach_obstacle(segment: Segment, module_root: Node2D) -> void:
	var module: ObstacleModule = OBSTACLE_SCENE.instantiate() as ObstacleModule
	if module == null:
		push_error("ModuleSpawner: failed to instantiate ObstacleModule.")
		return

	var local_position: Vector2 = GameConfig.get_obstacle_local_position(segment.get_length())

	module_root.add_child(module)
	module.setup({"local_position": local_position})
	module.activate()
