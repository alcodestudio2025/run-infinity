# M6.1 Visual Preview — real Godot viewports

**Commit captured:** `0c4ff1d0eeb103f3f6c11699f772430d236ae68c` (plus this preview PR docs/script)  
**Resolution:** 1920×1080 landscape  
**Method:** `scripts/ci/m6_1_visual_preview_capture.gd` — live `ViewportTexture` PNGs from the running game (OpenGL/llvmpipe on cloud display `:1`). **Not** mocked/composited images.

## Proxy vs definitive

| Element | Status |
|---------|--------|
| Character select UI (labels, Kai/Nova buttons, Confirm/Back) | **Definitive M6.1 UI** |
| Save persistence of `selected_character_id` | **Definitive** (logic) |
| Shared hitboxes / PlayerMovement | **Definitive** (unchanged physics) |
| Kai / Nova in-game body | **PROXY ONLY** — colored ColorRect silhouettes + name label |
| Final cartoon sprites from approved sheet | **NOT IN BUILD** — must drop `sprite_frames.tres` later |
| Approved concept sheet | **Definitive reference** at `docs/media/m6-character-ref-kai-nova.jpg` (SHA-256 matches store media) |

Proxy palette: Kai = yellow + black accent; Nova = fuchsia + teal accent. These are **not** final art and must not be mistaken for shipped character sprites.

## Files

| File | Contents |
|------|----------|
| `01-title.png` | Title screen |
| `02-character-select.png` | Character select (both options) |
| `03-character-select-kai-highlighted.png` | Kai selected |
| `04-character-select-nova-highlighted.png` | Nova selected |
| `05-gameplay-kai-run.png` | Kai proxy RUN |
| `06-gameplay-kai-jump.png` | Kai proxy JUMP (captured in JUMPING) |
| `07-gameplay-kai-slide.png` | Kai proxy SLIDE (squashed silhouette) |
| `08-gameplay-kai-grapple.png` | Kai live grapple / SWINGING |
| `09-gameplay-nova-run.png` | Nova proxy RUN |
| `10-gameplay-nova-jump.png` | Nova proxy JUMP |
| `11-gameplay-nova-slide.png` | Nova proxy SLIDE |
| `12-gameplay-nova-grapple.png` | Nova live grapple / SWINGING |
| `approved-character-ref.jpg` | Copy of approved sheet for side-by-side review |

## Reproduce

```bash
DISPLAY=:1 godot --path . --fixed-fps 60 \
  -s res://scripts/ci/m6_1_visual_preview_capture.gd
```

Do **not** pass `--headless` (renders black). Optional `RI_PREVIEW_FLIP_Y=1` on Vulkan if frames invert.

## Limits

- Cloud GPU is software LLVMpipe → functional but not device-quality presentation.
- Proxies intentionally replace missing final sprites; do not treat yellow/fuchsia blocks as art direction deliverables.
- Touch labels SLIDE/JUMP are existing M5 UI, not character art.
