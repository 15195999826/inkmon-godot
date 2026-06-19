# texgen.single_design_21_matrix -- single 3D design -> 21 comparison matrix
#
# Candidate-only tool:
#   original source-cut variants 7
#   top-edge-clean variants 7
#   top-edge-clean + Blender Freestyle ink 7
#
# Stages:
#   python  ... --stage prepare --design-png <png> --run-name <name>
#   blender ... --python ... -- --stage bake --run-name <name>
#   python  ... --stage contact --run-name <name>

import argparse
import json
import os
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
BLENDER_SCRIPTS_DIR = SCRIPT_DIR.parent
if str(BLENDER_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(BLENDER_SCRIPTS_DIR))

from texgen import geometry
from texgen import source_cut_recipe_gen
from texgen import tile_pipeline_modes
from texgen import top_edge_21_matrix as top21


RUN_NAME = "single-design-21-matrix-20260616-01"
RECIPE_RUN = "left-warp-source-cut-variants-baked-20260616-01"
DEFAULT_DESIGN_SIDECAR = "blender/templates/standard-templates/template_design_e0.json"
DEFAULT_UV_SIDECAR = "blender/templates/standard-templates/template_uv_e0.json"


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def _load_pil():
    top21._load_pil()
    return top21.Image


def _face_poly(face: dict) -> list:
    return face.get("polygon_px") or face["quad_px"]


def _fit_top(fit: dict) -> list:
    """Extract the 6 top-face vertices from a fit.json. Accepts faces.top as a
    bare list, as {polygon_px}, or a top-level top list."""
    faces = fit.get("faces", {})
    ft = faces.get("top")
    if ft is None:
        ft = fit.get("top")
    if isinstance(ft, list):
        return [[float(x), float(y)] for x, y in ft]
    if isinstance(ft, dict):
        poly = ft.get("polygon_px") or ft.get("quad_px")
        if poly is None:
            raise ValueError("fit.json faces.top missing polygon_px/quad_px")
        return [[float(x), float(y)] for x, y in poly]
    raise ValueError("fit.json missing faces.top (6 vertices)")


def _wall_depth(template_sidecar: dict) -> tuple:
    """Global wall depth vector (top edge -> bottom edge). Constant for a given
    pitch/yaw/thickness; derived from the template's wall_3 quad (BL - TL)."""
    w3 = template_sidecar["faces"]["wall_3"]["quad_px"]
    return (w3[3][0] - w3[0][0], w3[3][1] - w3[0][1])


def _add_v(p, d):
    return [p[0] + d[0], p[1] + d[1]]


def _sidecar_from_top(top: list, depth: tuple, template_sidecar: dict) -> dict:
    """Legacy: build sidecar from 6 fitted top verts + derived walls."""
    faces = {
        "top": {"polygon_px": [[float(x), float(y)] for x, y in top]},
        "wall_3": {"quad_px": [list(top[3]), list(top[4]), _add_v(top[4], depth), _add_v(top[3], depth)]},
        "wall_4": {"quad_px": [list(top[4]), list(top[5]), _add_v(top[5], depth), _add_v(top[4], depth)]},
        "wall_5": {"quad_px": [list(top[5]), list(top[0]), _add_v(top[0], depth), _add_v(top[5], depth)]},
    }
    return {"template": "fit", "canvas": template_sidecar["canvas"], "faces": faces, "manifest": template_sidecar.get("manifest", {})}


