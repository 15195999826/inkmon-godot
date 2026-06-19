# texgen.top_edge_21_matrix -- batch top-edge cleanup for the 7 source-cut variants
#
# Candidate-only tool. It takes the existing 7 left-warp source-cut UVs,
# resamples only the three upper top-face source edges inward, then bakes:
#   1) the original 7 references (already exist)
#   2) 7 cleaned, no Blender ink
#   3) 7 cleaned, with Blender Freestyle ink

import argparse
import json
import os
import sys
from pathlib import Path


def _ensure_pil_available():
    try:
        import PIL  # noqa: F401
        return
    except Exception:
        pass

    roots = []
    conda_prefix = os.environ.get("CONDA_PREFIX")
    if conda_prefix:
        roots.append(Path(conda_prefix))
    roots.append(Path.home() / "miniconda3")
    for root in roots:
        site_packages = root / "Lib" / "site-packages"
        if site_packages.is_dir() and str(site_packages) not in sys.path:
            sys.path.insert(0, str(site_packages))


SCRIPT_DIR = Path(__file__).resolve().parent
BLENDER_SCRIPTS_DIR = SCRIPT_DIR.parent
if str(BLENDER_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(BLENDER_SCRIPTS_DIR))
from texgen import tile_pipeline_modes

Image = None
ImageDraw = None
ImageFont = None
bpy = None


def _load_pil():
    global Image, ImageDraw, ImageFont
    if Image is not None:
        return
    _ensure_pil_available()
    from PIL import Image as _Image, ImageDraw as _ImageDraw, ImageFont as _ImageFont
    Image = _Image
    ImageDraw = _ImageDraw
    ImageFont = _ImageFont


def _load_bpy():
    global bpy
    if bpy is not None:
        return bpy
    try:
        import bpy as _bpy  # type: ignore
    except Exception as exc:  # pragma: no cover
        raise SystemExit("This stage must run inside Blender Python") from exc
    bpy = _bpy
    return bpy


RUN_NAME = "left-warp-source-cut-variants-top-edge-clean-20260616-01"
SOURCE_RUN = "left-warp-source-cut-variants-baked-20260616-01"
LEFT_WARP_RUN = "left-warp-corner-ink-20260616-01"
SELECTED_TOP_EDGES = [0, 1, 2]  # right slant, top horizontal, left slant in template vertex order


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def _centroid(poly: list) -> tuple:
    return (
        sum(p[0] for p in poly) / max(1, len(poly)),
        sum(p[1] for p in poly) / max(1, len(poly)),
    )


def _line_intersection(p, p2, q, q2):
    px, py = p
    rx, ry = p2[0] - px, p2[1] - py
    qx, qy = q
    sx, sy = q2[0] - qx, q2[1] - qy
    denom = rx * sy - ry * sx
    if abs(denom) < 1e-8:
        return p
    t = ((qx - px) * sy - (qy - py) * sx) / denom
    return (px + t * rx, py + t * ry)


def _offset_edge_toward(poly: list, edge_idx: int, inset_px: float, target: tuple):
    a = poly[edge_idx]
    b = poly[(edge_idx + 1) % len(poly)]
    vx, vy = b[0] - a[0], b[1] - a[1]
    mag = max((vx * vx + vy * vy) ** 0.5, 1e-6)
    nx, ny = -vy / mag, vx / mag
    mid = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
    if (target[0] - mid[0]) * nx + (target[1] - mid[1]) * ny < 0.0:
        nx, ny = -nx, -ny
    return (
        (a[0] + nx * inset_px, a[1] + ny * inset_px),
        (b[0] + nx * inset_px, b[1] + ny * inset_px),
    )


def _inset_selected_edges(poly: list, selected_edges: list, inset_px: float) -> list:
    center = _centroid(poly)
    edge_lines = []
    selected = set(selected_edges)
    for idx in range(len(poly)):
        if idx in selected:
            edge_lines.append(_offset_edge_toward(poly, idx, inset_px, center))
        else:
            edge_lines.append((tuple(poly[idx]), tuple(poly[(idx + 1) % len(poly)])))

    out = []
    for idx in range(len(poly)):
        prev_line = edge_lines[(idx - 1) % len(poly)]
        cur_line = edge_lines[idx]
        out.append(_line_intersection(prev_line[0], prev_line[1], cur_line[0], cur_line[1]))
    return out


