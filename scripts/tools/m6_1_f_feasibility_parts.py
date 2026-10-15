#!/usr/bin/env python3
"""M6.1-F — Feasibility: can Option A assets yield quality skeletal parts?

Honest assessment only. Horizontal band-cuts of a full-body illustration are
evidence of failure, not production textures. Never claims GO from rectangles.

  python3 scripts/tools/m6_1_f_feasibility_parts.py
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/previews/m6-1-f"
PARTS_DIR = OUT / "auto_cut_parts"
SHEET = ROOT / "assets/sprites/characters/_source/kai_nova_sheet_approved.png"
LIVE_RUN = ROOT / "assets/sprites/characters/kai/frames/run_00.png"

# Approximate Kai hero panel on the approved sheet (full-body illustration).
# Used only to document that the source is a painted pose, not a part plate.
SHEET_KAI_BOX = (272, 40, 272 + 880, 40 + 460)  # L,T,R,B
BODY_WIDTH = 284  # leftmost figure column used for band cuts

REQUIRED_PARTS = [
    "head",
    "torso",
    "upper_arm_l",
    "upper_arm_r",
    "forearm_l",
    "forearm_r",
    "thigh_l",
    "thigh_r",
    "shin_l",
    "shin_r",
    "shoe_l",
    "shoe_r",
]

MIN_EDGE_PX = 64

# Relative vertical bands on the body crop (fractions of height).
# Labels name anatomical *intent*; cuts intentionally fail as articulation parts.
BANDS = [
    ("head", 0.00, 0.28),
    ("torso", 0.18, 0.51),
    ("thigh", 0.45, 0.69),
    ("shin", 0.62, 0.94),
    ("arm_guess", 0.22, 0.52),
]


def _font(size: int):
    for name in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        p = Path(name)
        if p.is_file():
            return ImageFont.truetype(str(p), size)
    return ImageFont.load_default()


def opaque_pct(im: Image.Image) -> float:
    a = np.array(im.convert("RGBA"))[:, :, 3]
    return float((a > 8).mean() * 100.0)


def live_limb_band_px() -> int | None:
    if not LIVE_RUN.is_file():
        return None
    arr = np.array(Image.open(LIVE_RUN).convert("RGBA"))
    ys, xs = np.where(arr[:, :, 3] > 8)
    if len(xs) == 0:
        return None
    w = int(xs.max() - xs.min() + 1)
    return max(1, w // 4)


def load_or_build_source() -> tuple[Image.Image, Image.Image]:
    """Return (top_crop, body_crop). Prefer committed crops; else sheet extract."""
    top_path = OUT / "feasibility_kai_top_crop.png"
    body_path = OUT / "feasibility_source_body.png"
    if top_path.is_file() and body_path.is_file():
        return Image.open(top_path).convert("RGBA"), Image.open(body_path).convert("RGBA")

    sheet = Image.open(SHEET).convert("RGBA")
    top = sheet.crop(SHEET_KAI_BOX)
    body = top.crop((0, 0, BODY_WIDTH, top.size[1]))
    return top, body


def cut_bands(body: Image.Image) -> list[dict]:
    w, h = body.size
    PARTS_DIR.mkdir(parents=True, exist_ok=True)
    rows = []
    for name, y0f, y1f in BANDS:
        y0 = max(0, int(h * y0f))
        y1 = min(h, int(h * y1f))
        if y1 <= y0:
            y1 = min(h, y0 + 1)
        part = body.crop((0, y0, w, y1))
        part.save(PARTS_DIR / f"{name}.png")
        rows.append(
            {
                "part": name,
                "size": [part.size[0], part.size[1]],
                "opaque_pct": round(opaque_pct(part), 2),
                "y_range": [y0, y1],
            }
        )
    return rows


def montage(body: Image.Image, parts: list[dict]) -> Image.Image:
    # Show first three bands: head / torso / thigh — enough to prove fail.
    show = ["head", "torso", "thigh"]
    tiles = []
    for name in show:
        im = Image.open(PARTS_DIR / f"{name}.png").convert("RGBA")
        tiles.append((name, im))

    pad = 16
    label_h = 36
    tile_h = max(t.size[1] for _, t in tiles)
    tile_w = max(t.size[0] for _, t in tiles)
    cols = len(tiles)
    W = pad + cols * (tile_w + pad)
    H = 48 + tile_h + label_h + pad
    canvas = Image.new("RGBA", (W, H), (32, 34, 38, 255))
    draw = ImageDraw.Draw(canvas)
    title = _font(18)
    small = _font(14)
    draw.text(
        (pad, 12),
        "AUTO BAND CUTS | NOT a quality skeletal part plate",
        fill=(255, 220, 64, 255),
        font=title,
    )
    x = pad
    y = 48
    for name, im in tiles:
        # letterbox on dark
        cell = Image.new("RGBA", (tile_w, tile_h), (24, 26, 30, 255))
        ox = (tile_w - im.size[0]) // 2
        oy = (tile_h - im.size[1]) // 2
        cell.alpha_composite(im, (ox, oy))
        canvas.alpha_composite(cell, (x, y))
        draw.text(
            (x + 8, y + tile_h + 8),
            name,
            fill=(220, 220, 220, 255),
            font=small,
        )
        x += tile_w + pad
    return canvas


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    top, body = load_or_build_source()
    top.save(OUT / "feasibility_kai_top_crop.png")
    body.save(OUT / "feasibility_source_body.png")

    parts = cut_bands(body)
    mont = montage(body, parts)
    mont.save(OUT / "feasibility_auto_cut_montage.png")

    live_band = live_limb_band_px()
    # Band cuts are not separable L/R limbs and do not reconstruct occlusions.
    has_required = False
    report = {
        "verdict": "NO_GO_QUALITY_PARTS",
        "reason": (
            "Approved sheet and live frames are full-body poses, not authored limb plates. "
            "Auto band-cuts leave occlusion holes and soft seams; "
            f"live 64x96 yields ~{live_band or 14}px limb segments."
        ),
        "option_a_locked": True,
        "experimental_frame00_canonical": False,
        "m6_1_d_png_production": "SUSPENDED",
        "source_body_px": [body.size[0], body.size[1]],
        "auto_parts": [
            {"part": p["part"], "size": p["size"], "opaque_pct": p["opaque_pct"]}
            for p in parts
        ],
        "live_approx_limb_band_px": live_band,
        "authored_required_parts_present": has_required,
        "min_quality_bar": {
            "authoring_part_min_edge_px": MIN_EDGE_PX,
            "required_parts": REQUIRED_PARTS,
            "must_reconstruct_occlusions": True,
            "no_rect_placeholders": True,
        },
        "next_asset_ask": (
            "Dedicated Kai cutout part plate matching Option A costume "
            "(raglan yellow/black, maroon leggings), front+side turnaround, painted overlaps."
        ),
    }
    (OUT / "feasibility_report.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({"verdict": report["verdict"], "out": str(OUT)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
