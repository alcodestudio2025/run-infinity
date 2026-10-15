# M6.1-F — Kai skeletal feasibility previews

Review: `docs/reviews/M6_1_F_KAI_SKELETAL_POC.md`

| File | Content |
|------|---------|
| `feasibility_report.json` | Machine verdict `NO_GO_QUALITY_PARTS` |
| `feasibility_source_body.png` | Option A body crop used for band cuts |
| `feasibility_kai_top_crop.png` | Approved-sheet Kai crop context |
| `feasibility_auto_cut_montage.png` | Honest fail montage (not a part plate) |
| `auto_cut_parts/` | Individual band crops (evidence only) |

Regenerate:

```bash
python3 scripts/tools/m6_1_f_feasibility_parts.py
```

Do **not** treat `auto_cut_parts/` as production Skeleton2D textures.
