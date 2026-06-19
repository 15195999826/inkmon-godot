# texgen.source_cut_recipe_gen -- generate the 7 source-cut recipe variants
#
# Deterministic generator reverse-engineered from the frozen recipe in
#   blender/textures/_candidates/left-warp-source-cut-variants-baked-20260616-01/
#   logs/source_cut_variants_uv_report.json
#
# 6/7 slots match the frozen data exactly (next/prev/avoid seam). The
# all_wall_edges_inset_8 slot uses local-axes inset (a = b = 8 px, keeps the
# wall a parallelogram), NOT edge-normal inset -- verified 0.000000 px residual
# against the frozen data for all three walls.
#
# Input sidecar can be:
#   - a canonical template (blender/templates/standard-templates/template_design_e0.json)
#   - a fitted sidecar produced from fit.json (top + derived wall_3/4/5)
# Both must carry faces.{top, wall_3, wall_4, wall_5} as polygon_px / quad_px.

import argparse
import json
import math
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
BLENDER_SCRIPTS_DIR = SCRIPT_DIR.parent
if str(BLENDER_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(BLENDER_SCRIPTS_DIR))

from texgen import tile_pipeline_modes


WALL_ORDER = ["wall_3", "wall_4", "wall_5"]

SLOTS = [
    "original_both_faces_own",
    "next_face_owns_seam_12",
    "next_face_owns_seam_24",
    "prev_face_owns_seam_12",
    "prev_face_owns_seam_24",
    "both_faces_avoid_seam_10",
    "all_wall_edges_inset_8",
]

NO_INK_PATCH = {
    **tile_pipeline_modes.config_patch(tile_pipeline_modes.MODE2_HARD),
    "ink_enabled": False,
    "sun_energy": 0.0,
    "ambient_strength": 0.0,
    "material": "emission",
}


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path, data):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def face_poly(face):
    if isinstance(face, list):
        return [[float(x), float(y)] for x, y in face]
    poly = face.get("polygon_px") or face.get("quad_px")
    return [[float(x), float(y)] for x, y in poly]


def load_faces(sidecar):
    src = sidecar["faces"]
    return {
        "top": face_poly(src["top"]),
        "wall_3": face_poly(src["wall_3"]),
        "wall_4": face_poly(src["wall_4"]),
        "wall_5": face_poly(src["wall_5"]),
    }


def clone_poly(poly):
    return [[float(x), float(y)] for x, y in poly]


def unit(a, b):
    vx = b[0] - a[0]
    vy = b[1] - a[1]
    mag = max((vx * vx + vy * vy) ** 0.5, 1e-6)
    return vx / mag, vy / mag


def move_points(poly, indices, dx, dy):
    out = clone_poly(poly)
    for idx in indices:
        out[idx][0] += dx
        out[idx][1] += dy
    return out


def wall_top_unit(wp):
    # wall quad order: p0 TL, p1 TR, p2 BR, p3 BL
    return unit(wp[0], wp[1])


def move_left_edge_inward(wp, px):
    ux, uy = wall_top_unit(wp)
    return move_points(wp, [0, 3], ux * px, uy * px)


def move_right_edge_inward(wp, px):
    ux, uy = wall_top_unit(wp)
    return move_points(wp, [1, 2], -ux * px, -uy * px)


# --- all_wall_edges_inset_8: local-axes inset (keeps parallelogram) ----------
# Each wall is inset along its two local edge directions by inset_px, so the
# wall stays a parallelogram. Verified 0.000000 px residual vs frozen recipe
# for wall_3 / wall_4 / wall_5 (a = b = 8.0).

def _vsub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def _vnorm(v):
    m = math.hypot(v[0], v[1]) or 1e-9
    return (v[0] / m, v[1] / m)


def _vadd(a, b):
    return (a[0] + b[0], a[1] + b[1])


def _vscale(v, s):
    return (v[0] * s, v[1] * s)


