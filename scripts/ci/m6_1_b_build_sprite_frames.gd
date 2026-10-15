extends SceneTree

## Build SpriteFrames .tres from extracted PNG manifests (M6.1-B).
## Usage: godot --headless --path . -s res://scripts/ci/m6_1_b_build_sprite_frames.gd

const IDS := ["kai", "nova"]
const FPS := {
	"idle": 6.0,
	"run": 10.0,
	"jump": 8.0,
	"fall": 8.0,
	"land": 10.0,
	"slide": 8.0,
	"grapple": 8.0,
	"hit": 6.0,
}
const LOOP := {
	"idle": true,
	"run": true,
	"jump": false,
	"fall": true,
	"land": false,
	"slide": true,
	"grapple": true,
	"hit": false,
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for id: String in IDS:
		var manifest_path := "res://assets/sprites/characters/%s/frames_manifest.json" % id
		if not FileAccess.file_exists(manifest_path):
			push_error("Missing manifest: %s" % manifest_path)
			quit(1)
			return
		var f := FileAccess.open(manifest_path, FileAccess.READ)
		var data: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(data) != TYPE_DICTIONARY:
			push_error("Bad manifest JSON: %s" % manifest_path)
			quit(1)
			return
		var anims: Dictionary = data.get("anims", {})
		var frames := SpriteFrames.new()
		## Remove default empty anim if present.
		if frames.has_animation("default"):
			frames.remove_animation("default")
		for anim_name: String in anims.keys():
			var paths: Array = anims[anim_name]
			if paths.is_empty():
				push_error("%s/%s has no frames" % [id, anim_name])
				quit(1)
				return
			if frames.has_animation(anim_name):
				frames.remove_animation(anim_name)
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, float(FPS.get(anim_name, 8.0)))
			frames.set_animation_loop(anim_name, bool(LOOP.get(anim_name, true)))
			for p: Variant in paths:
				var tex: Texture2D = load(str(p)) as Texture2D
				if tex == null:
					push_error("Failed to load texture %s" % str(p))
					quit(1)
					return
				frames.add_frame(anim_name, tex)
		var out_path := "res://assets/sprites/characters/%s/sprite_frames.tres" % id
		var err: Error = ResourceSaver.save(frames, out_path)
		if err != OK:
			push_error("Save failed %s (%s)" % [out_path, error_string(err)])
			quit(1)
			return
		print("Wrote %s anims=%d" % [out_path, anims.size()])
	print("M6.1-B sprite_frames build PASS")
	quit(0)
