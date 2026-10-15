#!/usr/bin/env python3
"""M6.1-G — Validate part-plate contracts (no scene emission, no placeholders).

Checks PART_PLATE_SPEC / PIVOT_SCHEMA / ASSET_AUDIT consistency and reports
whether authored PNGs are present. Never writes Skeleton2D scenes or fake art.

  python3 scripts/tools/m6_1_g_part_plate_validate.py
  python3 scripts/tools/m6_1_g_part_plate_validate.py --json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PARTS_DIR = ROOT / "assets/sprites/characters/_incoming/kai/cutout_parts"
SPEC_PATH = PARTS_DIR / "PART_PLATE_SPEC.json"
PIVOT_PATH = PARTS_DIR / "PIVOT_SCHEMA.json"
AUDIT_PATH = PARTS_DIR / "ASSET_AUDIT.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def evaluate() -> dict:
    issues: list[str] = []
    warnings: list[str] = []

    for path in (SPEC_PATH, PIVOT_PATH, AUDIT_PATH):
        if not path.is_file():
            issues.append(f"missing_contract:{path.relative_to(ROOT)}")

    if issues:
        return {
            "verdict": "NO_GO_CONTRACT",
            "issues": issues,
            "warnings": warnings,
            "png_present": [],
            "png_missing": [],
        }

    spec = load(SPEC_PATH)
    pivot = load(PIVOT_PATH)
    audit = load(AUDIT_PATH)

    required = list(spec.get("required_parts") or [])
    if not required:
        issues.append("spec.required_parts empty")

    bones = spec.get("hierarchy", {}).get("bones") or []
    bone_sprites = {
        b.get("sprite") for b in bones if b.get("sprite")
    }
    for part in required:
        if part not in bone_sprites:
            issues.append(f"hierarchy_missing_sprite:{part}")

    pivots = pivot.get("pivots") or {}
    for part in required:
        if part not in pivots:
            issues.append(f"pivot_missing:{part}")
        else:
            entry = pivots[part]
            uv = entry.get("pivot_uv")
            if not (
                isinstance(uv, list)
                and len(uv) == 2
                and all(isinstance(v, (int, float)) for v in uv)
                and 0.0 <= float(uv[0]) <= 1.0
                and 0.0 <= float(uv[1]) <= 1.0
            ):
                issues.append(f"pivot_uv_invalid:{part}")

    checklist = (
        (audit.get("checklist") or {}).get("required_for_run_poc") or []
    )
    audit_parts = {row.get("part") for row in checklist}
    for part in required:
        if part not in audit_parts:
            issues.append(f"audit_missing:{part}")

    if spec.get("canon_option") != "A":
        issues.append("canon_option_not_A")
    if spec.get("experimental_frame00_canonical") is not False:
        issues.append("experimental_frame00_must_be_false")

    png_present: list[str] = []
    png_missing: list[str] = []
    for part in required:
        path = PARTS_DIR / f"{part}.png"
        if path.is_file():
            png_present.append(part)
        else:
            png_missing.append(part)

    if png_present:
        warnings.append(
            "PNG files present — run m6_1_f_skeletal_poc_scaffold.py for quality gate"
        )
    else:
        warnings.append(
            "no authored PNGs — SPEC_READY_BLOCKED_ON_ART (expected until artist delivery)"
        )

    auto_cut = ROOT / "docs/previews/m6-1-f/auto_cut_parts"
    if auto_cut.is_dir():
        warnings.append(
            "auto_cut_parts remain feasibility evidence only — do not copy into drop slot"
        )

    if issues:
        verdict = "NO_GO_CONTRACT"
    elif png_missing:
        verdict = "SPEC_READY_BLOCKED_ON_ART"
    else:
        verdict = "PARTS_ON_DISK_RUN_SCAFFOLD_GATE"

    return {
        "verdict": verdict,
        "milestone": "M6.1-G",
        "parts_dir": str(PARTS_DIR.relative_to(ROOT)),
        "required_count": len(required),
        "png_present": png_present,
        "png_missing": png_missing,
        "issues": issues,
        "warnings": warnings,
        "do_not_touch_character_visual": True,
        "forbid_rect_placeholders": True,
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true", help="Print JSON only")
    args = ap.parse_args(argv)
    report = evaluate()
    text = json.dumps(report, indent=2) + "\n"
    sys.stdout.write(text)
    if report["verdict"] == "NO_GO_CONTRACT":
        return 2
    # Spec ready / parts on disk are success for this validator.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
