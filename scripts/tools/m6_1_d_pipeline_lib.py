#!/usr/bin/env python3
"""Shared M6.1-D.1 import / gate helpers.

Transform contract:
  - Preserve the *entire* source canvas, including transparent margins.
  - Only deterministic whole-canvas resize to game size.
  - No auto-trim, auto-center, or per-frame reposition.
"""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPEC_PATH = ROOT / "assets/sprites/characters/_incoming/REWORK_SPEC.json"
PNG_RE = re.compile(r".*\.png$", re.I)
RESAMPLE = Image.Resampling.LANCZOS
TRANSFORM_ID = "whole_canvas_resize_lanczos_v1"

# Anchor kinds
ANCHOR_GROUND = "ground_contact"
ANCHOR_BODY = "body_center"
ANCHOR_ATTACH = "attachment"

DEFAULT_ANIM_ANCHOR = {
	"run": ANCHOR_GROUND,
	"slide": ANCHOR_GROUND,
	"land": ANCHOR_GROUND,
	"fall": ANCHOR_BODY,
	"grapple": ANCHOR_ATTACH,
	"jump": ANCHOR_BODY,
	"idle": ANCHOR_GROUND,
	"hit": ANCHOR_BODY,
}


def load_spec() -> dict:
	data = json.loads(SPEC_PATH.read_text(encoding="utf-8"))
	if not data.get("do_not_pad_with_duplicates", True):
		raise SystemExit("SPEC must keep do_not_pad_with_duplicates=true")
	if not data.get("do_not_extract_from_sheet", True):
		raise SystemExit("SPEC must keep do_not_extract_from_sheet=true")
	return data


def natural_pngs(folder: Path) -> list[Path]:
	if not folder.is_dir():
		return []
	files = [p for p in folder.iterdir() if p.is_file() and PNG_RE.match(p.name)]

	def key(p: Path) -> tuple:
		nums = re.findall(r"\d+", p.stem)
		return (tuple(int(n) for n in nums), p.name.lower())

	return sorted(files, key=key)


def sha256_bytes(data: bytes) -> str:
	return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
	return sha256_bytes(path.read_bytes())


def sha256_rgba(rgba: np.ndarray) -> str:
	"""Hash of raw RGBA bytes (deterministic for provenance compare)."""
	if rgba.dtype != np.uint8 or rgba.ndim != 3 or rgba.shape[2] != 4:
		raise ValueError("expected HxWx4 uint8 RGBA")
	return sha256_bytes(np.ascontiguousarray(rgba).tobytes())


def hygiene_rgb_under_zero_alpha(rgba: np.ndarray) -> np.ndarray:
	"""Zero RGB only where alpha is already 0 — does not alter margins/coverage."""
	out = rgba.copy()
	out[out[:, :, 3] == 0, 0:3] = 0
	return out


def resize_whole_canvas(rgba: np.ndarray, game_w: int, game_h: int) -> np.ndarray:
	"""Deterministic whole-canvas resize. Preserves relative pivots/margins."""
	if rgba.dtype != np.uint8 or rgba.ndim != 3 or rgba.shape[2] != 4:
		raise ValueError("expected HxWx4 uint8 RGBA")
	src_h, src_w = rgba.shape[:2]
	if src_w < 1 or src_h < 1:
		raise ValueError("empty source")
	if rgba[:, :, 3].max() == 0:
		raise ValueError("blank frame (no alpha)")
	clean = hygiene_rgb_under_zero_alpha(rgba)
	if src_w == game_w and src_h == game_h:
		return clean
	im = Image.fromarray(clean, "RGBA").resize((game_w, game_h), RESAMPLE)
	return hygiene_rgb_under_zero_alpha(np.array(im, dtype=np.uint8))


def expected_output_rgba(source_path: Path, game_w: int, game_h: int) -> np.ndarray:
	rgba = np.array(Image.open(source_path).convert("RGBA"), dtype=np.uint8)
	return resize_whole_canvas(rgba, game_w, game_h)


def encode_png_bytes(rgba: np.ndarray) -> bytes:
	from io import BytesIO

	buf = BytesIO()
	Image.fromarray(rgba, "RGBA").save(buf, format="PNG", optimize=True)
	return buf.getvalue()


def slot_anchor(slot: dict) -> str:
	if "anchor" in slot:
		return str(slot["anchor"])
	return DEFAULT_ANIM_ANCHOR.get(str(slot.get("anim", "")), ANCHOR_BODY)


def _opaque_mask(a: np.ndarray, thr: int = 48) -> np.ndarray:
	return a >= thr


