# M6.1-C — Real Godot animation captures

Captured with OpenGL (not `--headless`) via:

```bash
DISPLAY=:1 godot --path . --fixed-fps 30 -s res://scripts/ci/m6_1_c_anim_record.gd
# then ffmpeg GIF/MP4 encode from docs/previews/m6-1-c/raw/{id}/{anim}/play_*.png
```

| File pattern | Content |
|--------------|---------|
| `{id}_{anim}.gif` / `.mp4` | Full cycles from `AnimatedSprite2D` |
| `still_*.png` | Single Godot viewport stills |
| `*_strip_x4.png` | Source frame strips (×4 nearest) |
| `*_x6.png` | Idle frame ×6 for edge/sharpness check |
| `raw/` | Per-frame PNG sequences |
| `asset_metrics.json` | Alpha / foot-pivot / sharpness metrics |

These are **not** AI interpolations. Review narrative: `docs/reviews/M6_1_C_VISUAL_QA.md`.