def _sidecar_from_params(transform: dict, basis: dict, template_sidecar: dict) -> dict:
    """Parametric fit: project the standard hex at (pitch_std + pitch_delta,
    yaw_std + yaw_delta), then uniform scale + translate. Same math as
    geometry.py projector, so the output is the AI tile's actual projection --
    corrects pitch/yaw drift exactly (hex shape regular, only viewing angle off).
    Walls come from the same projection, so no per-wall fitting needed."""
    m = template_sidecar["manifest"]
    pitch_std = float(basis.get("pitch_std", m["pitch_deg"]))
    yaw_std = float(basis.get("yaw_std", m["yaw_deg"]))
    scale_px = float(basis.get("scale_px_per_unit", template_sidecar["scale_px_per_unit"]))
    origin = basis.get("origin_px", template_sidecar["origin_px"])
    edge = float(basis.get("hex_edge_world", m["hex_edge_world"]))
    thickness = float(basis.get("thickness_world", m["thickness_world"]))

    mfst = dict(m)
    mfst["pitch_deg"] = pitch_std + float(transform["pitch_delta"])
    mfst["yaw_deg"] = yaw_std + float(transform["yaw_delta"])
    project = geometry.projector(mfst)

    scale = float(transform["scale"])
    ox, oy = transform["offset"]
    def to_canvas(p):
        return [p[0] * scale_px * scale + origin[0] + ox, p[1] * scale_px * scale + origin[1] + oy]

    top = [to_canvas(project(*geometry.hex_corner(i, edge), 0.0)) for i in range(6)]
    walls = {}
    for i in (3, 4, 5):
        left, right = geometry.wall_corners_lr(mfst, i)
        walls[i] = [
            to_canvas(project(left[0], left[1], 0.0)),
            to_canvas(project(right[0], right[1], 0.0)),
            to_canvas(project(right[0], right[1], -thickness)),
            to_canvas(project(left[0], left[1], -thickness)),
        ]
    faces = {
        "top": {"polygon_px": top},
        "wall_3": {"quad_px": walls[3]},
        "wall_4": {"quad_px": walls[4]},
        "wall_5": {"quad_px": walls[5]},
    }
    return {"template": "fit", "canvas": template_sidecar["canvas"], "faces": faces, "manifest": mfst}


def _sidecar_from_fit(fit: dict, template_sidecar: dict) -> dict:
    if "transform" in fit:
        return _sidecar_from_params(fit["transform"], fit.get("basis", {}), template_sidecar)
    return _sidecar_from_top(_fit_top(fit), _wall_depth(template_sidecar), template_sidecar)


def _face_names(uv_sidecar: dict) -> list:
    names = ["top"]
    names.extend("wall_%d" % int(i) for i in uv_sidecar.get("wall_order", []))
    return names


def _source_poly_for(slot: str, face: str, design_sidecar: dict, recipe: dict, top_outline_px: float = 0.0) -> list:
    if slot == "original_both_faces_own":
        source = _face_poly(design_sidecar["faces"][face])
    else:
        source = recipe["reports"][slot][face]["source_poly"]
    if face == "top" and abs(float(top_outline_px)) > 1e-6:
        return top21._inset_selected_edges(source, list(range(len(source))), -float(top_outline_px))
    return source


def _warp_face(design, source_poly: list, dst_poly: list, size: tuple):
    Image = _load_pil()
    if len(source_poly) == 6 and len(dst_poly) == 6:
        # The top face is one planar orthographic projection. The fit tool
        # constrains the 6 vertices to the template shape (uniform scale +
        # translate, no per-vertex deformation), so a single 3-pt affine is
        # exact -- no squeeze and no background-bleed at the edges.
        coeffs = top21._affine_coeffs(
            [dst_poly[0], dst_poly[2], dst_poly[4]],
            [source_poly[0], source_poly[2], source_poly[4]],
        )
        warped = design.transform(size, Image.Transform.AFFINE, coeffs, resample=Image.Resampling.BICUBIC)
        mask = top21._poly_mask(size, dst_poly)
        canvas = Image.new("RGBA", size, (0, 0, 0, 0))
        canvas.paste(warped, (0, 0), mask)
        return canvas

    coeffs = top21._affine_coeffs([dst_poly[0], dst_poly[1], dst_poly[2]], [source_poly[0], source_poly[1], source_poly[2]])
    warped = design.transform(size, Image.Transform.AFFINE, coeffs, resample=Image.Resampling.BICUBIC)
    mask = top21._poly_mask(size, dst_poly)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.paste(warped, (0, 0), mask)
    return canvas


def _warp_variant(design_png: Path, design_sidecar: dict, uv_sidecar: dict, recipe: dict,
                  slot: str, out_path: Path, top_outline_px: float = 0.0) -> dict:
    Image = _load_pil()
    design = Image.open(design_png).convert("RGBA")
    if tuple(design.size) != tuple(design_sidecar["canvas"]):
        raise ValueError("design size %s != sidecar canvas %s" % (design.size, design_sidecar["canvas"]))

    size = tuple(uv_sidecar["canvas"])
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    face_reports = {}
    for face in _face_names(uv_sidecar):
        source_poly = _source_poly_for(slot, face, design_sidecar, recipe, top_outline_px)
        dst_poly = _face_poly(uv_sidecar["faces"][face])
        warped = _warp_face(design, source_poly, dst_poly, size)
        mask = top21._poly_mask(size, dst_poly)
        canvas.paste(warped, (0, 0), mask)
        face_reports[face] = {"source_poly": source_poly, "dst_poly": dst_poly}

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path)
    return {"slot": slot, "uv": str(out_path), "faces": face_reports}


