class_name TreeLatchProvider
extends LatchProvider

## Live latch source: collects Nodes in group Tags.ANCHOR and exposes world positions.
## LatchModule (Agent B) or smoke-spawned Node2D anchors both work.

var _tree_root: Node = null


func set_tree_root(root: Node) -> void:
	_tree_root = root


func get_tree_root() -> Node:
	return _tree_root


func collect_latches() -> Array[LatchPoint]:
	var out: Array[LatchPoint] = []
	if _tree_root == null or not is_instance_valid(_tree_root):
		return out
	var tree: SceneTree = _tree_root.get_tree()
	if tree == null:
		return out
	var nodes: Array[Node] = tree.get_nodes_in_group(Tags.ANCHOR)
	for node: Node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		## Prefer LatchModule validity + LatchPoint marker when present.
		if node.has_method("is_latch_valid") and not bool(node.call("is_latch_valid")):
			continue
		if node.has_method("to_latch_point"):
			out.append(node.call("to_latch_point") as LatchPoint)
			continue
		var node_2d := node as Node2D
		if node_2d == null:
			continue
		var pos: Vector2 = node_2d.global_position
		if node.has_method("get_latch_global_position"):
			pos = node.call("get_latch_global_position") as Vector2
		out.append(
			LatchPoint.new(
				StringName(str(node_2d.get_instance_id())),
				pos,
				GameConfig.LATCH_POINT_RADIUS,
				node_2d,
			)
		)
	return out
