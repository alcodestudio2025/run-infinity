#!/usr/bin/env python3
"""M6.1-D.1 quality gate — provenance, anchor metrics, visual similarity.

Fail-closed. correction_complete stays false until every rework slot PASSes
with verified incoming→production provenance. Never invents frames.

Usage:
  python3 scripts/tools/m6_1_d_quality_gate.py
  python3 scripts/tools/m6_1_d_quality_gate.py --json docs/previews/m6-1-d/gate_report.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
	sys.path.insert(0, str(_TOOLS))

from m6_1_d_pipeline_lib import (  # noqa: E402
	ANCHOR_GROUND,
	ROOT,
	TRANSFORM_ID,
	anchor_drift_x,
	anchor_xy,
	classify_similarity,
	expected_output_rgba,
	load_provenance,
	load_spec,
	natural_pngs,
	pairwise_similarities,
	sha256_file,
	sha256_rgba,
	slot_anchor,
)


def frame_paths(char_id: str, anim: str) -> list[Path]:
	folder = ROOT / f"assets/sprites/characters/{char_id}/frames"
	return sorted(folder.glob(f"{anim}_*.png"))


def analyze_frame(path: Path, anchor_kind: str) -> dict:
	rgba = np.array(Image.open(path).convert("RGBA"), dtype=np.uint8)
	h, w = rgba.shape[:2]
	a = rgba[:, :, 3].astype(np.float32)
	opaque = a >= 48
	opaque_pct = float(opaque.mean() * 100.0)
	rgb = rgba[:, :, :3].astype(np.float32)
	blackish = (rgb.max(axis=2) < 18) & (a >= 48)
	black_matte_pct = float(blackish.mean() * 100.0)
	fringe = (a > 0) & (a < 48)
	fringe_pct = float(fringe.mean() * 100.0)
	ys, xs = np.where(opaque)
	if len(xs) == 0:
		bbox = [0, 0, -1, -1]
		bw = bh = 0
		touch = ["empty"]
	else:
		x0, x1 = int(xs.min()), int(xs.max())
		y0, y1 = int(ys.min()), int(ys.max())
		bbox = [x0, y0, x1, y1]
		bw, bh = x1 - x0 + 1, y1 - y0 + 1
		touch = []
		if x0 <= 0:
			touch.append("left")
		if x1 >= w - 1:
			touch.append("right")
		if y0 <= 0:
			touch.append("top")
		if y1 >= h - 1:
			touch.append("bottom")
	ax, ay = anchor_xy(rgba, anchor_kind)
	lum = 0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]
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
		"anchor_kind": anchor_kind,
		"anchor_x": None if ax != ax else round(ax, 1),
		"anchor_y": None if ay != ay else round(ay, 1),
		"touch_edges": touch,
		"sharp": round(sharp, 2),
		"sha256": sha256_file(path),
	}


def max_anchor_drift(slot: dict) -> float:
	if "max_anchor_x_drift_px" in slot:
		return float(slot["max_anchor_x_drift_px"])
	# Legacy key fallback for ground-contact slots only.
	if "max_foot_x_drift_px" in slot and slot_anchor(slot) == ANCHOR_GROUND:
		return float(slot["max_foot_x_drift_px"])
	return float(slot.get("max_anchor_x_drift_px", 10.0))


def verify_provenance(slot: dict, prod: list[Path], incoming: list[Path], game: list[int]) -> list[str]:
	reasons: list[str] = []
	prov = load_provenance(slot["id"], slot["anim"])
	if prov is None:
		reasons.append("missing import_provenance manifest")
		return reasons
	if prov.get("transform") != TRANSFORM_ID:
		reasons.append(f"unexpected transform {prov.get('transform')}")
	if int(prov.get("frame_count", -1)) != int(slot["frame_count"]):
		reasons.append("provenance frame_count mismatch")
	if list(prov.get("game_size", [])) != list(game):
		reasons.append(f"provenance game_size {prov.get('game_size')} != {game}")

	frames = prov.get("frames", [])
	if len(frames) != len(prod) or len(frames) != len(incoming):
		reasons.append(
			f"provenance frames len {len(frames)} vs prod={len(prod)} incoming={len(incoming)}"
		)
		return reasons

	gw, gh = int(game[0]), int(game[1])
	for i, (fr, src, out) in enumerate(zip(frames, incoming, prod)):
		if Path(fr.get("source_path", "")).name != src.name and fr.get("source_path") != str(
			src.relative_to(ROOT)
		).replace("\\", "/"):
			# Allow either basename match via path ending
			if not str(fr.get("source_path", "")).endswith(src.name):
				reasons.append(f"frame {i}: source_path does not match incoming {src.name}")
		if sha256_file(src) != fr.get("source_sha256"):
			reasons.append(f"frame {i}: incoming sha != provenance source_sha256")
		if sha256_file(out) != fr.get("output_sha256"):
			reasons.append(f"frame {i}: production sha != provenance output_sha256")
		expected = expected_output_rgba(src, gw, gh)
		exp_sha = sha256_rgba(expected)
		if exp_sha != fr.get("expected_output_sha256"):
			reasons.append(f"frame {i}: provenance expected hash stale vs recompute")
		out_rgba = np.array(Image.open(out).convert("RGBA"), dtype=np.uint8)
		if sha256_rgba(out_rgba) != exp_sha:
			reasons.append(f"frame {i}: production RGBA != deterministic transform of source")
	return reasons


def evaluate_slot(slot: dict, spec: dict) -> dict:
	sim_cfg = spec.get("similarity", {})
	review_thr = float(sim_cfg.get("review_threshold", 0.92))
	fail_thr = float(sim_cfg.get("fail_threshold", 0.985))
	game = list(spec["canvas_game"])
	anchor_kind = slot_anchor(slot)

	prod = frame_paths(slot["id"], slot["anim"])
	incoming = natural_pngs(ROOT / slot["incoming_dir"])
	result = {
		"id": slot["id"],
		"anim": slot["anim"],
		"priority": slot["priority"],
		"anchor": anchor_kind,
		"required_count": int(slot["frame_count"]),
		"production_count": len(prod),
		"incoming_count": len(incoming),
		"verdict": "FAIL",
		"reasons": [],
		"manual_review": [],
		"metrics": None,
		"provenance_ok": False,
	}

	if len(incoming) == 0:
		result["verdict"] = "PENDING"
		result["reasons"].append("no incoming authored PNGs")
	elif len(incoming) != int(slot["frame_count"]):
		result["verdict"] = "PENDING"
		result["reasons"].append(
			f"incoming count {len(incoming)} != required {slot['frame_count']}"
		)

	if len(prod) != int(slot["frame_count"]):
		result["reasons"].append(
			f"production frame count {len(prod)} != required {slot['frame_count']}"
		)
		if result["verdict"] != "PENDING":
			result["verdict"] = "FAIL"
		# Still attach light metrics if any prod frames exist.
		if prod:
			rgbas = [np.array(Image.open(p).convert("RGBA"), dtype=np.uint8) for p in prod]
			frames = [analyze_frame(p, anchor_kind) for p in prod]
			result["metrics"] = {
				"anchor_kind": anchor_kind,
				"anchor_x_drift": round(anchor_drift_x(rgbas, anchor_kind), 1),
				"frames": frames,
			}
		return result

	rgbas = [np.array(Image.open(p).convert("RGBA"), dtype=np.uint8) for p in prod]
	frames = [analyze_frame(p, anchor_kind) for p in prod]
	drift = anchor_drift_x(rgbas, anchor_kind)
	heights = [f["bh"] for f in frames]
	hspan = 0.0
	if heights and max(heights) > 0:
		hspan = (max(heights) - min(heights)) / max(heights) * 100.0
	pairs = pairwise_similarities(rgbas)
	fail_pairs, review_pairs = classify_similarity(pairs, review_thr, fail_thr)

	result["metrics"] = {
		"anchor_kind": anchor_kind,
		"anchor_x_drift": round(drift, 1),
		"height_span_pct": round(hspan, 1),
		"unique_hashes": len({f["sha256"] for f in frames}),
		"similarity_pairs": pairs,
		"similarity_fail": fail_pairs,
		"similarity_review": review_pairs,
		"frames": frames,
	}

	if len({f["sha256"] for f in frames}) != len(frames):
		result["reasons"].append("duplicate frame hashes in production set")

	max_drift = max_anchor_drift(slot)
	if drift > max_drift:
		result["reasons"].append(
			f"anchor_x_drift({anchor_kind}) {drift:.1f} > {max_drift}"
		)
	if hspan > float(slot["max_height_span_pct"]):
		result["reasons"].append(
			f"height_span_pct {hspan:.1f} > {slot['max_height_span_pct']}"
		)

	for fr in frames:
		if fr["size"] != game:
			result["reasons"].append(f"{fr['file']} size {fr['size']} != {game}")
		if fr["black_matte_pct"] > float(slot["max_black_matte_pct"]):
			result["reasons"].append(
				f"{fr['file']} black_matte_pct {fr['black_matte_pct']}"
			)
		if fr["fringe_pct"] > float(slot["max_fringe_pct"]):
			result["reasons"].append(f"{fr['file']} fringe_pct {fr['fringe_pct']}")
		if fr["sharp"] < float(slot["min_sharp"]):
			result["reasons"].append(
				f"{fr['file']} sharp {fr['sharp']} < {slot['min_sharp']}"
			)
		bad_touch = [t for t in fr["touch_edges"] if t in ("left", "right", "top")]
		if bad_touch and anchor_kind == ANCHOR_GROUND:
			result["reasons"].append(f"{fr['file']} touches {bad_touch}")

	# Similarity FAIL/REVIEW and provenance only enforce when incoming is complete.
	incoming_complete = len(incoming) == int(slot["frame_count"])
	if incoming_complete:
		if fail_pairs:
			result["reasons"].append(
				f"near-duplicate FAIL pairs (sim>={fail_thr}): {fail_pairs}"
			)
		if review_pairs:
			result["manual_review"].append(
				{
					"issue": "near-duplicate REVIEW",
					"threshold": review_thr,
					"pairs": review_pairs,
					"note": "manual art review required before PASS",
				}
			)
		prov_reasons = verify_provenance(slot, prod, incoming, game)
		if prov_reasons:
			result["reasons"].extend(prov_reasons)
		else:
			result["provenance_ok"] = True
	elif result["verdict"] != "PENDING":
		result["reasons"].append("cannot verify provenance without complete incoming")

	if result["verdict"] == "PENDING":
		return result

	if result["reasons"] or result["manual_review"]:
		# Manual review blocks PASS even if no hard FAIL reasons.
		if result["reasons"]:
			result["verdict"] = "FAIL"
		else:
			result["verdict"] = "REVIEW"
		return result

	if result["provenance_ok"]:
		result["verdict"] = "PASS"
	else:
		result["verdict"] = "FAIL"
		result["reasons"].append("provenance not verified")
	return result


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--json", type=Path, help="write full report JSON")
	args = parser.parse_args()
	spec = load_spec()
	slots = [evaluate_slot(s, spec) for s in spec["rework"]]
	report = {
		"milestone": "M6.1-D.1",
		"spec_status": spec.get("status"),
		"transform": TRANSFORM_ID,
		"correction_complete": False,
		"slots": slots,
		"summary": {
			"pass": sum(1 for s in slots if s["verdict"] == "PASS"),
			"fail": sum(1 for s in slots if s["verdict"] == "FAIL"),
			"pending": sum(1 for s in slots if s["verdict"] == "PENDING"),
			"review": sum(1 for s in slots if s["verdict"] == "REVIEW"),
			"total": len(slots),
		},
	}
	report["correction_complete"] = (
		report["summary"]["pass"] == report["summary"]["total"]
		and report["summary"]["total"] > 0
		and report["summary"]["review"] == 0
	)

	for s in slots:
		m = s.get("metrics") or {}
		drift = m.get("anchor_x_drift", "-")
		print(
			f"[{s['verdict']}] {s['priority']} {s['id']}/{s['anim']} "
			f"anchor={s['anchor']} prod={s['production_count']}/{s['required_count']} "
			f"incoming={s['incoming_count']} anchor_drift={drift} "
			f"prov={'OK' if s.get('provenance_ok') else 'NO'}"
		)
		for r in s["reasons"]:
			print(f"         - {r}")
		for rev in s.get("manual_review", []):
			print(f"         ~ REVIEW {rev}")

	print(
		f"Summary PASS={report['summary']['pass']} "
		f"FAIL={report['summary']['fail']} "
		f"PENDING={report['summary']['pending']} "
		f"REVIEW={report['summary']['review']} "
		f"correction_complete={report['correction_complete']}"
	)

	if args.json:
		args.json.parent.mkdir(parents=True, exist_ok=True)
		args.json.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
		print(f"Wrote {args.json}")

	if report["correction_complete"]:
		return 0
	if report["summary"]["pending"] and report["summary"]["fail"] == 0 and report["summary"]["review"] == 0:
		return 2
	if report["summary"]["review"] and report["summary"]["fail"] == 0:
		return 3  # manual review required
	return 1


if __name__ == "__main__":
	sys.exit(main())
