extends SceneTree
const MAX_FRAMES := 60 * 50
const STATE_GAME_OVER := 4
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	for _i in range(MAX_FRAMES):
		await physics_frame
		var gsm := root.get_node_or_null("GameStateManager")
		if gsm == null:
			continue
		if int(gsm.get("current_state")) == STATE_GAME_OVER:
			var container := root.get_node_or_null("Main/GameSceneContainer")
			var gs: Node = container.get_child(0) if container and container.get_child_count() > 0 else null
			var dist := 0.0
			if gs:
				dist = float(gs.get_node("WorldVelocityController").get("distance_travelled"))
			print("M1 nojump-death smoke PASS (distance=%0.1f)" % dist)
			quit(0)
			return
	push_error("M1 nojump-death smoke: timed out without dying.")
	quit(1)
