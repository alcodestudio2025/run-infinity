#!/usr/bin/env python3
"""M6.1-F — Skeleton2D POC scaffold gate (Option A).

Refuses to emit a Godot skeletal scene until authored cutout parts meet the
quality bar. Colored rectangles and soft sheet band-cuts are rejected.

  python3 scripts/tools/m6_1_f_skeletal_poc_scaffold.py --status
  python3 scripts/tools/m6_1_f_skeletal_poc_scaffold.py
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PARTS_DIR = ROOT / "assets/sprites/characters/_incoming/kai/cutout_parts"
SPEC_PATH = PARTS_DIR / "PART_PLATE_SPEC.json"
FEASIBILITY = ROOT / "docs/previews/m6-1-f/feasibility_report.json"
SCENE_OUT = ROOT / "scenes/dev/m6_1_f_kai_skeletal_poc.tscn"

REQUIRED = [
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

MIN_EDGE = 64
MIN_OPAQUE_PCT = 8.0
# Reject near-solid single-hue placeholders (fake rectangles).
MAX_DOMINANT_HUE_SHARE = 0.92


def load_spec() -> dict:
    if SPEC_PATH.is_file():
        return json.loads(SPEC_PATH.read_text(encoding="utf-8"))
    return {
        "required_parts": REQUIRED,
        "min_edge_px": MIN_EDGE,
        "min_opaque_pct": MIN_OPAQUE_PCT,
        "forbid_rect_placeholders": True,
        "canon_option": "A",
    }


def analyze_part(path: Path) -> dict:
    im = Image.open(path).convert("RGBA")
    arr = np.array(im)
    a = arr[:, :, 3]
    opaque = a > 8
    opaque_pct = float(opaque.mean() * 100.0)
    w, h = im.size
    min_edge = min(w, h)
    issues: list[str] = []
    if min_edge < MIN_EDGE:
        issues.append(f"min_edge {min_edge} < {MIN_EDGE}")
    if opaque_pct < MIN_OPAQUE_PCT:
        issues.append(f"opaque_pct {opaque_pct:.1f} < {MIN_OPAQUE_PCT}")

    # Placeholder heuristic: mostly one flat RGB among opaque pixels.
    if opaque.any():
        rgb = arr[:, :, :3][opaque]
        # quantize to reduce noise
        q = (rgb // 16) * 16
        # count dominant bucket
        # flat view as structured dtype for unique rows
        view = q.view([("r", q.dtype), ("g", q.dtype), ("b", q.dtype)]).reshape(-1)
        _, counts = np.unique(view, return_counts=True)
        share = float(counts.max() / counts.sum()) if len(counts) else 1.0
        if share >= MAX_DOMINANT_HUE_SHARE and opaque_pct > 40:
            issues.append(
                f"likely_rect_placeholder (dominant_bucket_share={share:.2f})"
            )
    else:
        issues.append("fully_transparent")

    try:
        rel = str(path.relative_to(ROOT))
    except ValueError:
        rel = str(path)
    return {
        "path": rel,
        "size": [w, h],
        "opaque_pct": round(opaque_pct, 2),
        "ok": len(issues) == 0,
        "issues": issues,
    }


def evaluate() -> dict:
    spec = load_spec()
    required = list(spec.get("required_parts") or REQUIRED)
    results = []
    missing = []
    for name in required:
        path = PARTS_DIR / f"{name}.png"
        if not path.is_file():
            missing.append(name)
            results.append(
                {
                    "part": name,
                    "ok": False,
                    "issues": ["missing_file"],
                }
            )
            continue
        info = analyze_part(path)
        info["part"] = name
        results.append(info)

    # Reject known auto-cut evidence directory if someone copies it in.
    auto_cut = ROOT / "docs/previews/m6-1-f/auto_cut_parts"
    notes = []
    if auto_cut.is_dir():
        notes.append(
            "docs/previews/m6-1-f/auto_cut_parts are feasibility evidence only — "
            "not valid POC textures."
        )

    all_ok = not missing and all(r.get("ok") for r in results)
    verdict = "GO_PARTS_READY" if all_ok else "NO_GO_QUALITY_PARTS"
    return {
        "verdict": verdict,
        "parts_dir": str(PARTS_DIR.relative_to(ROOT)),
        "missing": missing,
        "parts": results,
        "notes": notes,
        "scene_emitted": False,
        "option_a_locked": True,
        "experimental_frame00_canonical": False,
    }


def emit_blocked_status(report: dict) -> None:
    """Write a small JSON status next to the drop slot; never emit a fake scene."""
    PARTS_DIR.mkdir(parents=True, exist_ok=True)
    status_path = PARTS_DIR / "SCAFFOLD_STATUS.json"
    status_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--status",
        action="store_true",
        help="Print evaluation only; do not attempt scene emission.",
    )
    ap.add_argument(
        "--force-emit-blocked-marker",
        action="store_true",
        help="Always write SCAFFOLD_STATUS.json even on --status.",
    )
    args = ap.parse_args(argv)

    report = evaluate()
    if FEASIBILITY.is_file():
        try:
            feas = json.loads(FEASIBILITY.read_text(encoding="utf-8"))
            report["feasibility_verdict"] = feas.get("verdict")
        except json.JSONDecodeError:
            pass

    print(json.dumps(report, indent=2))

    if args.status:
        if args.force_emit_blocked_marker:
            emit_blocked_status(report)
        return 0 if report["verdict"] == "GO_PARTS_READY" else 2

    # Full run: only emit Godot scene when GO. Otherwise refuse.
    emit_blocked_status(report)
    if report["verdict"] != "GO_PARTS_READY":
        print(
            "\nREFUSED: no Skeleton2D scene written. "
            "Provide Option A authored cutout parts meeting PART_PLATE_SPEC.json. "
            "Rectangles / band-cuts are not accepted.",
            file=sys.stderr,
        )
        if SCENE_OUT.is_file():
            print(
                f"NOTE: stale scene present at {SCENE_OUT.relative_to(ROOT)} — "
                "do not treat as approved until gate is GO.",
                file=sys.stderr,
            )
        return 2

    # Future: emit real Skeleton2D scene from validated parts.
    # Intentionally not implemented until parts exist — avoids shipping empty rigs.
    print(
        "Parts GO — scene emitter not yet implemented in this milestone "
        "(waiting on art delivery). Status recorded."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
