# M6.1 / M6.1-B — Character asset pipeline

Gameplay collision stays on `Player/CollisionShape2D` and never reads sprite bounds.

## Approved source

| Item | Path |
|------|------|
| Approved sheet (RGBA) | `assets/sprites/characters/_source/kai_nova_sheet_approved.png` |
| Extractor | `scripts/tools/extract_m6_character_frames.py` |
| SpriteFrames builder | `scripts/ci/m6_1_b_build_sprite_frames.gd` |

**M6.1-B:** Kai and Nova gameplay sprites are integrated. Colored proxies remain **emergency fallback only** when `sprite_frames.tres` is missing or incomplete.

## Stable IDs

| ID | Display | Tagline |
|----|---------|---------|
| `kai` | Kai | Eroe Atletico |
| `nova` | Nova | Esploratrice |

## Folder layout

```
assets/sprites/characters/
  _source/kai_nova_sheet_approved.png
  kai/
    frames/*.png          ← 64×96 RGBA, feet at bottom-center
    frames_manifest.json
    sprite_frames.tres
  nova/
    frames/*.png
    frames_manifest.json
    sprite_frames.tres
```

## SpriteFrames contract

Exact animation names (see `CharacterCatalog`):

| Anim | Loop | Notes |
|------|------|-------|
| `idle` | yes | |
| `run` | yes | |
| `jump` | no | |
| `fall` | yes | |
| `land` | no | brief |
| `slide` | yes | |
| `grapple` | yes | |
| `hit` | no | |

### Pivot / scale

- Canvas **64×96** matches `CharacterVisual.CANONICAL_SIZE`.
- Feet at bottom-center; `AnimatedSprite2D.centered` + `offset=(0,-48)`.
- Do **not** change hitboxes for art.

## Rebuild

```bash
python3 scripts/tools/extract_m6_character_frames.py
godot --headless --path . --import --quit
godot --headless --path . -s res://scripts/ci/m6_1_b_build_sprite_frames.gd
```

## Out of scope

- Per-character physics
- M6.2 content / APK
