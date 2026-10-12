class_name Layers
extends RefCounted

## Collision layer indices. Must match Project Settings → Layer Names (2D Physics).

const WORLD: int = 1
const PLAYER: int = 2
const OBSTACLE: int = 3
const COLLECTIBLE: int = 4
const UI: int = 5
const CAMERA: int = 6


## Returns the bitmask for a single 1-based layer index.
static func to_mask(layer: int) -> int:
	return 1 << (layer - 1)