def inset_wall_quad_local_axes(quad_px, inset_px=8.0):
    """Inset a wall quad along its two local edge directions, keeping it a
    parallelogram. quad_px order: p0,p1,p2,p3 = TL,TR,BR,BL.

      u_hat = unit along top edge  (p1 - p0)
      v_hat = unit along left edge (p3 - p0)

      p0' = p0 + inset*u_hat + inset*v_hat
      p1' = p1 - inset*u_hat + inset*v_hat
      p2' = p2 - inset*u_hat - inset*v_hat
      p3' = p3 + inset*u_hat - inset*v_hat
    """
    p0, p1, p2, p3 = quad_px
    u = _vnorm(_vsub(p1, p0))
    v = _vnorm(_vsub(p3, p0))
    d = float(inset_px)
    return [
        list(_vadd(p0, _vadd(_vscale(u, +d), _vscale(v, +d)))),
        list(_vadd(p1, _vadd(_vscale(u, -d), _vscale(v, +d)))),
        list(_vadd(p2, _vadd(_vscale(u, -d), _vscale(v, -d)))),
        list(_vadd(p3, _vadd(_vscale(u, +d), _vscale(v, -d)))),
    ]


def report_from_faces(faces):
    return {name: {"source_poly": clone_poly(poly)} for name, poly in faces.items()}


def build_variant_faces(base, slot):
    out = {name: clone_poly(poly) for name, poly in base.items()}

    if slot == "original_both_faces_own":
        return out

    if slot.startswith("next_face_owns_seam_"):
        px = float(slot.rsplit("_", 1)[1])
        out["wall_3"] = move_right_edge_inward(out["wall_3"], px)
        out["wall_4"] = move_right_edge_inward(out["wall_4"], px)
        return out

    if slot.startswith("prev_face_owns_seam_"):
        px = float(slot.rsplit("_", 1)[1])
        out["wall_4"] = move_left_edge_inward(out["wall_4"], px)
        out["wall_5"] = move_left_edge_inward(out["wall_5"], px)
        return out

    if slot == "both_faces_avoid_seam_10":
        px = 10.0
        out["wall_3"] = move_right_edge_inward(out["wall_3"], px)
        out["wall_4"] = move_left_edge_inward(out["wall_4"], px)
        out["wall_4"] = move_right_edge_inward(out["wall_4"], px)
        out["wall_5"] = move_left_edge_inward(out["wall_5"], px)
        return out

    if slot == "all_wall_edges_inset_8":
        px = 8.0
        for wall in WALL_ORDER:
            out[wall] = inset_wall_quad_local_axes(out[wall], px)
        return out

    raise ValueError("unknown slot: %s" % slot)


def build_recipe(sidecar, source_design=""):
    base = load_faces(sidecar)
    reports = {}
    for slot in SLOTS:
        if slot == "original_both_faces_own":
            # Consumer (single_design_21_matrix) reads the baseline face poly
            # directly from the design sidecar for this slot.
            reports[slot] = {"baseline": True}
            continue
        reports[slot] = report_from_faces(build_variant_faces(base, slot))

    return {
        "mode": "generated_source_cut_variants_v1",
        "source_design": source_design,
        "design_sidecar": sidecar.get("template") or "",
        "uv_sidecar": "",
        "outputs": {},
        "reports": reports,
        "note": "Generated from fitted/source sidecar. top face unchanged; wall seam variants move wall quad edges deterministically.",
    }


def build_bake_summary(out_dir):
    out_dir = Path(out_dir)
    items = []
    for slot in SLOTS:
        items.append({
            "slot": slot,
            "source_type": "uv",
            "source": str(out_dir / "uv" / ("%s_warp_uv.png" % slot)),
            "baked": str(out_dir / "baked" / ("%s_unlit_no_bevel.png" % slot)),
            "config_patch": dict(NO_INK_PATCH),
        })
    return {
        "run_dir": str(out_dir),
        "items": items,
    }


def main():
    ap = argparse.ArgumentParser(
        description="Generate 7 source-cut recipe variants from a design/fitted sidecar"
    )
    ap.add_argument(
        "--sidecar", required=True,
        help="template_design json or fitted sidecar (faces.top + wall_3/4/5)",
    )
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--source-design", default="")
    args = ap.parse_args()

    sidecar = read_json(args.sidecar)
    out_dir = Path(args.out_dir)
    recipe = build_recipe(sidecar, args.source_design)
    summary = build_bake_summary(out_dir)
    logs = out_dir / "logs"
    write_json(logs / "source_cut_variants_uv_report.json", recipe)
    write_json(logs / "source_cut_variants_bake_summary.json", summary)
    print(json.dumps({
        "recipe": str(logs / "source_cut_variants_uv_report.json"),
        "summary": str(logs / "source_cut_variants_bake_summary.json"),
    }, indent=2))


if __name__ == "__main__":
    main()
