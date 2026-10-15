#!/usr/bin/env python3
"""Extract Kai/Nova gameplay frames from the approved M6 sprite sheet.

Produces per-anim RGBA PNGs on a uniform feet-pivot canvas and a manifest JSON
consumed by the Godot SpriteFrames builder.
"""
from __future__ import annotations

import json
import os
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "assets/sprites/characters/_source/kai_nova_sheet_approved.png"
OUT_ROOT = ROOT / "assets/sprites/characters"
## Match CharacterVisual.CANONICAL_SIZE (64×96); feet at bottom-center.
CANVAS = (64, 96)  # W,H
ALPHA_KEEP = 48


def clean_alpha(rgba: np.ndarray) -> np.ndarray:
	out = rgba.copy()
	a = out[:, :, 3]
	# Near-transparent fringe → fully transparent (no black matte).
	out[a < ALPHA_KEEP, 3] = 0
	# Keep only the largest opaque blob (drops label crumbs / neighbors).
	mask = out[:, :, 3] >= ALPHA_KEEP
	if mask.any():
		labeled, n = ndimage.label(mask)
		if n > 1:
			sizes = ndimage.sum(mask, labeled, range(1, n + 1))
			keep = int(np.argmax(sizes)) + 1
			out[labeled != keep, 3] = 0
	# Fully transparent pixels must not carry color (premultiply hygiene).
	out[out[:, :, 3] == 0, 0:3] = 0
	return out


def place_on_canvas(crop: np.ndarray, canvas_size=CANVAS) -> np.ndarray:
	"""Feet at bottom-center; trim empty margins first."""
	crop = clean_alpha(crop)
	ys, xs = np.where(crop[:, :, 3] > 0)
	if len(xs) == 0:
		return np.zeros((canvas_size[1], canvas_size[0], 4), dtype=np.uint8)
	x0, x1 = int(xs.min()), int(xs.max())
	y0, y1 = int(ys.min()), int(ys.max())
	trimmed = crop[y0 : y1 + 1, x0 : x1 + 1]
	th, tw = trimmed.shape[:2]
	cw, ch = canvas_size
	# Scale down if larger than canvas (keep aspect).
	scale = min(1.0, (cw - 4) / max(tw, 1), (ch - 4) / max(th, 1))
	if scale < 0.999:
		nw = max(1, int(round(tw * scale)))
		nh = max(1, int(round(th * scale)))
		im = Image.fromarray(trimmed, "RGBA").resize((nw, nh), Image.Resampling.LANCZOS)
		trimmed = np.array(im)
		th, tw = trimmed.shape[:2]
	canvas = np.zeros((ch, cw, 4), dtype=np.uint8)
	# Feet = bottom of trimmed content → bottom of canvas with 2px pad.
	dest_y = ch - th - 2
	dest_x = (cw - tw) // 2
	dest_y = max(0, dest_y)
	dest_x = max(0, min(dest_x, cw - tw))
	canvas[dest_y : dest_y + th, dest_x : dest_x + tw] = trimmed
	return canvas


