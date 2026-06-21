"""Bake a complete terrain/elevation tile set from concept UV candidates."""

from __future__ import annotations

import argparse
import json
import os
import sys
import traceback
from pathlib import Path


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import bake_assets  # noqa: E402


TERRAINS = ("grass", "dirt", "stone", "water")
ELEVATIONS = (0, 1, 2)


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _rel(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(_repo_root()).as_posix()
    except ValueError:
        return str(resolved)


def build_manifest(pipeline: dict) -> dict:
    cfg = bake_assets.CONFIG
    assets: dict[str, dict] = {}
    for terrain in TERRAINS:
        for elevation in ELEVATIONS:
            key = f"tile_{terrain}_e{elevation}"
            filename = f"{key}_v0.png"
            assets[key] = {
                "file": filename,
                "variants": [filename],
                "kind": "tile",
                "terrain": terrain,
                "elevation": elevation,
                "anchor_px": [cfg["canvas_px"] * 0.5, cfg["canvas_px"] * 0.5],
                "size_px": [cfg["canvas_px"], cfg["canvas_px"]],
            }
    return {
        "comment": "Concept UV candidate bake set. Source raw style: docs/concept.jpg. No fable texture/decor referenced.",
        "pipeline": pipeline["id"],
        "pipeline_name": pipeline["zh_name"],
        "pitch_deg": cfg["pitch_deg"],
        "yaw_deg": cfg["yaw_deg"],
        "hex_orientation": "flat_top",
        "sun_elevation_deg": cfg["sun_elevation_deg"],
        "sun_azimuth_deg": cfg["sun_azimuth_deg"],
        "px_per_unit": cfg["px_per_unit"],
        "hex_edge_world": cfg["hex_edge"],
        "px_per_hex_edge": cfg["px_per_unit"] * cfg["hex_edge"],
        "thickness_world": cfg["thickness"],
        "elevation_step_world": cfg["elevation_step"],
        "water_recess_world": cfg["water_recess"],
        "assets": assets,
    }


def bake_set(uv_dir: Path, out_dir: Path, pipeline_mode: str, samples: int, ink_enabled: bool) -> dict:
    pipeline = bake_assets.apply_tile_pipeline_mode(pipeline_mode)
    bake_assets.CONFIG["samples"] = samples
    bake_assets.CONFIG["ink_enabled"] = ink_enabled
    out_dir.mkdir(parents=True, exist_ok=True)
    results: dict[str, dict] = {}

    for terrain in TERRAINS:
        for elevation in ELEVATIONS:
            key = f"{terrain}_e{elevation}"
            uv_path = uv_dir / f"{key}_warp_uv.png"
            if not uv_path.exists():
                raise FileNotFoundError(str(uv_path))
            out_path = out_dir / f"tile_{terrain}_e{elevation}_v0.png"
            bake_assets.bake_tile_candidate(str(uv_path), terrain, elevation, str(out_path))
            results[key] = {"uv": _rel(uv_path), "baked": _rel(out_path)}

    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(build_manifest(pipeline), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    report = {
        "source_script": _rel(Path(__file__)),
        "pipeline": pipeline,
        "pipeline_mode": pipeline_mode,
        "uv_dir": _rel(uv_dir),
        "out_dir": _rel(out_dir),
        "manifest": _rel(manifest_path),
        "samples": samples,
        "ink_enabled": ink_enabled,
        "mesh_contract": {
            "type": "standard_hex_prism",
            "tile_bevel_enabled": bake_assets.CONFIG.get("tile_bevel_enabled"),
            "tile_smooth_enabled": bake_assets.CONFIG.get("tile_smooth_enabled"),
            "bevel_width": bake_assets.CONFIG.get("bevel_width"),
            "bevel_segments": bake_assets.CONFIG.get("bevel_segments"),
        },
        "config_snapshot": dict(bake_assets.CONFIG),
        "results": results,
    }
    report_path = out_dir / "bake_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report["bake_report"] = _rel(report_path)
    return report


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pipeline", required=True)
    parser.add_argument("--uv-dir", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=32)
    parser.add_argument("--ink", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = bake_set(args.uv_dir.resolve(), args.out_dir.resolve(), args.pipeline, args.samples, args.ink)
        print(json.dumps({"ok": True, **result}, ensure_ascii=False, indent=2))
        return 0
    except Exception as exc:
        print(json.dumps({
            "ok": False,
            "error": repr(exc),
            "traceback": traceback.format_exc(),
        }, ensure_ascii=False, indent=2))
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []))