def prepare(design_png: Path, run_name: str, design_sidecar_path: Path, uv_sidecar_path: Path,
            inset_px: float, top_outline_px: float, fit_json_path=None) -> dict:
    repo = _repo_root()
    candidates = repo / "blender" / "textures" / "_candidates"
    run_dir = candidates / run_name
    run_dir.mkdir(parents=True, exist_ok=True)

    design_sidecar = _read_json(design_sidecar_path)
    uv_sidecar = _read_json(uv_sidecar_path)

    if fit_json_path is not None:
        fit = _read_json(fit_json_path)
        design_sidecar = _sidecar_from_fit(fit, design_sidecar)
        recipe = source_cut_recipe_gen.build_recipe(design_sidecar, source_design=str(design_png))
        source_summary = source_cut_recipe_gen.build_bake_summary(run_dir)
        fit_source = str(fit_json_path)
    else:
        recipe_run = candidates / RECIPE_RUN
        recipe = _read_json(recipe_run / "logs" / "source_cut_variants_uv_report.json")
        source_summary = _read_json(recipe_run / "logs" / "source_cut_variants_bake_summary.json")
        fit_source = "frozen:%s" % RECIPE_RUN

    original_items = []
    clean_items = []
    variant_reports = {}
    for item in source_summary["items"]:
        slot = item["slot"]
        uv = run_dir / "uv_source_cut_variants" / ("%s_warp_uv.png" % slot)
        report = _warp_variant(design_png, design_sidecar, uv_sidecar, recipe, slot, uv, top_outline_px)
        original_items.append({
            "slot": slot,
            "source_type": "uv",
            "source": str(uv),
            "config_patch": item.get("config_patch", {}),
        })
        clean_uv = run_dir / "uv_top_edge_clean" / ("%s_top_edge_clean.png" % slot)
        clean_report = top21._replace_top_face(
            uv,
            design_png,
            design_sidecar,
            uv_sidecar,
            clean_uv,
            inset_px,
        )
        clean_items.append({
            "slot": slot,
            "source_type": "uv",
            "source": str(uv),
            "clean_uv": str(clean_uv),
            "config_patch": item.get("config_patch", {}),
        })
        variant_reports[slot] = {"variant": report, "top_edge_clean": clean_report}

    summary = {
        "run_dir": str(run_dir),
        "design_png": str(design_png),
        "design_sidecar": str(design_sidecar_path),
        "uv_sidecar": str(uv_sidecar_path),
        "fit_source": fit_source,
        "inset_px": inset_px,
        "top_outline_px": top_outline_px,
        "original_items": original_items,
        "clean_items": clean_items,
        "variant_reports": variant_reports,
        "note": "Prepare stage only. Generates 7 source-cut UVs and 7 top-edge-clean UVs from one 3D design image.",
    }
    _write_json(run_dir / "logs" / "single_design_21_prepare.json", summary)
    return summary


def _bake_variants(ns: dict, base_config: dict, prepared: dict, run_dir: Path) -> dict:
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
    out = {"original_no_ink": [], "top_edge_clean_no_ink": [], "top_edge_clean_blender_ink": []}
    try:
        for item in prepared["original_items"]:
            slot = item["slot"]
            uv = Path(item["source"])
            baked = run_dir / "baked" / "original_no_ink" / ("%s_original_no_ink.png" % slot)
            top21._bake_one(ns, base_config, uv, baked, no_ink_patch)
            out["original_no_ink"].append({"slot": slot, "uv": str(uv), "baked": str(baked), "config_patch": no_ink_patch})

        for item in prepared["clean_items"]:
            slot = item["slot"]
            uv = Path(item["clean_uv"])
            no_ink = run_dir / "baked" / "top_edge_clean_no_ink" / ("%s_top_edge_clean_no_ink.png" % slot)
            ink = run_dir / "baked" / "top_edge_clean_blender_ink" / ("%s_top_edge_clean_blender_ink.png" % slot)
            top21._bake_one(ns, base_config, uv, no_ink, no_ink_patch)
            top21._bake_one(ns, base_config, uv, ink, blender_ink_patch)
            out["top_edge_clean_no_ink"].append({"slot": slot, "uv": str(uv), "baked": str(no_ink), "config_patch": no_ink_patch})
            out["top_edge_clean_blender_ink"].append({"slot": slot, "uv": str(uv), "baked": str(ink), "config_patch": blender_ink_patch})
    finally:
        top21._reset_config(ns, base_config, {})
    return out


