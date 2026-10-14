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
		var node_2d := node as Node2D
		if node_2d == null:
			continue
		out.append(
			LatchPoint.new(
				StringName(str(node_2d.get_instance_id())),
				node_2d.global_position,
				12.0,
				node_2d,
			)
		)
	return out
