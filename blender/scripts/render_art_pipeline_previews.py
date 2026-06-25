"""Render actual Blender mesh previews for the concept art pipeline page."""

from __future__ import annotations

import argparse
import json
import os
import sys
import traceback
from pathlib import Path

import bpy


SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import bake_art_concept_beveled_set  # noqa: E402
import bake_assets  # noqa: E402
from texgen import tile_pipeline_modes  # noqa: E402


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _rel(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(_repo_root()).as_posix()
    except ValueError:
        return str(resolved)


def _material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.78
    return material


def _render(path: Path, *, freestyle: bool) -> None:
    scene = bpy.context.scene
    scene.render.filepath = str(path)
    scene.render.use_freestyle = freestyle
    bpy.context.view_layer.use_freestyle = freestyle
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def _reset_scene(*, ink_enabled: bool) -> None:
    bake_assets.CONFIG["canvas_px"] = 512
    bake_assets.CONFIG["samples"] = 24
    bake_assets.CONFIG["ink_enabled"] = ink_enabled
    bake_assets.setup_stage()
    bake_assets.clear_assets()
    bake_assets.ensure_shadow_catcher(False)
    bpy.context.scene.world.color = (0.78, 0.76, 0.70)


def _build_hard(uv_path: Path | None, elevation: int, *, textured: bool) -> bpy.types.Object:
    bake_assets.apply_tile_pipeline_mode(tile_pipeline_modes.MODE2_HARD)
    if textured and uv_path and uv_path.exists():
        mat = bake_assets._tile_material_image(f"preview_hard_grass_e{elevation}", str(uv_path))
    else:
        mat = _material(f"preview_hard_plain_e{elevation}", (0.64, 0.68, 0.38, 1.0))
    obj = bake_assets.build_hex_tile("grass", elevation, {}, override_mat=mat, uv_layout="uv")
    obj.name = f"mode2_hard_e{elevation}_preview"
    return obj


def _build_bevel(
    uv_path: Path | None,
    sidecar_path: Path,
    elevation: int,
    *,
    textured: bool,
    chipped: bool = False,
) -> bpy.types.Object:
    bake_assets.CONFIG["rim_profile"] = "chipped" if chipped else "regular"
    bake_assets.CONFIG["chip_count_per_edge"] = 3 if chipped else 0
    bake_assets.CONFIG["chip_depth_world"] = 0.070 if chipped else 0.0
    bake_assets.CONFIG["chip_width_ratio"] = 0.100 if chipped else 0.0
    bake_assets.CONFIG["chip_segments_per_edge"] = 12 if chipped else 0
    bake_assets.CONFIG["chip_seed"] = 20260625 if chipped else None
    if textured and uv_path and uv_path.exists():
        obj = bake_art_concept_beveled_set._build_beveled_mesh(uv_path, sidecar_path, elevation)
    else:
        fallback_uv = uv_path if uv_path and uv_path.exists() else _repo_root() / "inkmon美术探索" / "concept素材-v1" / "beveled_uv_wide_rim" / f"grass_e{elevation}_beveled_uv.png"
        obj = bake_art_concept_beveled_set._build_beveled_mesh(fallback_uv, sidecar_path, elevation)
        obj.data.materials.clear()
        obj.data.materials.append(_material(f"preview_bevel_plain_e{elevation}", (0.64, 0.68, 0.38, 1.0)))
    obj.name = f"mode3_wide_rim{'_chipped' if chipped else ''}_e{elevation}_preview"
    return obj


def render_previews(repo: Path) -> dict:
    hard_dir = repo / "inkmon美术探索" / "codex-硬边-v1" / "model_preview"
    bevel_dir = repo / "inkmon美术探索" / "codex-倒角-v1" / "model_preview"
    regular_inset = 0.085
    regular_drop = 0.050
    chipped_inset = 0.150
    chipped_drop = 0.075
    bake_art_concept_beveled_set.BEVEL_INSET_WORLD = regular_inset
    bake_art_concept_beveled_set.BEVEL_DROP_WORLD = regular_drop

    outputs = {"hard": {}, "bevel": {}, "bevel_chipped": {}}
    hard_uvs = {}
    bevel_uvs = {}
    bevel_chipped_uvs = {}
    bevel_sidecars = {}
    bevel_chipped_sidecars = {}

    for elevation in (0, 1, 2):
        key = f"e{elevation}"
        hard_uv = repo / "inkmon美术探索" / "concept素材-v1" / "uv" / f"grass_e{elevation}_warp_uv.png"
        bevel_uv = repo / "inkmon美术探索" / "concept素材-v1" / "beveled_uv_wide_rim" / f"grass_e{elevation}_beveled_uv.png"
        bevel_sidecar = repo / "inkmon美术探索" / "concept素材-v1" / "beveled_uv_wide_rim" / "sidecars" / f"beveled_uv_e{elevation}.json"
        chipped_uv = repo / "inkmon美术探索" / "concept素材-v1" / "beveled_uv_wide_rim_chipped" / f"grass_e{elevation}_beveled_uv.png"
        chipped_sidecar = repo / "inkmon美术探索" / "concept素材-v1" / "beveled_uv_wide_rim_chipped" / "sidecars" / f"beveled_uv_e{elevation}.json"
        hard_uvs[key] = _rel(hard_uv)
        bevel_uvs[key] = _rel(bevel_uv)
        bevel_sidecars[key] = _rel(bevel_sidecar)
        bevel_chipped_uvs[key] = _rel(chipped_uv)
        bevel_chipped_sidecars[key] = _rel(chipped_sidecar)
        outputs["hard"][key] = {
            "wire": hard_dir / f"mode2_hard_e{elevation}_wire.png",
            "shaded": hard_dir / f"mode2_hard_e{elevation}_shaded.png",
        }
        outputs["bevel"][key] = {
            "wire": bevel_dir / f"mode3_wide_rim_e{elevation}_wire.png",
            "shaded": bevel_dir / f"mode3_wide_rim_e{elevation}_shaded.png",
        }
        outputs["bevel_chipped"][key] = {
            "wire": bevel_dir / f"mode3_wide_rim_chipped_e{elevation}_wire.png",
            "shaded": bevel_dir / f"mode3_wide_rim_chipped_e{elevation}_shaded.png",
        }

        _reset_scene(ink_enabled=True)
        _build_hard(hard_uv, elevation, textured=False)
        _render(outputs["hard"][key]["wire"], freestyle=True)

        _reset_scene(ink_enabled=False)
        _build_hard(hard_uv, elevation, textured=True)
        _render(outputs["hard"][key]["shaded"], freestyle=False)

        _reset_scene(ink_enabled=True)
        bake_art_concept_beveled_set.BEVEL_INSET_WORLD = regular_inset
        bake_art_concept_beveled_set.BEVEL_DROP_WORLD = regular_drop
        _build_bevel(bevel_uv, bevel_sidecar, elevation, textured=False)
        _render(outputs["bevel"][key]["wire"], freestyle=True)

        _reset_scene(ink_enabled=False)
        bake_art_concept_beveled_set.BEVEL_INSET_WORLD = regular_inset
        bake_art_concept_beveled_set.BEVEL_DROP_WORLD = regular_drop
        _build_bevel(bevel_uv, bevel_sidecar, elevation, textured=True)
        _render(outputs["bevel"][key]["shaded"], freestyle=False)

        if chipped_uv.exists() and chipped_sidecar.exists():
            _reset_scene(ink_enabled=True)
            bake_art_concept_beveled_set.BEVEL_INSET_WORLD = chipped_inset
            bake_art_concept_beveled_set.BEVEL_DROP_WORLD = chipped_drop
            _build_bevel(chipped_uv, chipped_sidecar, elevation, textured=False, chipped=True)
            _render(outputs["bevel_chipped"][key]["wire"], freestyle=True)

            _reset_scene(ink_enabled=False)
            bake_art_concept_beveled_set.BEVEL_INSET_WORLD = chipped_inset
            bake_art_concept_beveled_set.BEVEL_DROP_WORLD = chipped_drop
            _build_bevel(chipped_uv, chipped_sidecar, elevation, textured=True, chipped=True)
            _render(outputs["bevel_chipped"][key]["shaded"], freestyle=False)

    report = {
        "source_script": _rel(Path(__file__)),
        "outputs": {
            group: {
                elevation: {name: _rel(path) for name, path in values.items()}
                for elevation, values in by_elevation.items()
            }
            for group, by_elevation in outputs.items()
        },
        "hard": {
            "pipeline_mode": tile_pipeline_modes.MODE2_HARD,
            "uv": hard_uvs,
        },
        "bevel": {
            "pipeline_mode": tile_pipeline_modes.MODE3_TOP_EDGE_BEVEL,
            "uv": bevel_uvs,
            "uv_sidecar": bevel_sidecars,
            "bevel_inset_world": regular_inset,
            "bevel_drop_world": regular_drop,
        },
        "bevel_chipped": {
            "pipeline_mode": tile_pipeline_modes.MODE3_TOP_EDGE_BEVEL,
            "uv": bevel_chipped_uvs,
            "uv_sidecar": bevel_chipped_sidecars,
            "bevel_inset_world": chipped_inset,
            "bevel_drop_world": chipped_drop,
            "rim_profile": "chipped",
            "chip_count_per_edge": 3,
            "chip_depth_world": 0.070,
            "chip_width_ratio": 0.100,
            "chip_segments_per_edge": 12,
            "chip_seed": 20260625,
        },
    }
    report_path = repo / "inkmon美术探索" / "concept素材-v1" / "model_preview_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=_repo_root())
    args = parser.parse_args(argv)
    try:
        report = render_previews(args.repo.resolve())
        print(json.dumps({"ok": True, **report}, ensure_ascii=False, indent=2))
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