def _affine_coeffs(dst_tri, src_tri):
    import numpy as np

    a = np.zeros((6, 6))
    b = np.zeros(6)
    for k in range(3):
        dx, dy = dst_tri[k]
        sx, sy = src_tri[k]
        a[2 * k] = [dx, dy, 1, 0, 0, 0]
        a[2 * k + 1] = [0, 0, 0, dx, dy, 1]
        b[2 * k] = sx
        b[2 * k + 1] = sy
    return tuple(np.linalg.solve(a, b))


def _poly_mask(size: tuple, polygon: list, supersample: int = 4):
    _load_pil()
    w, h = size
    big = Image.new("L", (w * supersample, h * supersample), 0)
    d = ImageDraw.Draw(big)
    d.polygon([(x * supersample, y * supersample) for (x, y) in polygon], fill=255)
    return big.resize((w, h), Image.Resampling.LANCZOS)


def _top_affine_warp(design_img, design_poly: list, uv_poly: list, size: tuple):
    coeffs = _affine_coeffs(
        [uv_poly[0], uv_poly[2], uv_poly[4]],
        [design_poly[0], design_poly[2], design_poly[4]],
    )
    warped = design_img.transform(size, Image.Transform.AFFINE, coeffs, resample=Image.Resampling.BICUBIC)
    mask = _poly_mask(size, uv_poly)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.paste(warped, (0, 0), mask)
    return canvas


