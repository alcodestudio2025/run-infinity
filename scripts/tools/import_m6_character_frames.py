#!/usr/bin/env python3
"""M6.1-D: import independent authored PNG RGBA into gameplay frames.

Does NOT extract from the approved sheet. Does NOT pad with duplicates or
synthetic inbetweens. Only replaces anims that have a complete incoming drop.

Usage:
  python3 scripts/tools/import_m6_character_frames.py --status
  python3 scripts/tools/import_m6_character_frames.py --dry-run
  python3 scripts/tools/import_m6_character_frames.py
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPEC_PATH = ROOT / "assets/sprites/characters/_incoming/REWORK_SPEC.json"
ALPHA_KEEP = 48
PNG_RE = re.compile(r".*\.png$", re.I)


def load_spec() -> dict:
	data = json.loads(SPEC_PATH.read_text(encoding="utf-8"))
	if not data.get("do_not_pad_with_duplicates", True):
		raise SystemExit("SPEC must keep do_not_pad_with_duplicates=true")
	if not data.get("do_not_extract_from_sheet", True):
		raise SystemExit("SPEC must keep do_not_extract_from_sheet=true")
	return data


def natural_pngs(folder: Path) -> list[Path]:
	files = [p for p in folder.iterdir() if p.is_file() and PNG_RE.match(p.name)]
	def key(p: Path) -> tuple:
		nums = re.findall(r"\d+", p.stem)
		return (tuple(int(n) for n in nums), p.name.lower())
	return sorted(files, key=key)


def clean_alpha(rgba: np.ndarray) -> np.ndarray:
	out = rgba.copy()
	a = out[:, :, 3]
	out[a < ALPHA_KEEP, 3] = 0
	out[out[:, :, 3] == 0, 0:3] = 0
	return out


def place_on_canvas(rgba: np.ndarray, canvas_w: int, canvas_h: int) -> np.ndarray:
	"""Feet at bottom-center; optional downscale if larger than canvas."""
	rgba = clean_alpha(rgba)
	ys, xs = np.where(rgba[:, :, 3] > 0)
	if len(xs) == 0:
		raise ValueError("empty alpha — refuse blank frame")
	x0, x1 = int(xs.min()), int(xs.max())
	y0, y1 = int(ys.min()), int(ys.max())
	trimmed = rgba[y0 : y1 + 1, x0 : x1 + 1]
	th, tw = trimmed.shape[:2]
	scale = min(1.0, (canvas_w - 4) / max(tw, 1), (canvas_h - 4) / max(th, 1))
	if scale < 0.999:
		nw = max(1, int(round(tw * scale)))
		nh = max(1, int(round(th * scale)))
		trimmed = np.array(
			Image.fromarray(trimmed, "RGBA").resize((nw, nh), Image.Resampling.LANCZOS)
		)
		th, tw = trimmed.shape[:2]
	if th > canvas_h or tw > canvas_w:
		raise ValueError(f"content {tw}x{th} exceeds canvas {canvas_w}x{canvas_h}")
	canvas = np.zeros((canvas_h, canvas_w, 4), dtype=np.uint8)
	dest_y = canvas_h - th - 2
	dest_x = (canvas_w - tw) // 2
	dest_y = max(0, dest_y)
	dest_x = max(0, min(dest_x, canvas_w - tw))
	canvas[dest_y : dest_y + th, dest_x : dest_x + tw] = trimmed
	return canvas


def sha256_bytes(data: bytes) -> str:
	return hashlib.sha256(data).hexdigest()


def validate_drop(slot: dict, paths: list[Path], accepted_sizes: list[list[int]]) -> None:
	need = int(slot["frame_count"])
	if len(paths) != need:
		raise ValueError(
			f"{slot['id']}/{slot['anim']}: need exactly {need} PNGs, found {len(paths)} "
			"(refusing to pad with duplicates)"
		)
	hashes: list[str] = []
	accepted = {tuple(s) for s in accepted_sizes}
	for p in paths:
		im = Image.open(p).convert("RGBA")
		if tuple(im.size) not in accepted:
			raise ValueError(
				f"{p}: size {im.size} not in accepted {sorted(accepted)}"
			)
		arr = np.array(im)
		if arr[:, :, 3].max() < ALPHA_KEEP:
			raise ValueError(f"{p}: no opaque pixels")
		# Adjacent duplicate check on source bytes.
		h = sha256_bytes(p.read_bytes())
		if hashes and h == hashes[-1]:
			raise ValueError(f"{p}: identical to previous frame — refuse duplicates")
		hashes.append(h)
	if len(set(hashes)) < len(hashes):
		raise ValueError(f"{slot['id']}/{slot['anim']}: non-unique frames in drop")


def update_manifest(char_id: str, anim: str, frame_count: int, canvas: list[int]) -> None:
	manifest_path = ROOT / f"assets/sprites/characters/{char_id}/frames_manifest.json"
	data = json.loads(manifest_path.read_text(encoding="utf-8"))
	paths = [
		f"res://assets/sprites/characters/{char_id}/frames/{anim}_{i:02d}.png"
		for i in range(frame_count)
	]
	data.setdefault("anims", {})[anim] = paths
	data["canvas"] = canvas
	data["id"] = char_id
	manifest_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def slot_status(slot: dict, accepted_sizes: list[list[int]]) -> dict:
	folder = ROOT / slot["incoming_dir"]
	paths = natural_pngs(folder) if folder.is_dir() else []
	info = {
		"id": slot["id"],
		"anim": slot["anim"],
		"priority": slot["priority"],
		"required": int(slot["frame_count"]),
		"found": len(paths),
		"ready": False,
		"error": None,
	}
	if not paths:
		info["error"] = "no PNGs yet"
		return info
	try:
		validate_drop(slot, paths, accepted_sizes)
		info["ready"] = True
	except ValueError as exc:
		info["error"] = str(exc)
	return info


def import_slot(slot: dict, canvas: list[int], accepted_sizes: list[list[int]], dry_run: bool) -> None:
	folder = ROOT / slot["incoming_dir"]
	paths = natural_pngs(folder)
	validate_drop(slot, paths, accepted_sizes)
	cw, ch = int(canvas[0]), int(canvas[1])
	out_dir = ROOT / f"assets/sprites/characters/{slot['id']}/frames"
	# Remove prior frames for this anim only (including extras beyond new count).
	for old in out_dir.glob(f"{slot['anim']}_*.png"):
		if dry_run:
			print(f"  dry-run would remove {old.relative_to(ROOT)}")
		else:
			old.unlink()
			imp = Path(str(old) + ".import")
			if imp.exists():
				imp.unlink()
	for i, src in enumerate(paths):
		rgba = np.array(Image.open(src).convert("RGBA"))
		placed = place_on_canvas(rgba, cw, ch)
		dest = out_dir / f"{slot['anim']}_{i:02d}.png"
		if dry_run:
			print(f"  dry-run would write {dest.relative_to(ROOT)} from {src.name}")
			continue
		Image.fromarray(placed, "RGBA").save(dest)
		print(f"  wrote {dest.relative_to(ROOT)}")
	if not dry_run:
		update_manifest(slot["id"], slot["anim"], int(slot["frame_count"]), canvas)


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--status", action="store_true", help="list rework slot readiness")
	parser.add_argument("--dry-run", action="store_true", help="validate without writing")
	parser.add_argument(
		"--only",
		action="append",
		default=[],
		help="limit to id/anim (e.g. kai/run); repeatable",
	)
	args = parser.parse_args()
	spec = load_spec()
	canvas = list(spec["canvas_game"])
	accepted = list(spec["source_resolution_accepted"])
	slots = spec["rework"]
	if args.only:
		wanted = set(args.only)
		slots = [s for s in slots if f"{s['id']}/{s['anim']}" in wanted]
		if not slots:
			print("No matching --only slots", file=sys.stderr)
			return 1

	statuses = [slot_status(s, accepted) for s in slots]
	if args.status:
		for st in statuses:
			mark = "READY" if st["ready"] else "PENDING"
			extra = "" if st["ready"] else f" — {st['error']}"
			print(
				f"[{mark}] {st['priority']} {st['id']}/{st['anim']} "
				f"{st['found']}/{st['required']}{extra}"
			)
		ready_n = sum(1 for s in statuses if s["ready"])
		print(f"Ready {ready_n}/{len(statuses)}; milestone={spec.get('status')}")
		return 0

	ready_slots = [s for s, st in zip(slots, statuses) if st["ready"]]
	blocked = [st for st in statuses if not st["ready"]]
	if not ready_slots:
		print("No complete incoming drops to import.", file=sys.stderr)
		for st in blocked:
			print(f"  PENDING {st['id']}/{st['anim']}: {st['error']}", file=sys.stderr)
		print("Refusing to invent frames. Drop authored PNGs under _incoming/.", file=sys.stderr)
		return 2

	for slot in ready_slots:
		print(f"Importing {slot['id']}/{slot['anim']} ({slot['frame_count']} frames)…")
		try:
			import_slot(slot, canvas, accepted, dry_run=args.dry_run)
		except ValueError as exc:
			print(f"FAIL {slot['id']}/{slot['anim']}: {exc}", file=sys.stderr)
			return 1

	for st in blocked:
		print(f"SKIP PENDING {st['id']}/{st['anim']}: {st['error']}")

	if args.dry_run:
		print("Dry-run OK — no files written.")
	else:
		print(
			"Import OK for ready slots. Next:\n"
			"  godot --headless --path . --import --quit\n"
			"  godot --headless --path . -s res://scripts/ci/m6_1_b_build_sprite_frames.gd\n"
			"  python3 scripts/tools/m6_1_d_quality_gate.py"
		)
	return 0


if __name__ == "__main__":
	sys.exit(main())
