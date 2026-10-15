#!/usr/bin/env python3
"""M6.1-D.1: import independent authored PNG RGBA into gameplay frames.

Whole-canvas resize only — preserves artist pivots/margins.
Does NOT extract from sheet, pad with duplicates, trim, or re-center.

Usage:
  python3 scripts/tools/import_m6_character_frames.py --status
  python3 scripts/tools/import_m6_character_frames.py --dry-run
  python3 scripts/tools/import_m6_character_frames.py
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
	ROOT,
	TRANSFORM_ID,
	build_provenance_record,
	load_spec,
	natural_pngs,
	resize_whole_canvas,
	sha256_bytes,
	sha256_file,
	slot_anchor,
	write_provenance,
)


def validate_drop(slot: dict, paths: list[Path], accepted_sizes: list[list[int]]) -> list[int]:
	need = int(slot["frame_count"])
	if len(paths) != need:
		raise ValueError(
			f"{slot['id']}/{slot['anim']}: need exactly {need} PNGs, found {len(paths)} "
			"(refusing to pad with duplicates)"
		)
	hashes: list[str] = []
	accepted = {tuple(s) for s in accepted_sizes}
	source_size: list[int] | None = None
	for p in paths:
		im = Image.open(p).convert("RGBA")
		size = list(im.size)
		if tuple(size) not in accepted:
			raise ValueError(f"{p}: size {im.size} not in accepted {sorted(accepted)}")
		if source_size is None:
			source_size = size
		elif size != source_size:
			raise ValueError(
				f"{p}: mixed source sizes in drop ({size} vs {source_size})"
			)
		arr = np.array(im)
		if arr[:, :, 3].max() == 0:
			raise ValueError(f"{p}: blank alpha")
		h = sha256_bytes(p.read_bytes())
		if hashes and h == hashes[-1]:
			raise ValueError(f"{p}: identical to previous frame — refuse duplicates")
		hashes.append(h)
	if len(set(hashes)) < len(hashes):
		raise ValueError(f"{slot['id']}/{slot['anim']}: non-unique frames in drop")
	assert source_size is not None
	return source_size


def update_frames_manifest(char_id: str, anim: str, frame_count: int, canvas: list[int]) -> None:
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
	paths = natural_pngs(folder)
	info = {
		"id": slot["id"],
		"anim": slot["anim"],
		"priority": slot["priority"],
		"anchor": slot_anchor(slot),
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


def import_slot(
	slot: dict, canvas: list[int], accepted_sizes: list[list[int]], dry_run: bool
) -> None:
	folder = ROOT / slot["incoming_dir"]
	paths = natural_pngs(folder)
	source_size = validate_drop(slot, paths, accepted_sizes)
	cw, ch = int(canvas[0]), int(canvas[1])
	out_dir = ROOT / f"assets/sprites/characters/{slot['id']}/frames"
	out_dir.mkdir(parents=True, exist_ok=True)

	for old in out_dir.glob(f"{slot['anim']}_*.png"):
		if dry_run:
			print(f"  dry-run would remove {old.relative_to(ROOT)}")
		else:
			old.unlink()
			imp = Path(str(old) + ".import")
			if imp.exists():
				imp.unlink()

	written: list[Path] = []
	for i, src in enumerate(paths):
		rgba = np.array(Image.open(src).convert("RGBA"), dtype=np.uint8)
		placed = resize_whole_canvas(rgba, cw, ch)
		dest = out_dir / f"{slot['anim']}_{i:02d}.png"
		if dry_run:
			print(
				f"  dry-run would write {dest.relative_to(ROOT)} "
				f"from {src.name} via {TRANSFORM_ID} ({source_size}->[{cw},{ch}])"
			)
			continue
		Image.fromarray(placed, "RGBA").save(dest)
		written.append(dest)
		print(f"  wrote {dest.relative_to(ROOT)} sha={sha256_file(dest)[:12]}…")

	if dry_run:
		return

	update_frames_manifest(slot["id"], slot["anim"], int(slot["frame_count"]), canvas)
	record = build_provenance_record(slot, paths, written, canvas, source_size)
	# Sanity: every output must match expected transform hash.
	for fr in record["frames"]:
		if fr["output_rgba_sha256"] != fr["expected_output_sha256"]:
			raise ValueError(
				f"provenance mismatch frame {fr['index']}: "
				"output RGBA != expected transform"
			)
	prov = write_provenance(record)
	print(f"  provenance {prov.relative_to(ROOT)} anchor={record['anchor']}")


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--status", action="store_true")
	parser.add_argument("--dry-run", action="store_true")
	parser.add_argument("--only", action="append", default=[])
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
				f"anchor={st['anchor']} {st['found']}/{st['required']}{extra}"
			)
		print(
			f"Ready {sum(1 for s in statuses if s['ready'])}/{len(statuses)}; "
			f"milestone={spec.get('status')}"
		)
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
		print(
			f"Importing {slot['id']}/{slot['anim']} "
			f"({slot['frame_count']} frames, anchor={slot_anchor(slot)})…"
		)
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
