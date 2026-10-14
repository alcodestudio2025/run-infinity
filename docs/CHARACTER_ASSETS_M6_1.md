# M6.1 — Character asset pipeline

Drop final Kai / Nova art **without code changes**. Gameplay collision stays on `Player/CollisionShape2D` and never reads sprite bounds.

## Approved concepts

- Store reference (source of truth for look): project media `m6-character-ref-kai-nova.jpg`
- Repo copy for PR/docs: `docs/media/m6-character-ref-kai-nova.jpg`
- **Final sprites are not in this PR.** Colored proxy silhouettes ship as safe fallback only — they are **not** final art.

## Stable IDs

| ID | Display | Palette (approx.) |
|----|---------|-------------------|
| `kai` | Kai | Yellow primary, black secondary, orange accents |
| `nova` | Nova | Fuchsia primary, teal secondary |

Defined in `scripts/characters/CharacterCatalog.gd`.

## Folder layout

```
assets/sprites/characters/
  kai/
    sprite_frames.tres    ← preferred Godot SpriteFrames resource
  nova/
    sprite_frames.tres
```

Paths are fixed by catalog (`…/kai/sprite_frames.tres`, `…/nova/sprite_frames.tres`).  
If the `.tres` is missing, `CharacterVisual` uses the colored proxy automatically.

## SpriteFrames contract

Create a `SpriteFrames` resource (Godot editor → New Resource → SpriteFrames) with these **exact** animation names:

| Anim | Use |
|------|-----|
| `idle` | Title / wait |
| `run` | Ground run |
| `jump` | Ascending |
| `fall` | Descending / launched |
| `slide` | Ground slide |
| `grapple` | Swing attach |
| `land` | Brief touchdown |
| `hit` | Death / hit |

### Import conventions (transparent PNG)

1. Export frames or sheets as **RGBA PNG** (transparent background).
2. Drop PNGs under `assets/sprites/characters/{id}/` (any filenames).
3. In Godot: Import dock → ensure **Compress** mode suitable for mobile (VRAM / ETC2 as project default).
4. Build `sprite_frames.tres` pointing at those textures; assign loop for `idle`/`run`, one-shot for `land`/`hit` as preferred.
5. **Common canvas:** design around **64×96** logical body (or consistent multiple). Pivot / offset should place **feet at CharacterVisual origin** (body extends upward). `CharacterVisual` sets `AnimatedSprite2D.centered = true` and `offset = (0, -48)` for the 64×96 canon — match that or adjust the resource offsets once, not Player collision.

### Scale / pivot rules

- Do **not** change `GameConfig.PLAYER_*_HITBOX_*` for aesthetic differences.
- Do **not** parent `CollisionShape2D` under the visual node.
- Shared physical controller: `PlayerMovement` + same hitboxes for Kai and Nova.
- Per-character polish belongs only in `sprite_frames.tres` (and optional modulate), never in hitbox constants.

## Swap checklist (artist → engineer optional)

1. Add PNGs under `assets/sprites/characters/kai/` and `…/nova/`.
2. Author `sprite_frames.tres` with the eight anim names.
3. Re-open project (or CI import) — no GDScript edit required.
4. Verify headless: `m6_1_character_smoke.gd` still PASS; in-editor run shows frames instead of proxy (`CharacterVisual.is_using_sprite_frames() == true`).

## Out of scope (M6.1)

- Final painted sprites / sheets (must be provided separately)
- M6.2 content, APK export, M5.1.3 gameplay fixes
- Per-character collision or movement stats
