"""Bake a complete terrain/elevation tile set from concept UV candidates."""

from __future__ import annotations

import argparse
import math
import json
import os
import subprocess
import sys
import tempfile
import traceback
from array import array
from pathlib import Path

try:
    from PIL import Image
except Exception:  # Blender bundled Python normally has no Pillow.
    Image = None


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import bake_assets  # noqa: E402


TERRAINS = ("grass", "dirt", "stone", "water")
ELEVATIONS = (0, 1, 2)
DECOR_ANCHORS = {
    "decor_pine": [256.0, 372.0],
    "decor_pine_tall": [256.0, 404.0],
    "decor_bush": [256.0, 324.0],
    "decor_rocks": [256.0, 322.0],
}
DECOR_SIZE_PX = [512, 512]
DEFAULT_CANVAS_PX = 2048
DEFAULT_PX_PER_UNIT = 512
DEFAULT_SAMPLES = 64
BASE_INK_PX_PER_UNIT = 128
DEFAULT_RUNTIME_TARGET_MAX_OPAQUE_SIDE = 512
DEFAULT_RUNTIME_CROP_PADDING_PX = 2
DEFAULT_RUNTIME_ALPHA_THRESHOLD = 1
DEFAULT_EXTRA_STROKE_PX = 1


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _rel(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(_repo_root()).as_posix()
    except ValueError:
        return str(resolved)


def _asset_key(terrain: str, elevation: int) -> str:
    return f"tile_{terrain}_e{elevation}"


def _asset_filename(terrain: str, elevation: int) -> str:
    return f"{_asset_key(terrain, elevation)}_v0.png"


def _expand_bbox(bbox: tuple[int, int, int, int], width: int, height: int, padding: int) -> tuple[int, int, int, int]:
    x0, y0, x1, y1 = bbox
    return (
        max(0, x0 - padding),
        max(0, y0 - padding),
        min(width, x1 + padding),
        min(height, y1 + padding),
    )


def _bbox_from_alpha_values(width: int, height: int, pixels, threshold: float) -> tuple[int, int, int, int] | None:
    min_x = width
    min_y_bl = height
    max_x = -1
    max_y_bl = -1
    for y_bl in range(height):
        row = y_bl * width * 4
        for x in range(width):
            if pixels[row + x * 4 + 3] > threshold:
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y_bl = min(min_y_bl, y_bl)
                max_y_bl = max(max_y_bl, y_bl)
    if max_x < min_x or max_y_bl < min_y_bl:
        return None
    return (min_x, height - 1 - max_y_bl, max_x + 1, height - min_y_bl)


def _alpha_threshold_float(threshold: int) -> float:
    return (threshold + 0.5) / 255.0


def _alpha_bbox(path: Path, threshold: int) -> tuple[int, int, int, int] | None:
    if Image is not None:
        with Image.open(path).convert("RGBA") as image:
            alpha = image.getchannel("A")
            mask = alpha.point(lambda value: 255 if value > threshold else 0)
            return mask.getbbox()
    import bpy
    image = bpy.data.images.load(str(path), check_existing=False)
    try:
        width, height = image.size
        pixels = array("f", [0.0]) * (width * height * 4)
        image.pixels.foreach_get(pixels)
        return _bbox_from_alpha_values(width, height, pixels, _alpha_threshold_float(threshold))
    finally:
        bpy.data.images.remove(image)


def _export_runtime_pil(
    rendered: dict[str, Path],
    out_dir: Path,
    runtime_canvas_px: int,
    padding_px: int,
    alpha_threshold: int,
) -> dict[str, dict]:
    assert Image is not None
    exports: dict[str, dict] = {}
    resampling = Image.Resampling.LANCZOS
    for asset_name, source_path in rendered.items():
        with Image.open(source_path).convert("RGBA") as image:
            resized = image.resize((runtime_canvas_px, runtime_canvas_px), resampling)
            alpha = resized.getchannel("A")
            mask = alpha.point(lambda value: 255 if value > alpha_threshold else 0)
            opaque = mask.getbbox()
            if opaque is None:
                raise ValueError(f"runtime export got empty alpha: {source_path}")
            crop_box = _expand_bbox(opaque, runtime_canvas_px, runtime_canvas_px, padding_px)
            cropped = resized.crop(crop_box)
            out_path = out_dir / f"{asset_name}_v0.png"
            cropped.save(out_path)
            x0, y0, x1, y1 = crop_box
            ox0, oy0, ox1, oy1 = opaque
            exports[asset_name] = {
                "file": out_path.name,
                "size_px": [cropped.width, cropped.height],
                "anchor_px": [runtime_canvas_px * 0.5 - x0, runtime_canvas_px * 0.5 - y0],
                "crop_bbox_px": [x0, y0, x1, y1],
                "opaque_bbox_px": [ox0 - x0, oy0 - y0, ox1 - x0, oy1 - y0],
                "opaque_size_px": [ox1 - ox0, oy1 - oy0],
            }
    return exports


def _export_runtime_bpy(
    rendered: dict[str, Path],
    out_dir: Path,
    runtime_canvas_px: int,
    padding_px: int,
    alpha_threshold: int,
) -> dict[str, dict]:
    import bpy
    exports: dict[str, dict] = {}
    threshold = _alpha_threshold_float(alpha_threshold)
    for asset_name, source_path in rendered.items():
        image = bpy.data.images.load(str(source_path), check_existing=False)
        crop_image = None
        try:
            image.scale(runtime_canvas_px, runtime_canvas_px)
            width, height = image.size
            pixels = array("f", [0.0]) * (width * height * 4)
            image.pixels.foreach_get(pixels)
            opaque = _bbox_from_alpha_values(width, height, pixels, threshold)
            if opaque is None:
                raise ValueError(f"runtime export got empty alpha: {source_path}")
            crop_box = _expand_bbox(opaque, width, height, padding_px)
            x0, y0, x1, y1 = crop_box
            crop_w = x1 - x0
            crop_h = y1 - y0
            crop_pixels = array("f", [0.0]) * (crop_w * crop_h * 4)
            source_y_bl_start = height - y1
            for out_y_bl in range(crop_h):
                src_y_bl = source_y_bl_start + out_y_bl
                src_base = (src_y_bl * width + x0) * 4
                dst_base = out_y_bl * crop_w * 4
                crop_pixels[dst_base:dst_base + crop_w * 4] = pixels[src_base:src_base + crop_w * 4]
            crop_image = bpy.data.images.new(f"{asset_name}_runtime", width=crop_w, height=crop_h, alpha=True)
            crop_image.pixels.foreach_set(crop_pixels)
            final_path = out_dir / f"{asset_name}_v0.png"
            if final_path.exists():
                final_path.unlink()
            crop_image.filepath_raw = str(final_path)
            crop_image.file_format = "PNG"
            crop_image.save()
            ox0, oy0, ox1, oy1 = opaque
            exports[asset_name] = {
                "file": f"{asset_name}_v0.png",
                "size_px": [crop_w, crop_h],
                "anchor_px": [runtime_canvas_px * 0.5 - x0, runtime_canvas_px * 0.5 - y0],
                "crop_bbox_px": [x0, y0, x1, y1],
                "opaque_bbox_px": [ox0 - x0, oy0 - y0, ox1 - x0, oy1 - y0],
                "opaque_size_px": [ox1 - ox0, oy1 - oy0],
            }
        finally:
            if crop_image is not None:
                bpy.data.images.remove(crop_image)
            bpy.data.images.remove(image)
    return exports


def _refresh_final_opaque_meta(
    exports: dict[str, dict],
    out_dir: Path,
    alpha_threshold: int,
) -> int:
    runtime_max_side = 0
    for meta in exports.values():
        final_bbox = _alpha_bbox(out_dir / meta["file"], alpha_threshold)
        if final_bbox is None:
            raise ValueError(f"runtime export wrote empty alpha: {out_dir / meta['file']}")
        x0, y0, x1, y1 = final_bbox
        opaque_size = [x1 - x0, y1 - y0]
        meta["opaque_bbox_px"] = [x0, y0, x1, y1]
        meta["opaque_size_px"] = opaque_size
        runtime_max_side = max(runtime_max_side, max(opaque_size))
    return runtime_max_side


def _export_runtime_external_pillow(
    rendered: dict[str, Path],
    out_dir: Path,
    source_canvas_px: int,
    source_px_per_unit: int,
    target_max_opaque_side_px: int,
    padding_px: int,
    alpha_threshold: int,
) -> tuple[dict[str, dict], dict]:
    helper = r'''
import json
import math
import sys
from pathlib import Path
from PIL import Image


def alpha_bbox(path, threshold):
    with Image.open(path).convert("RGBA") as image:
        alpha = image.getchannel("A")
        mask = alpha.point(lambda value: 255 if value > threshold else 0)
        return mask.getbbox()


def expand_bbox(bbox, width, height, padding):
    x0, y0, x1, y1 = bbox
    return [
        max(0, x0 - padding),
        max(0, y0 - padding),
        min(width, x1 + padding),
        min(height, y1 + padding),
    ]


request = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
rendered = {name: Path(path) for name, path in request["rendered"].items()}
out_dir = Path(request["out_dir"])
source_canvas_px = int(request["source_canvas_px"])
source_px_per_unit = float(request["source_px_per_unit"])
target = int(request["target_max_opaque_side_px"])
padding = int(request["padding_px"])
threshold = int(request["alpha_threshold"])

source_bboxes = {}
for name, path in rendered.items():
    bbox = alpha_bbox(path, threshold)
    if bbox is None:
        raise SystemExit(f"runtime export got empty alpha: {path}")
    source_bboxes[name] = bbox

source_max_side = max(max(x1 - x0, y1 - y0) for x0, y0, x1, y1 in source_bboxes.values())
effective_target = max(1, target - 2)
requested_scale = min(1.0, effective_target / max(source_max_side, 1))
runtime_canvas_px = max(1, math.floor(source_canvas_px * requested_scale))

exports = {}
runtime_max_side = 0
for attempt in range(5):
    runtime_scale = runtime_canvas_px / float(source_canvas_px)
    exports = {}
    for name, path in rendered.items():
        with Image.open(path).convert("RGBA") as image:
            resized = image.resize((runtime_canvas_px, runtime_canvas_px), Image.Resampling.LANCZOS)
            alpha = resized.getchannel("A")
            mask = alpha.point(lambda value: 255 if value > threshold else 0)
            opaque = mask.getbbox()
            if opaque is None:
                raise SystemExit(f"runtime export got empty alpha after resize: {path}")
            crop_box = expand_bbox(opaque, runtime_canvas_px, runtime_canvas_px, padding)
            cropped = resized.crop(tuple(crop_box))
            out_path = out_dir / f"{name}_v0.png"
            cropped.save(out_path)
        final = alpha_bbox(out_path, threshold)
        if final is None:
            raise SystemExit(f"runtime export wrote empty alpha: {out_path}")
        fx0, fy0, fx1, fy1 = final
        x0, y0, x1, y1 = crop_box
        exports[name] = {
            "file": out_path.name,
            "size_px": [cropped.width, cropped.height],
            "anchor_px": [runtime_canvas_px * 0.5 - x0, runtime_canvas_px * 0.5 - y0],
            "crop_bbox_px": crop_box,
            "opaque_bbox_px": [fx0, fy0, fx1, fy1],
            "opaque_size_px": [fx1 - fx0, fy1 - fy0],
            "source_opaque_bbox_px": list(source_bboxes[name]),
            "runtime_scale": runtime_scale,
        }
    runtime_max_side = max(max(meta["opaque_size_px"]) for meta in exports.values())
    if runtime_max_side <= target or runtime_canvas_px <= 1:
        break
    runtime_canvas_px = max(1, math.floor(runtime_canvas_px * target / runtime_max_side) - 1)
runtime_scale = runtime_canvas_px / float(source_canvas_px)
print(json.dumps({
    "exports": exports,
    "runtime_export": {
        "mode": "tight_global_max_opaque_side",
        "source_canvas_px": source_canvas_px,
        "source_px_per_unit": source_px_per_unit,
        "target_max_opaque_side_px": target,
        "runtime_canvas_px": runtime_canvas_px,
        "runtime_scale": runtime_scale,
        "runtime_px_per_unit": source_px_per_unit * runtime_scale,
        "source_max_opaque_side_px": source_max_side,
        "runtime_max_opaque_side_px": runtime_max_side,
        "crop_padding_px": padding,
        "alpha_threshold": threshold,
        "exporter": "external_pillow_lanczos",
    },
}, ensure_ascii=False))
'''
    python_exe = os.environ.get("PYTHON", "python")
    with tempfile.TemporaryDirectory(prefix="inkmon_runtime_export_") as temp_dir:
        request_path = Path(temp_dir) / "request.json"
        helper_path = Path(temp_dir) / "runtime_export.py"
        request_path.write_text(json.dumps({
            "rendered": {name: str(path) for name, path in rendered.items()},
            "out_dir": str(out_dir),
            "source_canvas_px": source_canvas_px,
            "source_px_per_unit": source_px_per_unit,
            "target_max_opaque_side_px": target_max_opaque_side_px,
            "padding_px": padding_px,
            "alpha_threshold": alpha_threshold,
        }, ensure_ascii=False), encoding="utf-8")
        helper_path.write_text(helper, encoding="utf-8")
        proc = subprocess.run(
            [python_exe, str(helper_path), str(request_path)],
            text=True,
            encoding="utf-8",
            errors="replace",
            capture_output=True,
        )
        if proc.returncode != 0:
            raise RuntimeError(
                "external Pillow runtime export failed:\nSTDOUT:\n%s\nSTDERR:\n%s"
                % (proc.stdout, proc.stderr)
            )
        data = json.loads(proc.stdout)
        return data["exports"], data["runtime_export"]


def export_runtime_tiles(
    rendered: dict[str, Path],
    out_dir: Path,
    source_canvas_px: int,
    source_px_per_unit: int,
    target_max_opaque_side_px: int,
    padding_px: int,
    alpha_threshold: int,
) -> tuple[dict[str, dict], dict]:
    if Image is None:
        return _export_runtime_external_pillow(
            rendered,
            out_dir,
            source_canvas_px,
            source_px_per_unit,
            target_max_opaque_side_px,
            padding_px,
            alpha_threshold,
        )
    source_bboxes: dict[str, tuple[int, int, int, int]] = {}
    for asset_name, path in rendered.items():
        bbox = _alpha_bbox(path, alpha_threshold)
        if bbox is None:
            raise ValueError(f"runtime export got empty alpha: {path}")
        source_bboxes[asset_name] = bbox
    source_max_side = max(max(x1 - x0, y1 - y0) for x0, y0, x1, y1 in source_bboxes.values())
    effective_target = max(1, target_max_opaque_side_px - 2)
    requested_scale = min(1.0, effective_target / max(source_max_side, 1))
    runtime_canvas_px = max(1, math.floor(source_canvas_px * requested_scale))
    exports: dict[str, dict] = {}
    runtime_max_side = 0
    for _attempt in range(5):
        runtime_scale = runtime_canvas_px / float(source_canvas_px)
        exports = _export_runtime_pil(rendered, out_dir, runtime_canvas_px, padding_px, alpha_threshold)
        runtime_max_side = _refresh_final_opaque_meta(exports, out_dir, alpha_threshold)
        if runtime_max_side <= target_max_opaque_side_px or runtime_canvas_px <= 1:
            break
        runtime_canvas_px = max(
            1,
            math.floor(runtime_canvas_px * target_max_opaque_side_px / runtime_max_side) - 1,
        )
    runtime_scale = runtime_canvas_px / float(source_canvas_px)
    export_info = {
        "mode": "tight_global_max_opaque_side",
        "source_canvas_px": source_canvas_px,
        "source_px_per_unit": source_px_per_unit,
        "target_max_opaque_side_px": target_max_opaque_side_px,
        "runtime_canvas_px": runtime_canvas_px,
        "runtime_scale": runtime_scale,
        "runtime_px_per_unit": source_px_per_unit * runtime_scale,
        "source_max_opaque_side_px": source_max_side,
        "runtime_max_opaque_side_px": runtime_max_side,
        "crop_padding_px": padding_px,
        "alpha_threshold": alpha_threshold,
        "exporter": "pillow_lanczos",
    }
    for asset_name, meta in exports.items():
        meta["source_opaque_bbox_px"] = list(source_bboxes[asset_name])
        meta["runtime_scale"] = runtime_scale
    return exports, export_info


def build_manifest(
    pipeline: dict,
    *,
    asset_exports: dict[str, dict] | None = None,
    runtime_export: dict | None = None,
    material_mode: str = "emission",
) -> dict:
    cfg = bake_assets.CONFIG
    scale = float(runtime_export["runtime_scale"]) if runtime_export else 1.0
    canvas_px = int(runtime_export["runtime_canvas_px"]) if runtime_export else int(cfg["canvas_px"])
    px_per_unit = (
        float(runtime_export["runtime_px_per_unit"])
        if runtime_export and "runtime_px_per_unit" in runtime_export
        else float(cfg["px_per_unit"]) * scale
    )
    assets: dict[str, dict] = {}
    for terrain in TERRAINS:
        for elevation in ELEVATIONS:
            key = _asset_key(terrain, elevation)
            filename = _asset_filename(terrain, elevation)
            export = (asset_exports or {}).get(key, {})
            assets[key] = {
                "file": export.get("file", filename),
                "variants": [export.get("file", filename)],
                "kind": "tile",
                "terrain": terrain,
                "elevation": elevation,
                "anchor_px": export.get("anchor_px", [canvas_px * 0.5, canvas_px * 0.5]),
                "size_px": export.get("size_px", [canvas_px, canvas_px]),
            }
            for field in ("crop_bbox_px", "opaque_bbox_px", "opaque_size_px", "source_opaque_bbox_px", "runtime_scale"):
                if field in export:
                    assets[key][field] = export[field]
    for decor_name, anchor_px in DECOR_ANCHORS.items():
        filename = f"{decor_name}.png"
        assets[decor_name] = {
            "file": filename,
            "variants": [filename],
            "kind": "decor",
            "anchor_px": anchor_px,
            "size_px": DECOR_SIZE_PX,
        }
    return {
    "comment": "Concept UV candidate bake set. Source raw style: docs/concept.jpg. Runtime tile output uses fixed-density tight export when runtime_export is present.",
        "pipeline": pipeline["id"],
        "pipeline_name": pipeline["zh_name"],
        "pitch_deg": cfg["pitch_deg"],
        "yaw_deg": cfg["yaw_deg"],
        "hex_orientation": "flat_top",
        "sun_elevation_deg": cfg["sun_elevation_deg"],
        "sun_azimuth_deg": cfg["sun_azimuth_deg"],
        "material_mode": material_mode,
        "uv_inset_px": cfg.get("uv_inset_px", 0.0),
        "ink_color": list(cfg.get("ink_color", (0.16, 0.12, 0.08))),
        "stroke_mode": cfg.get("stroke_mode", "default"),
        "extra_stroke_px": cfg.get("extra_stroke_px", 0),
        "extra_stroke_scope": cfg.get("extra_stroke_scope", "none"),
        "ink_thickness_position": cfg.get("ink_thickness_position", "INSIDE"),
        "ink_select_crease": cfg.get("ink_select_crease", True),
        "ink_wobble_px": cfg.get("ink_wobble_px", 0.0),
        "source_canvas_px": cfg["canvas_px"],
        "runtime_canvas_px": canvas_px,
        "px_per_unit": px_per_unit,
        "source_px_per_unit": cfg["px_per_unit"],
        "hex_edge_world": cfg["hex_edge"],
        "px_per_hex_edge": px_per_unit * cfg["hex_edge"],
        "thickness_world": cfg["thickness"],
        "elevation_step_world": cfg["elevation_step"],
        "water_recess_world": cfg["water_recess"],
        "runtime_export": runtime_export,
        "assets": assets,
    }


def bake_set(
    uv_dir: Path,
    out_dir: Path,
    pipeline_mode: str,
    samples: int,
    ink_enabled: bool,
    canvas_px: int,
    px_per_unit: int,
    use_denoising: bool,
    material_mode: str,
    uv_inset_px: float,
    black_ink: bool,
    runtime_target_max_opaque_side_px: int,
    runtime_crop_padding_px: int,
    runtime_alpha_threshold: int,
    runtime_export_enabled: bool,
    extra_stroke: bool,
    extra_stroke_px: int,
) -> dict:
    pipeline = bake_assets.apply_tile_pipeline_mode(pipeline_mode)
    ink_scale = px_per_unit / BASE_INK_PX_PER_UNIT
    bake_assets.CONFIG["canvas_px"] = canvas_px
    bake_assets.CONFIG["px_per_unit"] = px_per_unit
    bake_assets.CONFIG["samples"] = samples
    bake_assets.CONFIG["ink_enabled"] = ink_enabled
    bake_assets.CONFIG["use_denoising"] = use_denoising
    bake_assets.CONFIG["tile_image_material_mode"] = material_mode
    bake_assets.CONFIG["uv_inset_px"] = uv_inset_px
    if black_ink:
        bake_assets.CONFIG["ink_color"] = (0.0, 0.0, 0.0)
        bake_assets.CONFIG["ink_corner_color"] = (0.0, 0.0, 0.0)
    bake_assets.CONFIG["ink_thickness_px"] = 3.2 * ink_scale
    bake_assets.CONFIG["ink_wobble_px"] = 1.5 * ink_scale
    bake_assets.CONFIG["ink_corner_thickness_px"] = 2.0 * ink_scale
    bake_assets.CONFIG["ink_corner_wobble_px"] = 0.35 * ink_scale
    bake_assets.CONFIG["stroke_mode"] = "extra_stroke" if extra_stroke else "default"
    bake_assets.CONFIG["ink_thickness_position"] = "INSIDE"
    bake_assets.CONFIG["ink_thickness_noise_px"] = None
    bake_assets.CONFIG["ink_select_silhouette"] = True
    bake_assets.CONFIG["ink_select_border"] = True
    bake_assets.CONFIG["ink_select_crease"] = True
    bake_assets.CONFIG["ink_select_external_contour"] = True
    bake_assets.CONFIG["extra_stroke_px"] = 0
    bake_assets.CONFIG["extra_stroke_scope"] = "none"
    if extra_stroke:
        bake_assets.CONFIG["ink_enabled"] = False
        bake_assets.CONFIG["uv_inset_px"] = 0.0
        bake_assets.CONFIG["ink_thickness_px"] = 0.0
        bake_assets.CONFIG["ink_wobble_px"] = 0.0
        bake_assets.CONFIG["ink_corner_wobble_px"] = 0.0
        bake_assets.CONFIG["ink_thickness_noise_px"] = 0.0
        bake_assets.CONFIG["ink_thickness_position"] = "ALPHA_OUTSIDE"
        bake_assets.CONFIG["ink_select_crease"] = False
        bake_assets.CONFIG["extra_stroke_px"] = max(0, int(extra_stroke_px))
        bake_assets.CONFIG["extra_stroke_scope"] = "alpha_silhouette_only"
    out_dir.mkdir(parents=True, exist_ok=True)
    results: dict[str, dict] = {}
    rendered: dict[str, Path] = {}

    with tempfile.TemporaryDirectory(prefix="inkmon_concept_tile_master_") as temp_dir:
        temp_root = Path(temp_dir)
        for terrain in TERRAINS:
            for elevation in ELEVATIONS:
                key = f"{terrain}_e{elevation}"
                asset_name = _asset_key(terrain, elevation)
                uv_path = uv_dir / f"{key}_warp_uv.png"
                if not uv_path.exists():
                    raise FileNotFoundError(str(uv_path))
                out_path = out_dir / _asset_filename(terrain, elevation)
                render_path = temp_root / out_path.name if runtime_export_enabled else out_path
                bake_assets.bake_tile_candidate(str(uv_path), terrain, elevation, str(render_path))
                rendered[asset_name] = render_path
                results[key] = {"uv": _rel(uv_path), "baked": _rel(out_path)}

        asset_exports = None
        runtime_export = None
        if runtime_export_enabled:
            stroke_px = int(bake_assets.CONFIG.get("extra_stroke_px", 0))
            export_target = runtime_target_max_opaque_side_px
            if extra_stroke and stroke_px > 0:
                export_target = max(1, runtime_target_max_opaque_side_px - stroke_px * 2)
            asset_exports, runtime_export = export_runtime_tiles(
                rendered,
                out_dir,
                canvas_px,
                px_per_unit,
                export_target,
                max(runtime_crop_padding_px, stroke_px),
                runtime_alpha_threshold,
            )
            if extra_stroke and stroke_px > 0:
                bake_assets.apply_alpha_extra_stroke(
                    [out_dir / meta["file"] for meta in asset_exports.values()],
                    stroke_px,
                    runtime_alpha_threshold,
                )
                runtime_export["pre_stroke_target_max_opaque_side_px"] = export_target
                runtime_export["target_max_opaque_side_px"] = runtime_target_max_opaque_side_px
                runtime_export["extra_stroke_px"] = stroke_px
                runtime_export["runtime_max_opaque_side_px"] = _refresh_final_opaque_meta(
                    asset_exports,
                    out_dir,
                    runtime_alpha_threshold,
                )
        elif extra_stroke and int(bake_assets.CONFIG.get("extra_stroke_px", 0)) > 0:
            bake_assets.apply_alpha_extra_stroke(
                list(rendered.values()),
                int(bake_assets.CONFIG["extra_stroke_px"]),
                runtime_alpha_threshold,
            )

    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(
            build_manifest(
                pipeline,
                asset_exports=asset_exports,
                runtime_export=runtime_export,
                material_mode=material_mode,
            ),
            ensure_ascii=False,
            indent=2,
        ) + "\n",
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
        "canvas_px": canvas_px,
        "px_per_unit": px_per_unit,
        "use_denoising": use_denoising,
        "material_mode": material_mode,
        "uv_inset_px": bake_assets.CONFIG["uv_inset_px"],
        "black_ink": black_ink,
        "extra_stroke": extra_stroke,
        "extra_stroke_px": bake_assets.CONFIG.get("extra_stroke_px", 0),
        "runtime_export_enabled": runtime_export_enabled,
        "runtime_export": runtime_export,
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
    parser.add_argument("--samples", type=int, default=DEFAULT_SAMPLES)
    parser.add_argument("--canvas-px", type=int, default=DEFAULT_CANVAS_PX)
    parser.add_argument("--px-per-unit", type=int, default=DEFAULT_PX_PER_UNIT)
    parser.add_argument("--denoise", action="store_true")
    parser.add_argument("--ink", action="store_true")
    parser.add_argument("--material-mode", choices=("emission", "lit"), default="emission")
    parser.add_argument("--uv-inset-px", type=float, default=0.0)
    parser.add_argument("--black-ink", action="store_true")
    parser.add_argument("--runtime-target-max-opaque-side", type=int, default=DEFAULT_RUNTIME_TARGET_MAX_OPAQUE_SIDE)
    parser.add_argument("--runtime-crop-padding-px", type=int, default=DEFAULT_RUNTIME_CROP_PADDING_PX)
    parser.add_argument("--runtime-alpha-threshold", type=int, default=DEFAULT_RUNTIME_ALPHA_THRESHOLD)
    parser.add_argument("--no-runtime-export", action="store_true")
    parser.add_argument("--extra-stroke", action="store_true")
    parser.add_argument("--extra-stroke-px", type=int, default=DEFAULT_EXTRA_STROKE_PX)
    args = parser.parse_args(argv)
    try:
        result = bake_set(
            args.uv_dir.resolve(),
            args.out_dir.resolve(),
            args.pipeline,
            args.samples,
            args.ink,
            args.canvas_px,
            args.px_per_unit,
            args.denoise,
            args.material_mode,
            args.uv_inset_px,
            args.black_ink,
            args.runtime_target_max_opaque_side,
            args.runtime_crop_padding_px,
            args.runtime_alpha_threshold,
            not args.no_runtime_export,
            args.extra_stroke,
            args.extra_stroke_px,
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