def find_body_components(half: np.ndarray, yoff: int) -> list[dict]:
	mask = half[:, :, 3] >= 90
	opened = ndimage.binary_opening(mask, structure=np.ones((3, 3), bool), iterations=1)
	sep = ndimage.binary_erosion(opened, structure=np.ones((1, 3), bool), iterations=2)
	labeled, n = ndimage.label(sep)
	comps: list[dict] = []
	for lab in range(1, n + 1):
		ys, xs = np.where(labeled == lab)
		if len(xs) == 0:
			continue
		x0, x1 = int(xs.min()), int(xs.max())
		y0, y1 = int(ys.min()), int(ys.max())
		pad = 6
		yy0 = max(0, y0 - pad)
		yy1 = min(half.shape[0] - 1, y1 + pad)
		xx0 = max(0, x0 - pad)
		xx1 = min(half.shape[1] - 1, x1 + pad)
		region = mask[yy0 : yy1 + 1, xx0 : xx1 + 1]
		rys, rxs = np.where(region)
		if len(rxs) == 0:
			continue
		x0 = int(rxs.min() + xx0)
		x1 = int(rxs.max() + xx0)
		y0 = int(rys.min() + yy0)
		y1 = int(rys.max() + yy0)
		w, h = x1 - x0 + 1, y1 - y0 + 1
		area = int(mask[y0 : y1 + 1, x0 : x1 + 1].sum())
		if h < 45 or w < 25 or area < 800:
			continue
		if w > 200:
			continue
		comps.append(
			{
				"x0": x0,
				"y0": y0 + yoff,
				"x1": x1,
				"y1": y1 + yoff,
				"w": w,
				"h": h,
				"area": area,
			}
		)
	comps.sort(key=lambda c: (c["y0"] // 50, c["x0"]))
	return comps


def assign_anims(comps: list[dict], half_name: str) -> dict[str, list[dict]]:
	"""Assign components to gameplay anims by sheet row bands (deterministic)."""
	# Row bands relative to half (absolute y already in comps).
	if half_name == "kai":
		row1 = [c for c in comps if 20 <= c["y0"] <= 160 and c["x0"] >= 300]
		row2 = [c for c in comps if 170 <= c["y0"] <= 320 and c["x0"] >= 300]
		row3 = [c for c in comps if 340 <= c["y0"] <= 500 and c["x0"] >= 300]
	else:
		row1 = [c for c in comps if 530 <= c["y0"] <= 680 and c["x0"] >= 300]
		row2 = [c for c in comps if 690 <= c["y0"] <= 840 and c["x0"] >= 300]
		row3 = [c for c in comps if 850 <= c["y0"] <= 1020 and c["x0"] >= 300]

	row1 = sorted(row1, key=lambda c: c["x0"])
	row2 = sorted(row2, key=lambda c: c["x0"])
	row3 = sorted(row3, key=lambda c: c["x0"])

	# Filter expression heads (~70x70) out of row3 body poses: prefer taller bodies.
	row3_body = [c for c in row3 if c["h"] >= 90 and c["w"] <= 100]
	row3_body = sorted(row3_body, key=lambda c: c["x0"])

	anims: dict[str, list[dict]] = {}
	# IDLE 4 + RUN 6 + JUMP rest on row1
	if len(row1) < 10:
		raise RuntimeError(f"{half_name}: row1 expected ≥10 body frames, got {len(row1)}")
	anims["idle"] = row1[0:4]
	anims["run"] = row1[4:10]
	anims["jump"] = row1[10:]

	# FALL 3 + LAND 3 + SLIDE 3 + GRAPPLE rest on row2
	if len(row2) < 9:
		raise RuntimeError(f"{half_name}: row2 expected ≥9 body frames, got {len(row2)}")
	anims["fall"] = row2[0:3]
	anims["land"] = row2[3:6]
	anims["slide"] = row2[6:9]
	anims["grapple"] = row2[9:]

	# HIT: first two tall bodies on left of row3
	if len(row3_body) < 2:
		# Fallback: any tall in row3
		row3_body = sorted([c for c in row3 if c["h"] >= 85], key=lambda c: c["x0"])
	anims["hit"] = row3_body[0:2]

	for name, frames in anims.items():
		if len(frames) < 1:
			raise RuntimeError(f"{half_name}: anim '{name}' has no frames")
	return anims


def write_character(arr: np.ndarray, half: np.ndarray, yoff: int, char_id: str) -> dict:
	comps = find_body_components(half, yoff)
	anims = assign_anims(comps, char_id)
	char_dir = OUT_ROOT / char_id / "frames"
	if char_dir.exists():
		for old in char_dir.glob("*.png"):
			old.unlink()
	char_dir.mkdir(parents=True, exist_ok=True)

	manifest = {"id": char_id, "canvas": list(CANVAS), "anims": {}}
	for anim, frames in anims.items():
		paths = []
		for i, c in enumerate(frames):
			crop = arr[c["y0"] : c["y1"] + 1, c["x0"] : c["x1"] + 1]
			canvas = place_on_canvas(crop)
			# Reject empty / nearly empty
			if (canvas[:, :, 3] > 0).sum() < 200:
				raise RuntimeError(f"{char_id}/{anim}_{i}: empty after clean")
			fname = f"{anim}_{i:02d}.png"
			Image.fromarray(canvas, "RGBA").save(char_dir / fname)
			paths.append(f"res://assets/sprites/characters/{char_id}/frames/{fname}")
		manifest["anims"][anim] = paths
		print(f"{char_id}/{anim}: {len(paths)} frames")
	(OUT_ROOT / char_id / "frames_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
	return manifest


def main() -> None:
	if not SHEET.exists():
		raise SystemExit(f"Missing sheet: {SHEET}")
	img = Image.open(SHEET).convert("RGBA")
	arr = np.array(img)
	if arr.shape[0] < 1000 or arr.shape[1] < 1500:
		raise SystemExit(f"Unexpected sheet size {arr.shape} — refusing to invent frames")
	kai = write_character(arr, arr[:512], 0, "kai")
	nova = write_character(arr, arr[512:], 512, "nova")
	# Quick coherence: same anim keys, similar frame counts
	for k in kai["anims"]:
		if k not in nova["anims"]:
			raise SystemExit(f"Nova missing anim {k}")
		dk = abs(len(kai["anims"][k]) - len(nova["anims"][k]))
		if dk > 2:
			print(f"WARN: frame count drift {k}: kai={len(kai['anims'][k])} nova={len(nova['anims'][k])}")
	print("OK extracted", SHEET.name)


if __name__ == "__main__":
	main()