def anchor_xy(rgba: np.ndarray, kind: str) -> tuple[float, float]:
	"""Return (x, y) anchor in pixel space of the given canvas."""
	a = rgba[:, :, 3]
	h, w = a.shape
	opaque = _opaque_mask(a)
	if not opaque.any():
		return float("nan"), float("nan")
	ys, xs = np.where(opaque)
	if kind == ANCHOR_GROUND:
		y1 = int(ys.max())
		band = opaque[max(0, y1 - 3) : y1 + 1, :]
		bx = np.where(band)[1]
		x = float(bx.mean()) if len(bx) else float(xs.mean())
		y = float(y1)
		return x, y
	if kind == ANCHOR_ATTACH:
		# Upper quartile of opaque rows — rope / hand attachment zone.
		y_cut = float(np.quantile(ys.astype(np.float64), 0.25))
		sel = ys <= y_cut
		if not sel.any():
			sel = np.ones_like(ys, dtype=bool)
		x = float(xs[sel].mean())
		y = float(ys[sel].mean())
		return x, y
	# body_center
	x = float(xs.mean())
	y = float(ys.mean())
	return x, y


def anchor_drift_x(frames_rgba: list[np.ndarray], kind: str) -> float:
	xs = []
	for rgba in frames_rgba:
		x, _y = anchor_xy(rgba, kind)
		if x == x:
			xs.append(x)
	if not xs:
		return 0.0
	return float(max(xs) - min(xs))


def perceptual_fingerprint(rgba: np.ndarray, grid: tuple[int, int] = (16, 24)) -> np.ndarray:
	"""Low-res luma+alpha fingerprint for near-duplicate detection."""
	gw, gh = grid
	im = Image.fromarray(rgba, "RGBA").resize((gw, gh), Image.Resampling.BILINEAR)
	arr = np.array(im, dtype=np.float32)
	a = arr[:, :, 3] / 255.0
	lum = (
		0.299 * arr[:, :, 0] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2]
	) / 255.0
	return np.stack([lum * a, a], axis=-1).reshape(-1)


def fingerprint_similarity(fa: np.ndarray, fb: np.ndarray) -> float:
	"""1.0 = identical fingerprints; 0.0 = maximally different (clamped)."""
	diff = np.abs(fa.astype(np.float64) - fb.astype(np.float64))
	# Mean absolute difference on [0,1] channels → similarity
	mad = float(diff.mean())
	return max(0.0, min(1.0, 1.0 - mad))


def pairwise_similarities(frames_rgba: list[np.ndarray]) -> list[dict[str, Any]]:
	fps = [perceptual_fingerprint(r) for r in frames_rgba]
	out: list[dict[str, Any]] = []
	for i in range(len(fps)):
		for j in range(i + 1, len(fps)):
			sim = fingerprint_similarity(fps[i], fps[j])
			out.append({"i": i, "j": j, "similarity": round(sim, 4)})
	return out


def classify_similarity(
	pairs: list[dict[str, Any]], review_thr: float, fail_thr: float
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
	"""Return (fail_pairs, review_pairs). fail_thr >= review_thr."""
	fails: list[dict[str, Any]] = []
	reviews: list[dict[str, Any]] = []
	for p in pairs:
		sim = float(p["similarity"])
		if sim >= fail_thr:
			fails.append(p)
		elif sim >= review_thr:
			reviews.append(p)
	return fails, reviews


def provenance_path(char_id: str, anim: str) -> Path:
	return (
		ROOT
		/ "assets/sprites/characters"
		/ char_id
		/ "import_provenance"
		/ f"{anim}.json"
	)


def build_provenance_record(
	slot: dict,
	sources: list[Path],
	outputs: list[Path],
	game_size: list[int],
	source_size: list[int],
) -> dict:
	gw, gh = int(game_size[0]), int(game_size[1])
	frames = []
	for i, (src, out) in enumerate(zip(sources, outputs)):
		expected = expected_output_rgba(src, gw, gh)
		exp_sha = sha256_rgba(expected)
		out_rgba = np.array(Image.open(out).convert("RGBA"), dtype=np.uint8)
		frames.append(
			{
				"index": i,
				"source_path": str(src.relative_to(ROOT)).replace("\\", "/"),
				"source_sha256": sha256_file(src),
				"output_path": str(out.relative_to(ROOT)).replace("\\", "/"),
				"output_sha256": sha256_file(out),
				"expected_output_sha256": exp_sha,
				"output_rgba_sha256": sha256_rgba(out_rgba),
			}
		)
	return {
		"milestone": "M6.1-D.1",
		"id": slot["id"],
		"anim": slot["anim"],
		"transform": TRANSFORM_ID,
		"anchor": slot_anchor(slot),
		"source_size": source_size,
		"game_size": game_size,
		"frame_count": len(frames),
		"frames": frames,
	}


def write_provenance(record: dict) -> Path:
	path = provenance_path(str(record["id"]), str(record["anim"]))
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
	return path


def load_provenance(char_id: str, anim: str) -> dict | None:
	path = provenance_path(char_id, anim)
	if not path.is_file():
		return None
	return json.loads(path.read_text(encoding="utf-8"))
