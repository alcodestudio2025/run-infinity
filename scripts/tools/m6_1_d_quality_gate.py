#!/usr/bin/env python3
"""M6.1-D reproducible quality gate for rework animations.

Fails closed until every rework slot has *new* verified frames that meet
thresholds in REWORK_SPEC.json. Never invents frames; never reports PASS
while ASSETS_PENDING.

Usage:
  python3 scripts/tools/m6_1_d_quality_gate.py
  python3 scripts/tools/m6_1_d_quality_gate.py --json docs/previews/m6-1-d/gate_report.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPEC_PATH = ROOT / "assets/sprites/characters/_incoming/REWORK_SPEC.json"
INCOMING_ROOT = ROOT / "assets/sprites/characters/_incoming"


def load_spec() -> dict:
	return json.loads(SPEC_PATH.read_text(encoding="utf-8"))


def frame_paths(char_id: str, anim: str) -> list[Path]:
	folder = ROOT / f"assets/sprites/characters/{char_id}/frames"
	return sorted(folder.glob(f"{anim}_*.png"))


def incoming_pngs(slot: dict) -> list[Path]:
	folder = ROOT / slot["incoming_dir"]
	if not folder.is_dir():
		return []
	return sorted(p for p in folder.iterdir() if p.suffix.lower() == ".png")


def sha_file(path: Path) -> str:
	return hashlib.sha256(path.read_bytes()).hexdigest()


def analyze_frame(path: Path) -> dict:
	im = Image.open(path).convert("RGBA")
	arr = np.array(im)
	h, w = arr.shape[:2]
	a = arr[:, :, 3].astype(np.float32)
	opaque = a >= 48
	opaque_pct = float(opaque.mean() * 100.0)
	# Near-black RGB with usable alpha → matte residual proxy (M6.1-C aligned).
	rgb = arr[:, :, :3].astype(np.float32)
	blackish = (rgb.max(axis=2) < 18) & (a >= 48)
	black_matte_pct = float(blackish.mean() * 100.0)
	# Soft fringe below keep threshold (matches M6.1-C ~5–7% band).
	fringe = (a > 0) & (a < 48)
	fringe_pct = float(fringe.mean() * 100.0)
	ys, xs = np.where(opaque)
	if len(xs) == 0:
		bbox = [0, 0, -1, -1]
		bw = bh = 0
		foot_x = float("nan")
		touch = ["empty"]
	else:
		x0, x1 = int(xs.min()), int(xs.max())
		y0, y1 = int(ys.min()), int(ys.max())
		bbox = [x0, y0, x1, y1]
		bw, bh = x1 - x0 + 1, y1 - y0 + 1
		band = opaque[max(0, y1 - 3) : y1 + 1, :]
		fxs = np.where(band)[1]
		foot_x = float(fxs.mean()) if len(fxs) else float("nan")
		touch = []
		if x0 <= 0:
			touch.append("left")
		if x1 >= w - 1:
			touch.append("right")
		if y0 <= 0:
			touch.append("top")
		if y1 >= h - 1:
			touch.append("bottom")
	# Laplacian-ish sharpness on luminance of opaque pixels.
	lum = (0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2])
	kernel = np.array([[0, 1, 0], [1, -4, 1], [0, 1, 0]], dtype=np.float32)
	from numpy.lib.stride_tricks import sliding_window_view

	if h >= 3 and w >= 3 and opaque.any():
		windows = sliding_window_view(lum, (3, 3))
		resp = np.abs((windows * kernel).sum(axis=(-1, -2)))
		mask = opaque[1:-1, 1:-1]
		sharp = float(resp[mask].mean()) if mask.any() else 0.0
	else:
		sharp = 0.0
	return {
		"file": path.name,
		"size": [w, h],
		"bbox": bbox,
		"bw": bw,
		"bh": bh,
		"opaque_pct": round(opaque_pct, 2),
		"black_matte_pct": round(black_matte_pct, 2),
		"fringe_pct": round(fringe_pct, 2),
		"foot_x": None if foot_x != foot_x else round(foot_x, 1),
		"touch_edges": touch,
		"sharp": round(sharp, 2),
		"sha256": sha_file(path),
	}


def analyze_anim(paths: list[Path]) -> dict:
	frames = [analyze_frame(p) for p in paths]
	foots = [f["foot_x"] for f in frames if f["foot_x"] is not None]
	heights = [f["bh"] for f in frames]
	foot_drift = (max(foots) - min(foots)) if foots else 0.0
	hspan = 0.0
	if heights and max(heights) > 0:
		hspan = (max(heights) - min(heights)) / max(heights) * 100.0
	return {
		"count": len(frames),
		"frames": frames,
		"foot_x_drift": round(float(foot_drift), 1),
		"height_span_pct": round(float(hspan), 1),
		"hashes": [f["sha256"] for f in frames],
	}


def evaluate_slot(slot: dict) -> dict:
	paths = frame_paths(slot["id"], slot["anim"])
	incoming = incoming_pngs(slot)
	result = {
		"id": slot["id"],
		"anim": slot["anim"],
		"priority": slot["priority"],
		"required_count": int(slot["frame_count"]),
		"production_count": len(paths),
		"incoming_count": len(incoming),
		"verdict": "FAIL",
		"reasons": [],
		"metrics": None,
	}
	if len(incoming) == 0:
		result["verdict"] = "PENDING"
		result["reasons"].append("no incoming authored PNGs")
	elif len(incoming) != int(slot["frame_count"]):
		result["verdict"] = "PENDING"
		result["reasons"].append(
			f"incoming count {len(incoming)} != required {slot['frame_count']}"
		)

	if len(paths) != int(slot["frame_count"]):
		result["reasons"].append(
			f"production frame count {len(paths)} != required {slot['frame_count']}"
		)
		if result["verdict"] != "PENDING":
			result["verdict"] = "FAIL"
		return result

	metrics = analyze_anim(paths)
	result["metrics"] = {
		"foot_x_drift": metrics["foot_x_drift"],
		"height_span_pct": metrics["height_span_pct"],
		"unique_hashes": len(set(metrics["hashes"])),
		"frames": metrics["frames"],
	}

	# Must not be padded with duplicates.
	if len(set(metrics["hashes"])) != len(metrics["hashes"]):
		result["reasons"].append("duplicate frame hashes in production set")
		result["verdict"] = "FAIL"

	# Gate thresholds.
	if metrics["foot_x_drift"] > float(slot["max_foot_x_drift_px"]):
		result["reasons"].append(
			f"foot_x_drift {metrics['foot_x_drift']} > {slot['max_foot_x_drift_px']}"
		)
	if metrics["height_span_pct"] > float(slot["max_height_span_pct"]):
		result["reasons"].append(
			f"height_span_pct {metrics['height_span_pct']} > {slot['max_height_span_pct']}"
		)
	for fr in metrics["frames"]:
		if fr["size"] != [64, 96]:
			result["reasons"].append(f"{fr['file']} size {fr['size']} != [64,96]")
		if fr["black_matte_pct"] > float(slot["max_black_matte_pct"]):
			result["reasons"].append(
				f"{fr['file']} black_matte_pct {fr['black_matte_pct']}"
			)
		if fr["fringe_pct"] > float(slot["max_fringe_pct"]):
			result["reasons"].append(f"{fr['file']} fringe_pct {fr['fringe_pct']}")
		if fr["sharp"] < float(slot["min_sharp"]):
			result["reasons"].append(f"{fr['file']} sharp {fr['sharp']} < {slot['min_sharp']}")
		# Bottom edge touch is OK (feet). Refuse left/right/top hard clips for run/slide.
		bad_touch = [t for t in fr["touch_edges"] if t in ("left", "right", "top")]
		if bad_touch and slot["anim"] in ("run", "slide", "land"):
			result["reasons"].append(f"{fr['file']} touches {bad_touch}")

	# If incoming missing, stay PENDING even if old frames accidentally meet count.
	if result["verdict"] == "PENDING":
		# Still attach metric failures as informational.
		return result

	if result["reasons"]:
		result["verdict"] = "FAIL"
	else:
		# Require incoming present AND production metrics clean.
		if len(incoming) == int(slot["frame_count"]):
			result["verdict"] = "PASS"
		else:
			result["verdict"] = "PENDING"
			result["reasons"].append("incoming incomplete")
	return result


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--json", type=Path, help="write full report JSON")
	args = parser.parse_args()
	spec = load_spec()
	slots = [evaluate_slot(s) for s in spec["rework"]]
	report = {
		"milestone": "M6.1-D",
		"spec_status": spec.get("status"),
		"correction_complete": False,
		"slots": slots,
		"summary": {
			"pass": sum(1 for s in slots if s["verdict"] == "PASS"),
			"fail": sum(1 for s in slots if s["verdict"] == "FAIL"),
			"pending": sum(1 for s in slots if s["verdict"] == "PENDING"),
			"total": len(slots),
		},
	}
	report["correction_complete"] = (
		report["summary"]["pass"] == report["summary"]["total"]
		and report["summary"]["total"] > 0
	)

	for s in slots:
		m = s.get("metrics") or {}
		drift = m.get("foot_x_drift", "-")
		print(
			f"[{s['verdict']}] {s['priority']} {s['id']}/{s['anim']} "
			f"prod={s['production_count']}/{s['required_count']} "
			f"incoming={s['incoming_count']} foot_drift={drift}"
		)
		for r in s["reasons"]:
			print(f"         - {r}")

	print(
		f"Summary PASS={report['summary']['pass']} "
		f"FAIL={report['summary']['fail']} "
		f"PENDING={report['summary']['pending']} "
		f"correction_complete={report['correction_complete']}"
	)

	if args.json:
		args.json.parent.mkdir(parents=True, exist_ok=True)
		args.json.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
		print(f"Wrote {args.json}")

	# Exit closed: 0 only when all PASS.
	if report["correction_complete"]:
		return 0
	if report["summary"]["pending"] and report["summary"]["fail"] == 0:
		return 2  # assets still pending
	return 1


if __name__ == "__main__":
	sys.exit(main())
