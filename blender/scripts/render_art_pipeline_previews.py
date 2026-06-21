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


def _build_hard(uv_path: Path | None, *, textured: bool) -> bpy.types.Object:
    bake_assets.apply_tile_pipeline_mode(tile_pipeline_modes.MODE2_HARD)
    if textured and uv_path and uv_path.exists():
        mat = bake_assets._tile_material_image("preview_hard_grass", str(uv_path))
    else:
        mat = _material("preview_hard_plain", (0.64, 0.68, 0.38, 1.0))
    obj = bake_assets.build_hex_tile("grass", 0, {}, override_mat=mat, uv_layout="uv")
    obj.name = "mode2_hard_preview"
    return obj


def _build_bevel(uv_path: Path | None, sidecar_path: Path, *, textured: bool) -> bpy.types.Object:
    if textured and uv_path and uv_path.exists():
        obj = bake_art_concept_beveled_set._build_beveled_mesh(uv_path, sidecar_path, 0)
    else:
        fallback_uv = uv_path if uv_path and uv_path.exists() else _repo_root() / "inkmon美术探索" / "concept素材-v1" / "beveled_uv_wide_rim" / "grass_e0_beveled_uv.png"
        obj = bake_art_concept_beveled_set._build_beveled_mesh(fallback_uv, sidecar_path, 0)
        obj.data.materials.clear()
        obj.data.materials.append(_material("preview_bevel_plain", (0.64, 0.68, 0.38, 1.0)))
    obj.name = "mode3_wide_rim_preview"
    return obj


def render_previews(repo: Path) -> dict:
    hard_dir = repo / "inkmon美术探索" / "codex-硬边-v1" / "model_preview"
    bevel_dir = repo / "inkmon美术探索" / "codex-倒角-v1" / "model_preview"
    hard_uv = repo / "inkmon美术探索" / "concept素材-v1" / "uv" / "grass_e0_warp_uv.png"
    bevel_uv = repo / "inkmon美术探索" / "concept素材-v1" / "beveled_uv_wide_rim" / "grass_e0_beveled_uv.png"
    bevel_sidecar = repo / "inkmon美术探索" / "concept素材-v1" / "beveled_uv_wide_rim" / "sidecars" / "beveled_uv_e0.json"

    outputs = {
        "hard": {
            "wire": hard_dir / "mode2_hard_e0_wire.png",
            "shaded": hard_dir / "mode2_hard_e0_shaded.png",
        },
        "bevel": {
            "wire": bevel_dir / "mode3_wide_rim_e0_wire.png",
            "shaded": bevel_dir / "mode3_wide_rim_e0_shaded.png",
        },
    }

    _reset_scene(ink_enabled=True)
    _build_hard(hard_uv, textured=False)
    _render(outputs["hard"]["wire"], freestyle=True)

    _reset_scene(ink_enabled=False)
    _build_hard(hard_uv, textured=True)
    _render(outputs["hard"]["shaded"], freestyle=False)

    bake_art_concept_beveled_set.BEVEL_INSET_WORLD = 0.085
    bake_art_concept_beveled_set.BEVEL_DROP_WORLD = 0.050
    _reset_scene(ink_enabled=True)
    _build_bevel(bevel_uv, bevel_sidecar, textured=False)
    _render(outputs["bevel"]["wire"], freestyle=True)

    _reset_scene(ink_enabled=False)
    _build_bevel(bevel_uv, bevel_sidecar, textured=True)
    _render(outputs["bevel"]["shaded"], freestyle=False)

    report = {
        "source_script": _rel(Path(__file__)),
        "outputs": {group: {name: _rel(path) for name, path in values.items()} for group, values in outputs.items()},
        "hard": {
            "pipeline_mode": tile_pipeline_modes.MODE2_HARD,
            "uv": _rel(hard_uv),
        },
        "bevel": {
            "pipeline_mode": tile_pipeline_modes.MODE3_TOP_EDGE_BEVEL,
            "uv": _rel(bevel_uv),
            "uv_sidecar": _rel(bevel_sidecar),
            "bevel_inset_world": 0.085,
            "bevel_drop_world": 0.050,
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
