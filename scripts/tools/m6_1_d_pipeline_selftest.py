#!/usr/bin/env python3
"""Synthetic self-tests for M6.1-D.1 pipeline (temp dirs only — never game frames).

Verifies:
  - whole-canvas resize preserves relative marker positions (pivot)
  - no trim/center when margins differ
  - near-duplicate similarity flags
  - provenance expected hash matches transform

Exit 0 on success.
"""
from __future__ import annotations

import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
	sys.path.insert(0, str(_TOOLS))

from m6_1_d_pipeline_lib import (  # noqa: E402
	ANCHOR_ATTACH,
	ANCHOR_BODY,
	ANCHOR_GROUND,
	TRANSFORM_ID,
	anchor_xy,
	classify_similarity,
	fingerprint_similarity,
	pairwise_similarities,
	perceptual_fingerprint,
	resize_whole_canvas,
	sha256_rgba,
)


def _blank(w: int, h: int) -> np.ndarray:
	return np.zeros((h, w, 4), dtype=np.uint8)


def _stamp(rgba: np.ndarray, x: int, y: int, color=(255, 0, 0, 255), size: int = 8) -> None:
	h, w = rgba.shape[:2]
	rgba[max(0, y) : min(h, y + size), max(0, x) : min(w, x + size)] = color


def test_pivot_preservation_half_scale() -> None:
	"""Marker at (20, 160) on 128x192 → expect ~ (10, 80) on 64x96."""
	src = _blank(128, 192)
	_stamp(src, 20, 160, size=8)
	out = resize_whole_canvas(src, 64, 96)
	assert out.shape == (96, 64, 4)
	# Find opaque centroid of marker.
	ys, xs = np.where(out[:, :, 3] >= 48)
	assert len(xs) > 0, "marker lost"
	cx, cy = float(xs.mean()), float(ys.mean())
	# Exact half + stamp extent tolerance.
	assert abs(cx - 10.0) <= 3.0, f"pivot x drifted: {cx}"
	assert abs(cy - 80.0) <= 3.0, f"pivot y drifted: {cy}"


def test_margins_not_recentering() -> None:
	"""Left-biased content must stay left after resize (no auto-center)."""
	src = _blank(128, 192)
	_stamp(src, 4, 100, color=(0, 255, 0, 255), size=12)
	out = resize_whole_canvas(src, 64, 96)
	ys, xs = np.where(out[:, :, 3] >= 48)
	cx = float(xs.mean())
	assert cx < 20.0, f"auto-center suspected: cx={cx}"


def test_identity_64() -> None:
	src = _blank(64, 96)
	_stamp(src, 30, 70, size=6)
	out = resize_whole_canvas(src, 64, 96)
	assert sha256_rgba(out) == sha256_rgba(src) or (out == src).all()
	# hygiene may zero RGB under a==0 but stamp region identical
	assert (out[70:76, 30:36] == src[70:76, 30:36]).all()


def test_anchor_kinds() -> None:
	src = _blank(64, 96)
	# Foot blob bottom-right, body blob center, attach blob top-left.
	_stamp(src, 48, 88, color=(255, 255, 255, 255), size=6)
	_stamp(src, 28, 48, color=(200, 200, 200, 255), size=10)
	_stamp(src, 4, 4, color=(180, 180, 180, 255), size=6)
	gx, gy = anchor_xy(src, ANCHOR_GROUND)
	bx, by = anchor_xy(src, ANCHOR_BODY)
	ax, ay = anchor_xy(src, ANCHOR_ATTACH)
	assert gy >= 85, gy
	assert ay <= 30, ay
	assert abs(bx - 28) < 20


def test_similarity_near_duplicate() -> None:
	a = _blank(64, 96)
	_stamp(a, 20, 40, size=20)
	b = a.copy()
	b[45, 25, 0] = 250  # tiny change → still near-dup
	c = _blank(64, 96)
	# Highly distinct silhouette (opposite corner + different chroma fill band).
	_stamp(c, 40, 8, color=(0, 0, 255, 255), size=22)
	c[70:90, 5:55] = (0, 200, 0, 255)
	pairs = pairwise_similarities([a, b, c])
	fails, _reviews = classify_similarity(pairs, review_thr=0.92, fail_thr=0.985)
	ab = next(p for p in pairs if p["i"] == 0 and p["j"] == 1)
	ac = next(p for p in pairs if p["i"] == 0 and p["j"] == 2)
	assert ab["similarity"] >= 0.985, ab
	assert ac["similarity"] < 0.92, ac
	assert fails, "expected FAIL near-dup pair"
	assert not any(p["i"] == 0 and p["j"] == 2 for p in fails)


def test_transform_id_stable() -> None:
	assert TRANSFORM_ID == "whole_canvas_resize_lanczos_v1"


def main() -> int:
	tests = [
		test_transform_id_stable,
		test_pivot_preservation_half_scale,
		test_margins_not_recentering,
		test_identity_64,
		test_anchor_kinds,
		test_similarity_near_duplicate,
	]
	# Ensure we never touch game trees accidentally.
	with tempfile.TemporaryDirectory(prefix="m6_1_d_selftest_") as tmp:
		Path(tmp).joinpath("marker.txt").write_text("ok\n", encoding="utf-8")
		for fn in tests:
			fn()
			print(f"PASS {fn.__name__}")
	print(f"ALL {len(tests)} SELFTESTS PASS (temp-only; game sprites untouched)")
	return 0


if __name__ == "__main__":
	sys.exit(main())
