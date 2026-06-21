"""Bake concept-style explicit top-edge bevel tile assets for art exploration."""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
import traceback
from pathlib import Path

import bpy


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import bake_assets  # noqa: E402
from texgen import geometry, tile_pipeline_modes  # noqa: E402


TERRAINS = ("grass", "dirt", "stone", "water")
ELEVATIONS = (0, 1, 2)
BEVEL_INSET_WORLD = 0.055
BEVEL_DROP_WORLD = 0.035


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _face_poly(face: dict) -> list:
    return face.get("polygon_px") or face["quad_px"]


def _bevel_world(manifest: dict, elevation: int) -> dict:
    edge = float(manifest["hex_edge_world"])
    depth = geometry.tile_depth(manifest, elevation)
    radial_shrink = BEVEL_INSET_WORLD / math.cos(math.radians(30.0))
    inner_edge = max(0.01, edge - radial_shrink)
    inner = [(x, y, 0.0) for x, y in [geometry.hex_corner(i, inner_edge) for i in range(6)]]
    outer = [(x, y, -BEVEL_DROP_WORLD) for x, y in [geometry.hex_corner(i, edge) for i in range(6)]]
    bottom = [(x, y, -depth) for x, y in [geometry.hex_corner(i, edge) for i in range(6)]]
    return {"inner": inner, "outer": outer, "bottom": bottom}


def _build_beveled_mesh(uv_path: Path, uv_sidecar_path: Path, elevation: int):
    manifest = geometry.load_manifest()
    uv = _read_json(uv_sidecar_path)
    w = _bevel_world(manifest, elevation)
    verts = []
    verts.extend(w["inner"])
    verts.extend(w["outer"])
    verts.extend(w["bottom"])

    face_defs = [("top", [0, 1, 2, 3, 4, 5])]
    for i in range(6):
        face_defs.append((f"bevel_{i}", [i, (i + 1) % 6, 6 + ((i + 1) % 6), 6 + i]))
    for i in range(6):
        face_name = f"wall_{i}"
        mapped = face_name if face_name in uv["faces"] else f"wall_{(i + 3) % 6}"
        face_defs.append((mapped, [6 + i, 6 + ((i + 1) % 6), 12 + ((i + 1) % 6), 12 + i]))
    face_defs.append(("bottom", [17, 16, 15, 14, 13, 12]))

    mesh = bpy.data.meshes.new(f"concept_beveled_tile_e{elevation}_mesh")
    mesh.from_pydata([tuple(v) for v in verts], [], [indices for _name, indices in face_defs])
    mesh.update()

    uv_layer = mesh.uv_layers.new(name="UVMap")
    cw, ch = uv["canvas"]

    def uv_of(point):
        return (point[0] / cw, 1.0 - point[1] / ch)

    loop_index = 0
    for poly_index, (face_name, indices) in enumerate(face_defs):
        poly = mesh.polygons[poly_index]
        if face_name == "bottom":
            center = uv["faces"]["top"]["center_px"]
            coords = [uv_of(center)] * len(indices)
        else:
            coords = [uv_of(point) for point in _face_poly(uv["faces"][face_name])]
        for k in range(poly.loop_total):
            uv_layer.data[loop_index + k].uv = coords[k]
        loop_index += poly.loop_total

    obj = bpy.data.objects.new(f"concept_beveled_tile_e{elevation}", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(bake_assets._tile_material_image("mat_concept_beveled_candidate", str(uv_path)))
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


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
        "comment": "Concept explicit top-edge bevel bake set. Source raw style: docs/concept.jpg. No fable texture/decor referenced.",
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
        "bevel_inset_world": BEVEL_INSET_WORLD,
        "bevel_drop_world": BEVEL_DROP_WORLD,
        "assets": assets,
    }


def bake_set(
    uv_dir: Path,
    out_dir: Path,
    samples: int,
    ink_enabled: bool,
    bevel_inset_world: float | None = None,
    bevel_drop_world: float | None = None,
) -> dict:
    global BEVEL_INSET_WORLD, BEVEL_DROP_WORLD
    if bevel_inset_world is not None:
        BEVEL_INSET_WORLD = bevel_inset_world
    if bevel_drop_world is not None:
        BEVEL_DROP_WORLD = bevel_drop_world
    pipeline = bake_assets.apply_tile_pipeline_mode(tile_pipeline_modes.MODE3_TOP_EDGE_BEVEL)
    bake_assets.CONFIG["samples"] = samples
    bake_assets.CONFIG["ink_enabled"] = ink_enabled
    bake_assets.CONFIG["tile_smooth_enabled"] = False
    out_dir.mkdir(parents=True, exist_ok=True)
    sidecar_dir = uv_dir / "sidecars"
    results: dict[str, dict] = {}

    for terrain in TERRAINS:
        for elevation in ELEVATIONS:
            key = f"{terrain}_e{elevation}"
            uv_path = uv_dir / f"{key}_beveled_uv.png"
            uv_sidecar_path = sidecar_dir / f"beveled_uv_e{elevation}.json"
            if not uv_path.exists():
                raise FileNotFoundError(str(uv_path))
            if not uv_sidecar_path.exists():
                raise FileNotFoundError(str(uv_sidecar_path))
            bake_assets.setup_stage()
            bake_assets.clear_assets()
            bake_assets.ensure_shadow_catcher(False)
            _build_beveled_mesh(uv_path, uv_sidecar_path, elevation)
            out_path = out_dir / f"tile_{terrain}_e{elevation}_v0.png"
            bake_assets.render_to(str(out_path))
            results[key] = {"uv": str(uv_path), "baked": str(out_path), "uv_sidecar": str(uv_sidecar_path)}

    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(build_manifest(pipeline), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return {
        "pipeline": pipeline,
        "uv_dir": str(uv_dir),
        "out_dir": str(out_dir),
        "manifest": str(manifest_path),
        "samples": samples,
        "ink_enabled": ink_enabled,
        "results": results,
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--uv-dir", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=16)
    parser.add_argument("--ink", action="store_true")
    parser.add_argument("--bevel-inset-world", type=float, default=None)
    parser.add_argument("--bevel-drop-world", type=float, default=None)
    args = parser.parse_args(argv)
    try:
        result = bake_set(
            args.uv_dir.resolve(),
            args.out_dir.resolve(),
            args.samples,
            args.ink,
            bevel_inset_world=args.bevel_inset_world,
            bevel_drop_world=args.bevel_drop_world,
        )
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
