class_name CharacterDefinition
extends RefCounted

## Immutable catalog entry for a selectable runner (visual identity only).

var id: String = ""
var display_name: String = ""
var tagline: String = ""
var accent_primary: Color = Color.WHITE
var accent_secondary: Color = Color.BLACK
## Expected SpriteFrames resource; missing → CharacterVisual fallback proxy.
var sprite_frames_path: String = ""


func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_tagline: String = "",
	p_primary: Color = Color.WHITE,
	p_secondary: Color = Color.BLACK,
	p_frames_path: String = ""
) -> void:
	id = p_id
	display_name = p_display_name
	tagline = p_tagline
	accent_primary = p_primary
	accent_secondary = p_secondary
	sprite_frames_path = p_frames_path
