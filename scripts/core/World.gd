class_name World
extends Node2D

## Structural container for world layers.
## Exposes typed roots for spawners without hard-coded node paths.

@onready var _background_root: Node2D = $BackgroundRoot
@onready var _gameplay_root: Node2D = $GameplayRoot
@onready var _chunk_root: Node2D = $ChunkRoot
@onready var _fx_root: Node2D = $FXRoot


func get_background_root() -> Node2D:
	return _background_root


func get_gameplay_root() -> Node2D:
	return _gameplay_root


func get_chunk_root() -> Node2D:
	return _chunk_root


func get_fx_root() -> Node2D:
	return _fx_root
