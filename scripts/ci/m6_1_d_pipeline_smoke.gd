extends SceneTree

## M6.1-D pipeline smoke — tools/spec present; live SpriteFrames still load.
## Does NOT claim animation rework complete (assets still pending).
## Usage: godot --headless --path . -s res://scripts/ci/m6_1_d_pipeline_smoke.gd

const LABEL := "M6.1-D pipeline smoke"
const SPEC := "res://assets/sprites/characters/_incoming/REWORK_SPEC.json"
const IMPORT_TOOL := "res://scripts/tools/import_m6_character_frames.py"
const GATE_TOOL := "res://scripts/tools/m6_1_d_quality_gate.py"
const IDS := ["kai", "nova"]
const KEEP := {
	"kai": ["idle", "jump", "fall", "land", "slide", "hit"],
	"nova": ["idle", "run", "jump", "hit"],
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not FileAccess.file_exists(SPEC):
		push_error("%s: missing %s" % [LABEL, SPEC])
		quit(1)
		return
	if not FileAccess.file_exists(IMPORT_TOOL):
		push_error("%s: missing %s" % [LABEL, IMPORT_TOOL])
		quit(1)
		return
	if not FileAccess.file_exists(GATE_TOOL):
		push_error("%s: missing %s" % [LABEL, GATE_TOOL])
		quit(1)
		return

	var f := FileAccess.open(SPEC, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("%s: bad REWORK_SPEC JSON" % LABEL)
		quit(1)
		return
	if not bool(data.get("do_not_pad_with_duplicates", false)):
		push_error("%s: SPEC must forbid duplicate padding" % LABEL)
		quit(1)
		return
	if not bool(data.get("do_not_extract_from_sheet", false)):
		push_error("%s: SPEC must forbid sheet extract for rework" % LABEL)
		quit(1)
		return
	var rework: Array = data.get("rework", [])
	if rework.is_empty():
		push_error("%s: rework list empty" % LABEL)
		quit(1)
		return
	print("%s: SPEC OK slots=%d status=%s" % [LABEL, rework.size(), str(data.get("status", "?"))])

	## Live characters must still resolve SpriteFrames (system not broken).
	for id: String in IDS:
		var path := "res://assets/sprites/characters/%s/sprite_frames.tres" % id
		if not ResourceLoader.exists(path):
			push_error("%s: missing %s" % [LABEL, path])
			quit(1)
			return
		var frames: SpriteFrames = load(path) as SpriteFrames
		if frames == null:
			push_error("%s: load failed %s" % [LABEL, path])
			quit(1)
			return
		for anim: String in KEEP[id]:
			if not frames.has_animation(anim) or frames.get_frame_count(anim) < 1:
				push_error("%s: kept anim missing %s/%s" % [LABEL, id, anim])
				quit(1)
				return
		## Rework anims must still exist (legacy frames) until replaced — playable system.
		for item: Variant in rework:
			if str(item.get("id", "")) != id:
				continue
			var anim: String = str(item.get("anim", ""))
			if not frames.has_animation(anim) or frames.get_frame_count(anim) < 1:
				push_error("%s: rework slot anim missing in live tres %s/%s" % [LABEL, id, anim])
				quit(1)
				return
		print("%s: SpriteFrames OK %s" % [LABEL, id])

	print("%s: PASS (pipeline ready; art correction NOT complete)" % LABEL)
	quit(0)
