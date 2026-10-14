class_name CharacterCatalog
extends RefCounted

## Stable character IDs and definitions for M6.1.
## Visual-only — never changes collision / PlayerMovement physics.

const ID_KAI: String = "kai"
const ID_NOVA: String = "nova"
const DEFAULT_ID: String = ID_KAI

## Animation names expected by CharacterVisual + future sprite sheets.
const ANIM_IDLE: String = "idle"
const ANIM_RUN: String = "run"
const ANIM_JUMP: String = "jump"
const ANIM_FALL: String = "fall"
const ANIM_SLIDE: String = "slide"
const ANIM_GRAPPLE: String = "grapple"
const ANIM_LAND: String = "land"
const ANIM_HIT: String = "hit"

static func all_anims() -> PackedStringArray:
	return PackedStringArray([
		ANIM_IDLE,
		ANIM_RUN,
		ANIM_JUMP,
		ANIM_FALL,
		ANIM_SLIDE,
		ANIM_GRAPPLE,
		ANIM_LAND,
		ANIM_HIT,
	])


static func is_valid_anim(anim_name: String) -> bool:
	match anim_name:
		ANIM_IDLE, ANIM_RUN, ANIM_JUMP, ANIM_FALL, ANIM_SLIDE, ANIM_GRAPPLE, ANIM_LAND, ANIM_HIT:
			return true
		_:
			return false


static func all_ids() -> PackedStringArray:
	return PackedStringArray([ID_KAI, ID_NOVA])


static func is_valid_id(character_id: String) -> bool:
	return character_id == ID_KAI or character_id == ID_NOVA


static func normalize_id(character_id: String) -> String:
	if is_valid_id(character_id):
		return character_id
	return DEFAULT_ID


static func get_definition(character_id: String) -> CharacterDefinition:
	var id: String = normalize_id(character_id)
	match id:
		ID_NOVA:
			return CharacterDefinition.new(
				ID_NOVA,
				"Nova",
				"Esploratrice",
				Color(0.95, 0.2, 0.72, 1.0),
				Color(0.15, 0.85, 0.78, 1.0),
				"res://assets/sprites/characters/nova/sprite_frames.tres",
			)
		_:
			return CharacterDefinition.new(
				ID_KAI,
				"Kai",
				"Eroe Atletico",
				Color(1.0, 0.84, 0.12, 1.0),
				Color(0.08, 0.08, 0.1, 1.0),
				"res://assets/sprites/characters/kai/sprite_frames.tres",
			)


static func frames_root_for(character_id: String) -> String:
	return "res://assets/sprites/characters/%s" % normalize_id(character_id)