def bake(run_name: str) -> dict:
    repo = _repo_root()
    run_dir = repo / "blender" / "textures" / "_candidates" / run_name
    prepared = _read_json(run_dir / "logs" / "single_design_21_prepare.json")

    ns = top21._load_bake_assets(repo)
    top21._install_emission_image_material(ns)
    base_config = dict(ns["CONFIG"])
    bake_results = _bake_variants(ns, base_config, prepared, run_dir)

    summary = {
        "run_dir": str(run_dir),
        "bake_results": bake_results,
        "note": "Bake stage only. Uses emission image material; no lighting/shadow is baked into the matrix.",
    }
    _write_json(run_dir / "logs" / "single_design_21_bake.json", summary)
    return summary


def contact(run_name: str) -> dict:
    repo = _repo_root()
    run_dir = repo / "blender" / "textures" / "_candidates" / run_name
    prepared = _read_json(run_dir / "logs" / "single_design_21_prepare.json")
    baked = _read_json(run_dir / "logs" / "single_design_21_bake.json")
    bake_results = baked["bake_results"]

    shots = top21._make_contact_sheet(
        run_dir,
        bake_results["original_no_ink"],
        bake_results["top_edge_clean_no_ink"],
        bake_results["top_edge_clean_blender_ink"],
    )

    summary = {
        "run_dir": str(run_dir),
        "prepare": prepared,
        "bake_results": bake_results,
        "shots": shots,
        "note": "21 matrix = original source-cut 7 + top-edge-clean 7 + top-edge-clean-with-Blender-ink 7.",
    }
    _write_json(run_dir / "logs" / "single_design_21_matrix_summary.json", summary)
    (run_dir / "REPORT.md").write_text(
        "# Single Design 21 Matrix\n\n"
        "Input design: `%s`\n\n"
        "- original source-cut variants: 7\n"
        "- top-edge-clean variants: 7\n"
        "- top-edge-clean + Blender ink variants: 7\n"
        "- top-edge inset: `%.1fpx`\n\n"
        "- original top outline ownership: `%.1fpx`\n\n"
        "Contact sheets:\n\n"
        "- by variant: `%s`\n"
        "- by group: `%s`\n"
        % (
            prepared["design_png"],
            float(prepared["inset_px"]),
            float(prepared.get("top_outline_px", 0.0)),
            shots["by_variant"],
            shots["by_group"],
        ),
        encoding="utf-8",
    )
    return summary


def main():
    ap = argparse.ArgumentParser(description="Build a 21-image matrix from one 3D design image")
    ap.add_argument("--stage", choices=["prepare", "bake", "contact"], required=True)
    ap.add_argument("--run-name", default=RUN_NAME)
    ap.add_argument("--design-png", default=None)
    ap.add_argument("--design-sidecar", default=None)
    ap.add_argument("--uv-sidecar", default=None)
    ap.add_argument("--inset-px", type=float, default=18.0)
    ap.add_argument(
        "--top-outline-px",
        type=float,
        default=None,
        help="Top source outward ownership px. Defaults to 12 for frozen legacy runs, 0 for fit-json runs.",
    )
    ap.add_argument("--fit-json", default=None, help="fit.json (fitted top 6 verts); walls derive, overrides frozen recipe")
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else None
    args = ap.parse_args(argv)

    repo = _repo_root()
    if args.stage == "prepare":
        if not args.design_png:
            raise SystemExit("--design-png is required for prepare")
        design_sidecar = Path(args.design_sidecar) if args.design_sidecar else repo / DEFAULT_DESIGN_SIDECAR
        uv_sidecar = Path(args.uv_sidecar) if args.uv_sidecar else repo / DEFAULT_UV_SIDECAR
        fit_json = Path(args.fit_json) if args.fit_json else None
        top_outline_px = args.top_outline_px
        if top_outline_px is None:
            top_outline_px = 0.0 if fit_json is not None else 12.0
        summary = prepare(Path(args.design_png), args.run_name, design_sidecar, uv_sidecar, args.inset_px, top_outline_px, fit_json)
    elif args.stage == "bake":
        summary = bake(args.run_name)
    else:
        summary = contact(args.run_name)
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