def _edge_length(a, b) -> float:
    return max(((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5, 1e-6)


def _paste_triangle(src_img, canvas, dst_tri: list, src_tri: list):
    coeffs = _affine_coeffs(dst_tri, src_tri)
    warped = src_img.transform(canvas.size, Image.Transform.AFFINE, coeffs, resample=Image.Resampling.BICUBIC)
    mask = _poly_mask(canvas.size, dst_tri)
    canvas.paste(warped, (0, 0), mask)


def _paste_quad_piecewise(src_img, canvas, dst_quad: list, src_quad: list):
    _paste_triangle(src_img, canvas, [dst_quad[0], dst_quad[1], dst_quad[2]], [src_quad[0], src_quad[1], src_quad[2]])
    _paste_triangle(src_img, canvas, [dst_quad[0], dst_quad[2], dst_quad[3]], [src_quad[0], src_quad[2], src_quad[3]])


def _clean_top_edge_strips(design_img, top_img, design_poly: list, uv_poly: list,
                           selected_edges: list, inset_px: float, size: tuple):
    """Replace only narrow edge strips using inward source samples.

    Earlier cleanup inset the whole source top polygon, then stretched it back
    over the full UV top face. That removed albedo edge lines but distorted the
    entire grass surface. This keeps the interior unchanged and only resamples
    the edge band that contains template/albedo outline pixels.
    """
    src_center = _centroid(design_poly)
    dst_center = _centroid(uv_poly)
    out = top_img.copy()
    for idx in selected_edges:
        ni = (idx + 1) % len(design_poly)
        src_a = design_poly[idx]
        src_b = design_poly[ni]
        dst_a = uv_poly[idx]
        dst_b = uv_poly[ni]

        src_edge_len = _edge_length(src_a, src_b)
        dst_edge_len = _edge_length(dst_a, dst_b)
        dst_inset = inset_px * dst_edge_len / src_edge_len

        src_outer = _offset_edge_toward(design_poly, idx, inset_px, src_center)
        src_inner = _offset_edge_toward(design_poly, idx, inset_px * 2.0, src_center)
        dst_outer = (tuple(dst_a), tuple(dst_b))
        dst_inner = _offset_edge_toward(uv_poly, idx, dst_inset, dst_center)

        dst_quad = [dst_outer[0], dst_outer[1], dst_inner[1], dst_inner[0]]
        src_quad = [src_outer[0], src_outer[1], src_inner[1], src_inner[0]]
        _paste_quad_piecewise(design_img, out, dst_quad, src_quad)
    return out


def _replace_top_face(base_uv: Path, design_png: Path, design_sidecar: dict, uv_sidecar: dict,
                      out_path: Path, inset_px: float) -> dict:
    _load_pil()
    base = Image.open(base_uv).convert("RGBA")
    design = Image.open(design_png).convert("RGBA")
    if tuple(base.size) != tuple(uv_sidecar["canvas"]):
        raise ValueError("UV size %s != sidecar canvas %s" % (base.size, uv_sidecar["canvas"]))
    if tuple(design.size) != tuple(design_sidecar["canvas"]):
        raise ValueError("design size %s != sidecar canvas %s" % (design.size, design_sidecar["canvas"]))

    design_top = design_sidecar["faces"]["top"]["polygon_px"]
    uv_top = uv_sidecar["faces"]["top"]["polygon_px"]

    top = _top_affine_warp(design, design_top, uv_top, base.size)
    top = _clean_top_edge_strips(design, top, design_top, uv_top, SELECTED_TOP_EDGES, inset_px, base.size)
    top_mask = _poly_mask(base.size, uv_top)
    base.paste(top, (0, 0), top_mask)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    base.save(out_path)
    return {
        "source_uv": str(base_uv),
        "out_uv": str(out_path),
        "inset_px": inset_px,
        "selected_top_edges": SELECTED_TOP_EDGES,
        "source_top_polygon_px": design_top,
        "note": "Only narrow strips along selected top edges are resampled inward. Top interior and wall faces stay unchanged.",
    }


def _load_bake_assets(repo: Path) -> dict:
    script = repo / "blender" / "scripts" / "bake_assets.py"
    ns = {"__file__": str(script)}
    exec(compile(script.read_text(encoding="utf-8"), str(script), "exec"), ns)
    return ns


def _install_emission_image_material(ns: dict):
    _load_bpy()

    def _tile_material_image_emission(name: str, image_path: str):
        mat = bpy.data.materials.get(name)
        if mat is not None:
            bpy.data.materials.remove(mat)
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nt = mat.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        emit = nt.nodes.new("ShaderNodeEmission")
        emit.inputs["Strength"].default_value = 1.0
        img = ns["_load_image"](image_path)
        if tuple(img.size) != ns["texgen_geometry"].UV_CANVAS:
            raise ValueError("UV texture %s size %s != %s" % (
                image_path, tuple(img.size), ns["texgen_geometry"].UV_CANVAS))
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.extension = "EXTEND"
        nt.links.new(tex.outputs["Color"], emit.inputs["Color"])
        nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
        return mat

    ns["_tile_material_image"] = _tile_material_image_emission


def _reset_config(ns: dict, base_config: dict, patch: dict):
    ns["CONFIG"].clear()
    ns["CONFIG"].update(base_config)
    ns["CONFIG"].update(patch)


def _bake_one(ns: dict, base_config: dict, uv_path: Path, out_path: Path, patch: dict):
    _reset_config(ns, base_config, patch)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    ns["bake_tile_candidate"](str(uv_path), "grass", 0, str(out_path))


def _bake_variants(ns: dict, base_config: dict, items: list, run_dir: Path) -> dict:
    no_ink_patch = {
        **tile_pipeline_modes.config_patch(tile_pipeline_modes.MODE2_HARD),
        "ink_enabled": False,
        "sun_energy": 0.0,
        "ambient_strength": 0.0,
        "samples": 32,
    }
    blender_ink_patch = {
        **tile_pipeline_modes.config_patch(tile_pipeline_modes.MODE2_HARD),
        "ink_enabled": True,
        "sun_energy": 0.0,
        "ambient_strength": 0.0,
        "samples": 32,
        "ink_thickness_px": 3.2,
        "ink_wobble_px": 0.8,
        "ink_exclude_wall_stitch_edges": False,
        "ink_corner_enabled": False,
    }

    out = {"top_edge_clean_no_ink": [], "top_edge_clean_blender_ink": []}
    try:
        for item in items:
            slot = item["slot"]
            uv = Path(item["clean_uv"])
            no_ink = run_dir / "baked" / "top_edge_clean_no_ink" / ("%s_top_edge_clean_no_ink.png" % slot)
            ink = run_dir / "baked" / "top_edge_clean_blender_ink" / ("%s_top_edge_clean_blender_ink.png" % slot)
            _bake_one(ns, base_config, uv, no_ink, no_ink_patch)
            _bake_one(ns, base_config, uv, ink, blender_ink_patch)
            out["top_edge_clean_no_ink"].append({
                "slot": slot,
                "uv": str(uv),
                "baked": str(no_ink),
                "config_patch": no_ink_patch,
            })
            out["top_edge_clean_blender_ink"].append({
                "slot": slot,
                "uv": str(uv),
                "baked": str(ink),
                "config_patch": blender_ink_patch,
            })
    finally:
        _reset_config(ns, base_config, {})
    return out


def _trimmed_panel(path: Path, label: str, panel_size=(280, 260)):
    _load_pil()
    try:
        font = ImageFont.truetype("arial.ttf", 13)
    except Exception:
        font = ImageFont.load_default()
    image = Image.open(path).convert("RGBA")
    bbox = image.getbbox() or (0, 0, image.width, image.height)
    image = image.crop(bbox)
    image.thumbnail((panel_size[0] - 18, panel_size[1] - 42), Image.Resampling.LANCZOS)
    panel = Image.new("RGBA", panel_size, (245, 244, 239, 255))
    panel.alpha_composite(image, ((panel_size[0] - image.width) // 2, 32 + (panel_size[1] - 42 - image.height) // 2))
    d = ImageDraw.Draw(panel)
    d.text((8, 8), label, fill=(24, 24, 24, 255), font=font)
    return panel.convert("RGB")


def _make_contact_sheet(run_dir: Path, source_items: list, clean_items: list, ink_items: list) -> dict:
    shots = run_dir / "shots"
    shots.mkdir(parents=True, exist_ok=True)

    by_slot_clean = {Path(item["uv"]).stem.removesuffix("_top_edge_clean"): item for item in clean_items}
    by_slot_ink = {Path(item["uv"]).stem.removesuffix("_top_edge_clean"): item for item in ink_items}

    panels = []
    for item in source_items:
        slot = item["slot"]
        panels.append([
            _trimmed_panel(Path(item["baked"]), "%s / original" % slot),
            _trimmed_panel(Path(by_slot_clean[slot]["baked"]), "%s / top edges clean" % slot),
            _trimmed_panel(Path(by_slot_ink[slot]["baked"]), "%s / clean + Blender ink" % slot),
        ])

    w, h = 280, 260
    sheet = Image.new("RGB", (w * 3, h * len(panels)), (235, 234, 229))
    for row, row_panels in enumerate(panels):
        for col, panel in enumerate(row_panels):
            sheet.paste(panel, (col * w, row * h))
    sheet_path = shots / "top_edge_clean_21_compare_by_variant.png"
    sheet.save(sheet_path)

    wide = Image.new("RGB", (w * len(panels), h * 3), (235, 234, 229))
    for col, row_panels in enumerate(panels):
        for row, panel in enumerate(row_panels):
            wide.paste(panel, (col * w, row * h))
    wide_path = shots / "top_edge_clean_21_compare_by_group.png"
    wide.save(wide_path)

    return {"by_variant": str(sheet_path), "by_group": str(wide_path)}


def prepare(inset_px: float, run_name: str) -> dict:
    repo = _repo_root()
    candidates = repo / "blender" / "textures" / "_candidates"
    source_run = candidates / SOURCE_RUN
    left_run = candidates / LEFT_WARP_RUN
    run_dir = candidates / run_name
    run_dir.mkdir(parents=True, exist_ok=True)

    source_summary = _read_json(source_run / "logs" / "source_cut_variants_bake_summary.json")
    design_png = left_run / "raw" / "dual_left_design.png"
    design_sidecar_path = left_run / "templates" / "template_design_e0.json"
    uv_sidecar_path = left_run / "templates" / "template_uv_e0.json"
    design_sidecar = _read_json(design_sidecar_path)
    uv_sidecar = _read_json(uv_sidecar_path)

    clean_items = []
    uv_reports = {}
    for source_item in source_summary["items"]:
        slot = source_item["slot"]
        clean_uv = run_dir / "uv_top_edge_clean" / ("%s_top_edge_clean.png" % slot)
        report = _replace_top_face(
            Path(source_item["source"]),
            design_png,
            design_sidecar,
            uv_sidecar,
            clean_uv,
            inset_px,
        )
        clean_items.append({**source_item, "clean_uv": str(clean_uv)})
        uv_reports[slot] = report

    summary = {
        "run_dir": str(run_dir),
        "source_run": str(source_run),
        "design_png": str(design_png),
        "design_sidecar": str(design_sidecar_path),
        "uv_sidecar": str(uv_sidecar_path),
        "inset_px": inset_px,
        "selected_top_edges": [
            "top right slanted outer edge top[0]->top[1]",
            "top horizontal outer edge top[1]->top[2]",
            "top left slanted outer edge top[2]->top[3]",
        ],
        "original_7": source_summary["items"],
        "clean_items": clean_items,
        "clean_uv_reports": uv_reports,
        "note": "Prepare stage only. Wall faces stay from the original 7 UVs; only the top face is rewarped.",
    }
    _write_json(run_dir / "logs" / "top_edge_21_prepare.json", summary)
    return summary


def bake(run_name: str) -> dict:
    repo = _repo_root()
    run_dir = repo / "blender" / "textures" / "_candidates" / run_name
    prepared = _read_json(run_dir / "logs" / "top_edge_21_prepare.json")

    ns = _load_bake_assets(repo)
    _install_emission_image_material(ns)
    base_config = dict(ns["CONFIG"])
    bake_results = _bake_variants(ns, base_config, prepared["clean_items"], run_dir)

    summary = {
        "run_dir": str(run_dir),
        "bake_results": bake_results,
        "note": "Bake stage only. Uses emission image material so no lighting/shadow is baked into these comparisons.",
    }
    _write_json(run_dir / "logs" / "top_edge_21_bake.json", summary)
    return summary


def contact(run_name: str) -> dict:
    repo = _repo_root()
    candidates = repo / "blender" / "textures" / "_candidates"
    source_run = candidates / SOURCE_RUN
    run_dir = candidates / run_name

    source_summary = _read_json(source_run / "logs" / "source_cut_variants_bake_summary.json")
    prepared = _read_json(run_dir / "logs" / "top_edge_21_prepare.json")
    baked = _read_json(run_dir / "logs" / "top_edge_21_bake.json")
    bake_results = baked["bake_results"]

    shots = _make_contact_sheet(
        run_dir,
        source_summary["items"],
        bake_results["top_edge_clean_no_ink"],
        bake_results["top_edge_clean_blender_ink"],
    )

    summary = {
        "run_dir": str(run_dir),
        "source_run": str(source_run),
        "prepare": prepared,
        "bake_results": bake_results,
        "shots": shots,
        "note": "21 matrix = original 7 + top-edge-clean 7 + top-edge-clean-with-Blender-ink 7. No production texture or Godot slot overwrite.",
    }
    _write_json(run_dir / "logs" / "top_edge_21_matrix_summary.json", summary)
    (run_dir / "REPORT.md").write_text(
        "# Top Edge 21 Matrix\n\n"
        "This run keeps the previous 7 source-cut variants and only changes the three upper top-face edges.\n\n"
        "- original 7: previous `unlit_no_bevel` bakes from `%s`\n"
        "- cleaned 7: top face source edges `[0,1,2]` inset by `%.1fpx`, no Blender ink\n"
        "- cleaned + Blender ink 7: same cleaned UVs with Freestyle ink enabled\n\n"
        "No production textures or Godot tile slots were overwritten.\n\n"
        "Contact sheets:\n\n"
        "- by variant: `%s`\n"
        "- by group: `%s`\n"
        % (SOURCE_RUN, float(prepared["inset_px"]), shots["by_variant"], shots["by_group"]),
        encoding="utf-8",
    )
    return summary


def main():
    ap = argparse.ArgumentParser(description="Build the 21-image top-edge comparison matrix")
    ap.add_argument("--stage", choices=["prepare", "bake", "contact"], required=True)
    ap.add_argument("--inset-px", type=float, default=18.0)
    ap.add_argument("--run-name", default=RUN_NAME)
    ap.add_argument("--summary", default=None)
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else None
    args = ap.parse_args(argv)
    if args.stage == "prepare":
        summary = prepare(args.inset_px, args.run_name)
    elif args.stage == "bake":
        summary = bake(args.run_name)
    else:
        summary = contact(args.run_name)
    if args.summary:
        _write_json(Path(args.summary), summary)
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
