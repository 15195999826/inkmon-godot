# texgen.beveled_tile_prototype -- candidate-only top bevel tile experiment
#
# This script is intentionally isolated from the production tile pipeline.
# It writes new runs under blender/textures/_candidates/<run-name>/ and builds a
# prototype mesh/template pair with explicit top bevel faces:
#   top + bevel_0..5 + wall_3/4/5
#
# Typical flow from repo root:
#   python blender/scripts/texgen/beveled_tile_prototype.py --stage templates
#   # generate/export raw images with texture-gen into <run>/raw/raw_*.png
#   python blender/scripts/texgen/beveled_tile_prototype.py --stage prepare
#   # in Blender MCP:
#   #   from texgen import beveled_tile_prototype as b; b.bake()
#   python blender/scripts/texgen/beveled_tile_prototype.py --stage contact

import argparse
import json
import math
import os
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
BLENDER_SCRIPTS_DIR = SCRIPT_DIR.parent
if str(BLENDER_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(BLENDER_SCRIPTS_DIR))

from texgen import geometry
from texgen import archive_paths
from texgen import tile_pipeline_modes
from texgen import top_edge_21_matrix as top21


RUN_NAME = "beveled-tile-prototype-20260617-01"
PIPELINE_MODE = tile_pipeline_modes.MODE3_TOP_EDGE_BEVEL
BEVEL_INSET_WORLD = 0.055
BEVEL_DROP_WORLD = 0.035
REPRESENTATIVE_TILE_INDEX = 3
DESIGN_BG = (255, 255, 255)
TEMPLATE_FILL = (246, 246, 242)
TOP_FILL = (247, 247, 242)
BEVEL_FILL = (233, 232, 220)
WALL_FILL = (240, 239, 232)
LINE_COLOR = (42, 42, 38)
HINGE_COLOR = (122, 118, 104)


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _run_dir(run_name: str = RUN_NAME) -> Path:
    return archive_paths.candidate_run(_repo_root(), run_name)


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def _load_pil():
    top21._load_pil()
    from PIL import ImageFilter
    return top21.Image, top21.ImageDraw, top21.ImageFont, ImageFilter


def _add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def _mul(a, s):
    return (a[0] * s, a[1] * s)


def _face_poly(face: dict) -> list:
    return face.get("polygon_px") or face["quad_px"]


def _edge_key(a, b):
    pa = (round(a[0], 1), round(a[1], 1))
    pb = (round(b[0], 1), round(b[1], 1))
    return (pa, pb) if pa <= pb else (pb, pa)


def _poly_edges(polys: list) -> tuple:
    seen = {}
    edges = {}
    for poly in polys:
        for idx, a in enumerate(poly):
            b = poly[(idx + 1) % len(poly)]
            key = _edge_key(a, b)
            seen[key] = seen.get(key, 0) + 1
            edges[key] = (a, b)
    outer = [edges[k] for k, count in seen.items() if count == 1]
    hinges = [edges[k] for k, count in seen.items() if count > 1]
    return outer, hinges


def _manifest() -> dict:
    return geometry.load_manifest()


def _bevel_world(manifest: dict) -> dict:
    """Return model-space vertices for top inner, top outer and wall bottom.

    outer: original hex top edge, at z=-BEVEL_DROP_WORLD
    inner: inset hex top edge, at z=0
    bottom: original hex bottom edge, at z=-tile_depth
    """
    edge = float(manifest["hex_edge_world"])
    depth = geometry.tile_depth(manifest, 0)
    # For a regular flat-top hex, radial shrink matching an inward edge offset d.
    radial_shrink = BEVEL_INSET_WORLD / math.cos(math.radians(30.0))
    inner_edge = max(0.01, edge - radial_shrink)
    inner = [(x, y, 0.0) for x, y in [geometry.hex_corner(i, inner_edge) for i in range(6)]]
    outer = [(x, y, -BEVEL_DROP_WORLD) for x, y in [geometry.hex_corner(i, edge) for i in range(6)]]
    bottom = [(x, y, -depth) for x, y in [geometry.hex_corner(i, edge) for i in range(6)]]
    return {
        "inner": inner,
        "outer": outer,
        "bottom": bottom,
        "inner_edge_world": inner_edge,
        "outer_edge_world": edge,
        "depth_world": depth,
    }


def _visible_wall_order(manifest: dict) -> list:
    return [int(i) for i in geometry.visible_walls(manifest)]


def _world_faces(manifest: dict) -> dict:
    w = _bevel_world(manifest)
    faces = {"top": w["inner"]}
    for i in range(6):
        faces["bevel_%d" % i] = [
            w["inner"][i],
            w["inner"][(i + 1) % 6],
            w["outer"][(i + 1) % 6],
            w["outer"][i],
        ]
    for i in _visible_wall_order(manifest):
        faces["wall_%d" % i] = [
            w["outer"][i],
            w["outer"][(i + 1) % 6],
            w["bottom"][(i + 1) % 6],
            w["bottom"][i],
        ]
    return faces


def design_layout(manifest: dict) -> dict:
    world_faces = _world_faces(manifest)
    project = geometry.projector(manifest)
    cw, ch = geometry.DESIGN_CANVAS

    all_pts = []
    for poly in world_faces.values():
        all_pts.extend(project(*p) for p in poly)
    xs = [p[0] for p in all_pts]
    ys = [p[1] for p in all_pts]
    scale = min((cw - 2 * geometry.DESIGN_MARGIN) / (max(xs) - min(xs)),
                (ch - 2 * geometry.DESIGN_MARGIN) / (max(ys) - min(ys)))
    ox = cw * 0.5 - (min(xs) + max(xs)) * 0.5 * scale
    oy = ch * 0.5 - (min(ys) + max(ys)) * 0.5 * scale

    def to_px(p):
        sx, sy = project(*p)
        return [sx * scale + ox, sy * scale + oy]

    faces = {}
    for name, poly in world_faces.items():
        key = "polygon_px" if name == "top" else "quad_px"
        faces[name] = {key: [to_px(p) for p in poly]}
    w = _bevel_world(manifest)
    return {
        "template": "beveled_design",
        "elevation": 0,
        "canvas": [cw, ch],
        "scale_px_per_unit": scale,
        "origin_px": [ox, oy],
        "bevel_inset_world": BEVEL_INSET_WORLD,
        "bevel_drop_world": BEVEL_DROP_WORLD,
        "inner_edge_world": w["inner_edge_world"],
        "faces": faces,
        "wall_order": _visible_wall_order(manifest),
        "manifest": geometry._manifest_excerpt(manifest),
    }


def uv_layout(manifest: dict) -> dict:
    Image, ImageDraw, _ImageFont, _ImageFilter = _load_pil()
    cw, ch = geometry.UV_CANVAS
    s = geometry.UV_PX_PER_UNIT
    w = _bevel_world(manifest)
    order = _visible_wall_order(manifest)

    def img(x, y):
        return (x * s, -y * s)

    inner2 = [img(p[0], p[1]) for p in w["inner"]]
    outer2 = [img(p[0], p[1]) for p in w["outer"]]
    faces = {"top": {"polygon_px": inner2}}

    # Bevel faces unfold as a ring between top inner and the original hex edge.
    for i in range(6):
        faces["bevel_%d" % i] = {
            "quad_px": [inner2[i], inner2[(i + 1) % 6], outer2[(i + 1) % 6], outer2[i]]
        }

    # Visible walls unfold outward from the original outer edge.
    wall_quads = {}
    wall_depth = w["depth_world"] - BEVEL_DROP_WORLD
    for i in order:
        a = (w["outer"][i][0], w["outer"][i][1])
        b = (w["outer"][(i + 1) % 6][0], w["outer"][(i + 1) % 6][1])
        na = math.radians(60.0 * i + 30.0)
        nx, ny = math.cos(na) * wall_depth, math.sin(na) * wall_depth
        q = [img(*a), img(*b), img(b[0] + nx, b[1] + ny), img(a[0] + nx, a[1] + ny)]
        wall_quads[i] = q
        faces["wall_%d" % i] = {"quad_px": q}

    all_pts = []
    for face in faces.values():
        all_pts.extend(_face_poly(face))
    min_x, max_x = min(p[0] for p in all_pts), max(p[0] for p in all_pts)
    min_y, max_y = min(p[1] for p in all_pts), max(p[1] for p in all_pts)
    ox = cw * 0.5 - (min_x + max_x) * 0.5
    oy = ch * 0.5 - (min_y + max_y) * 0.5

    def shift(poly):
        return [[p[0] + ox, p[1] + oy] for p in poly]

    out_faces = {}
    for name, face in faces.items():
        key = "polygon_px" if name == "top" else "quad_px"
        out_faces[name] = {key: shift(_face_poly(face))}
    out_faces["top"]["center_px"] = [ox, oy]
    out_faces["top"]["px_per_unit"] = s

    return {
        "template": "beveled_uv",
        "layout": "beveled_net_v1",
        "elevation": 0,
        "canvas": [cw, ch],
        "px_per_unit": s,
        "bevel_inset_world": BEVEL_INSET_WORLD,
        "bevel_drop_world": BEVEL_DROP_WORLD,
        "faces": out_faces,
        "bevel_order": list(range(6)),
        "wall_order": order,
        "manifest": geometry._manifest_excerpt(manifest),
    }


class _Sheet:
    def __init__(self, w: int, h: int):
        Image, ImageDraw, _ImageFont, _ImageFilter = _load_pil()
        self.w = w
        self.h = h
        self.svg = []
        self.img = Image.new("RGB", (w, h), DESIGN_BG)
        self.draw = ImageDraw.Draw(self.img)

    def poly(self, pts, fill=None, outline=LINE_COLOR, width=3):
        if fill is not None:
            self.draw.polygon([tuple(p) for p in pts], fill=fill)
        if outline is not None and width > 0:
            self.draw.line([tuple(p) for p in pts] + [tuple(pts[0])], fill=outline, width=width, joint="curve")
        d = "M " + " L ".join("%.2f %.2f" % (x, y) for x, y in pts) + " Z"
        fill_s = "none" if fill is None else "rgb%s" % (fill,)
        stroke_s = "none" if outline is None else "rgb%s" % (outline,)
        self.svg.append(
            '<path d="%s" fill="%s" stroke="%s" stroke-width="%d" stroke-linejoin="round"/>'
            % (d, fill_s, stroke_s, width)
        )

    def line(self, a, b, color=LINE_COLOR, width=3):
        self.draw.line([tuple(a), tuple(b)], fill=color, width=width)
        self.svg.append(
            '<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="rgb%s" stroke-width="%d" stroke-linecap="round"/>'
            % (a[0], a[1], b[0], b[1], color, width)
        )

    def save(self, path_stem: Path) -> list:
        path_stem.parent.mkdir(parents=True, exist_ok=True)
        svg_path = str(path_stem) + ".svg"
        png_path = str(path_stem) + ".png"
        with open(svg_path, "w", encoding="utf-8") as f:
            f.write('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n' % (self.w, self.h, self.w, self.h))
            f.write('<rect width="%d" height="%d" fill="white"/>\n' % (self.w, self.h))
            f.write("\n".join(self.svg))
            f.write("\n</svg>\n")
        self.img.save(png_path)
        return [svg_path, png_path]


def _draw_design(layout: dict) -> _Sheet:
    sheet = _Sheet(*layout["canvas"])
    faces = layout["faces"]
    # Fill large regions first, then draw shared edges once.
    sheet.poly(_face_poly(faces["top"]), fill=TOP_FILL, outline=None, width=0)
    for i in range(6):
        sheet.poly(_face_poly(faces["bevel_%d" % i]), fill=BEVEL_FILL, outline=None, width=0)
    for i in layout["wall_order"]:
        sheet.poly(_face_poly(faces["wall_%d" % int(i)]), fill=WALL_FILL, outline=None, width=0)
    polys = [_face_poly(faces["top"])]
    polys.extend(_face_poly(faces["bevel_%d" % i]) for i in range(6))
    polys.extend(_face_poly(faces["wall_%d" % int(i)]) for i in layout["wall_order"])
    outer, hinges = _poly_edges(polys)
    for a, b in outer:
        sheet.line(a, b, color=LINE_COLOR, width=3)
    for a, b in hinges:
        sheet.line(a, b, color=HINGE_COLOR, width=2)
    return sheet


def _draw_uv(layout: dict) -> _Sheet:
    sheet = _Sheet(*layout["canvas"])
    faces = layout["faces"]
    polys = []
    sheet.poly(_face_poly(faces["top"]), fill=TOP_FILL, outline=None, width=0)
    polys.append(_face_poly(faces["top"]))
    for i in range(6):
        p = _face_poly(faces["bevel_%d" % i])
        sheet.poly(p, fill=BEVEL_FILL, outline=None, width=0)
        polys.append(p)
    for i in layout["wall_order"]:
        p = _face_poly(faces["wall_%d" % int(i)])
        sheet.poly(p, fill=WALL_FILL, outline=None, width=0)
        polys.append(p)
    outer, hinges = _poly_edges(polys)
    for a, b in outer:
        sheet.line(a, b, color=LINE_COLOR, width=3)
    for a, b in hinges:
        sheet.line(a, b, color=HINGE_COLOR, width=2)
    return sheet


def templates(run_name: str = RUN_NAME, template_out: "str | None" = None,
              pitch_deg: "float | None" = None, yaw_deg: "float | None" = None) -> dict:
    run_dir = _run_dir(run_name)
    out_dir = Path(template_out) if template_out else run_dir / "templates"
    manifest = _manifest()
    if pitch_deg is not None:
        manifest["pitch_deg"] = float(pitch_deg)
    if yaw_deg is not None:
        manifest["yaw_deg"] = float(yaw_deg)
    d = design_layout(manifest)
    u = uv_layout(manifest)
    written = []
    for stem, layout, sheet in [
        ("beveled_design_e0", d, _draw_design(d)),
        ("beveled_uv_e0", u, _draw_uv(u)),
    ]:
        written.extend(sheet.save(out_dir / stem))
        sidecar = out_dir / ("%s.json" % stem)
        _write_json(sidecar, layout)
        written.append(str(sidecar))
    summary = {
        "run_dir": str(run_dir),
        "template_dir": str(out_dir),
        "templates": written,
        "pitch_deg": float(manifest["pitch_deg"]),
        "yaw_deg": float(manifest["yaw_deg"]),
        "bevel_inset_world": BEVEL_INSET_WORLD,
        "bevel_drop_world": BEVEL_DROP_WORLD,
    }
    if template_out:
        _write_json(out_dir / "templates.json", summary)
    else:
        _write_json(run_dir / "logs" / "templates.json", summary)
    return summary


def _nonwhite_bbox(path: Path, threshold: int = 246) -> tuple:
    Image, _ImageDraw, _ImageFont, _ImageFilter = _load_pil()
    img = Image.open(path).convert("RGB")
    pix = img.load()
    xs = []
    ys = []
    for y in range(img.height):
        for x in range(img.width):
            r, g, b = pix[x, y]
            if min(r, g, b) < threshold:
                xs.append(x)
                ys.append(y)
    if not xs:
        return (0, 0, img.width, img.height)
    return (min(xs), min(ys), max(xs) + 1, max(ys) + 1)


def _layout_bbox(layout: dict) -> tuple:
    pts = []
    for face in layout["faces"].values():
        pts.extend(_face_poly(face))
    return (min(p[0] for p in pts), min(p[1] for p in pts), max(p[0] for p in pts), max(p[1] for p in pts))


def _fit_layout_to_image(design_layout_data: dict, image_path: Path) -> dict:
    """Conservative bbox-only source fit for AI drift.

    The prototype template is generated as an image-to-image base. Low-quality
    generations still drift a few pixels, so a uniform bbox fit keeps source
    polygons inside the tile component without introducing freeform warping.
    """
    src = json.loads(json.dumps(design_layout_data))
    lb = _layout_bbox(src)
    ib = _nonwhite_bbox(image_path)
    lw, lh = lb[2] - lb[0], lb[3] - lb[1]
    iw, ih = ib[2] - ib[0], ib[3] - ib[1]
    scale = min(iw / max(lw, 1e-6), ih / max(lh, 1e-6))
    # Slightly shrink to avoid sampling white background around anti-aliased edges.
    scale *= 0.985
    lc = ((lb[0] + lb[2]) * 0.5, (lb[1] + lb[3]) * 0.5)
    ic = ((ib[0] + ib[2]) * 0.5, (ib[1] + ib[3]) * 0.5)

    def map_point(p):
        return [(p[0] - lc[0]) * scale + ic[0], (p[1] - lc[1]) * scale + ic[1]]

    for face in src["faces"].values():
        key = "polygon_px" if "polygon_px" in face else "quad_px"
        face[key] = [map_point(p) for p in face[key]]
    src["fit"] = {
        "mode": "bbox_uniform",
        "source_bbox": list(ib),
        "template_bbox": list(lb),
        "scale": scale,
    }
    return src


def _warp_face(design, source_poly: list, dst_poly: list, size: tuple):
    Image, _ImageDraw, _ImageFont, _ImageFilter = _load_pil()
    if len(source_poly) == 6 and len(dst_poly) == 6:
        coeffs = top21._affine_coeffs(
            [dst_poly[0], dst_poly[2], dst_poly[4]],
            [source_poly[0], source_poly[2], source_poly[4]],
        )
    else:
        coeffs = top21._affine_coeffs(
            [dst_poly[0], dst_poly[1], dst_poly[2]],
            [source_poly[0], source_poly[1], source_poly[2]],
        )
    warped = design.transform(size, Image.Transform.AFFINE, coeffs, resample=Image.Resampling.BICUBIC)
    mask = top21._poly_mask(size, dst_poly)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.paste(warped, (0, 0), mask)
    return canvas


def _face_order(uv: dict) -> list:
    return ["top"] + ["bevel_%d" % i for i in uv.get("bevel_order", list(range(6)))] + ["wall_%d" % int(i) for i in uv["wall_order"]]


def _warp_design_to_uv(design_png: Path, design_sidecar: dict, uv_sidecar: dict, out_path: Path) -> dict:
    Image, _ImageDraw, _ImageFont, _ImageFilter = _load_pil()
    design = Image.open(design_png).convert("RGBA")
    size = tuple(uv_sidecar["canvas"])
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    faces = {}
    for face in _face_order(uv_sidecar):
        source_poly = _face_poly(design_sidecar["faces"][face])
        dst_poly = _face_poly(uv_sidecar["faces"][face])
        warped = _warp_face(design, source_poly, dst_poly, size)
        canvas.alpha_composite(warped)
        faces[face] = {"source_poly": source_poly, "dst_poly": dst_poly}
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path)
    return {"design": str(design_png), "uv": str(out_path), "faces": faces, "fit": design_sidecar.get("fit", {})}


def prepare(run_name: str = RUN_NAME) -> dict:
    run_dir = _run_dir(run_name)
    design = _read_json(run_dir / "templates" / "beveled_design_e0.json")
    uv = _read_json(run_dir / "templates" / "beveled_uv_e0.json")
    raw_dir = run_dir / "raw"
    raw_paths = sorted(raw_dir.glob("raw_*.png"))
    if not raw_paths:
        raise FileNotFoundError("No raw images found in %s" % raw_dir)

    items = []
    for idx, raw in enumerate(raw_paths, 1):
        fitted = _fit_layout_to_image(design, raw)
        fitted_path = run_dir / "fit" / ("raw_%02d_beveled_design_fit.json" % idx)
        _write_json(fitted_path, fitted)
        uv_path = run_dir / "uv" / ("raw_%02d_beveled_uv.png" % idx)
        report = _warp_design_to_uv(raw, fitted, uv, uv_path)
        items.append({**report, "fit_sidecar": str(fitted_path), "index": idx})
    summary = {"run_dir": str(run_dir), "items": items}
    _write_json(run_dir / "logs" / "prepare.json", summary)
    return summary


def _load_bpy():
    import bpy  # noqa: F401
    return bpy


def _build_blender_material(ns: dict, image_path: Path):
    bpy = _load_bpy()
    mat = bpy.data.materials.get("mat_beveled_candidate")
    if mat is not None:
        bpy.data.materials.remove(mat)
    mat = bpy.data.materials.new("mat_beveled_candidate")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Strength"].default_value = 1.0
    img = ns["_load_image"](str(image_path))
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.extension = "EXTEND"
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs["Color"], emit.inputs["Color"])
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return mat


def _build_beveled_mesh(ns: dict, uv_path: Path):
    bpy = _load_bpy()
    from mathutils import Vector

    manifest = _manifest()
    uv = _read_json(_run_dir() / "templates" / "beveled_uv_e0.json")
    w = _bevel_world(manifest)
    verts = []
    verts.extend(w["inner"])
    verts.extend(w["outer"])
    verts.extend(w["bottom"])

    face_defs = []
    # Blender mesh face indices and matching uv sidecar face name.
    face_defs.append(("top", [0, 1, 2, 3, 4, 5]))
    for i in range(6):
        face_defs.append(("bevel_%d" % i, [i, (i + 1) % 6, 6 + ((i + 1) % 6), 6 + i]))
    for i in range(6):
        face_name = "wall_%d" % i
        # Invisible back walls still need material to close silhouette; map to opposite visible wall if needed.
        mapped = face_name if face_name in uv["faces"] else "wall_%d" % ((i + 3) % 6)
        face_defs.append((mapped, [6 + i, 6 + ((i + 1) % 6), 12 + ((i + 1) % 6), 12 + i]))
    face_defs.append(("bottom", [17, 16, 15, 14, 13, 12]))

    mesh = bpy.data.meshes.new("beveled_tile_candidate_mesh")
    mesh.from_pydata([tuple(v) for v in verts], [], [indices for _name, indices in face_defs])
    mesh.update()

    uv_layer = mesh.uv_layers.new(name="UVMap")
    cw, ch = uv["canvas"]

    def uv_of(px):
        return (px[0] / cw, 1.0 - px[1] / ch)

    loop_index = 0
    for poly_idx, (face_name, indices) in enumerate(face_defs):
        poly = mesh.polygons[poly_idx]
        if face_name == "bottom":
            center = uv["faces"]["top"]["center_px"]
            coords = [uv_of(center)] * len(indices)
        else:
            coords_px = _face_poly(uv["faces"][face_name])
            if face_name == "top":
                coords = [uv_of(p) for p in coords_px]
            else:
                coords = [uv_of(p) for p in coords_px]
        for k in range(poly.loop_total):
            uv_layer.data[loop_index + k].uv = coords[k]
        loop_index += poly.loop_total

    obj = bpy.data.objects.new("beveled_tile_candidate", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(_build_blender_material(ns, uv_path))
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def _bake_one(ns: dict, base_config: dict, uv_path: Path, out_path: Path):
    ns["CONFIG"].clear()
    ns["CONFIG"].update(base_config)
    ns["CONFIG"].update({
        **tile_pipeline_modes.config_patch(PIPELINE_MODE),
        "ink_enabled": False,
        "sun_energy": 0.0,
        "ambient_strength": 0.0,
        "samples": 16,
        "canvas_px": 2048,
        "px_per_unit": 512,
    })
    ns["setup_stage"]()
    ns["clear_assets"]()
    ns["ensure_shadow_catcher"](False)
    _build_beveled_mesh(ns, uv_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    ns["render_to"](str(out_path))


def bake(run_name: str = RUN_NAME) -> dict:
    run_dir = _run_dir(run_name)
    prepared = _read_json(run_dir / "logs" / "prepare.json")
    ns = top21._load_bake_assets(_repo_root())
    base_config = dict(ns["CONFIG"])
    outputs = []
    try:
        for item in prepared["items"]:
            idx = int(item["index"])
            uv_path = Path(item["uv"])
            out_path = run_dir / "baked_2048" / ("beveled_tile_%02d_2048.png" % idx)
            _bake_one(ns, base_config, uv_path, out_path)
            outputs.append({"index": idx, "uv": str(uv_path), "baked_2048": str(out_path)})
    finally:
        ns["CONFIG"].clear()
        ns["CONFIG"].update(base_config)
    summary = {"run_dir": str(run_dir), "outputs": outputs}
    _write_json(run_dir / "logs" / "bake.json", summary)
    return summary


def _downsample_and_sharpen(src: Path, dst: Path) -> None:
    Image, _ImageDraw, _ImageFont, ImageFilter = _load_pil()
    img = Image.open(src).convert("RGBA")
    out = img.resize((512, 512), Image.Resampling.LANCZOS)
    out = out.filter(ImageFilter.UnsharpMask(radius=0.75, percent=80, threshold=2))
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst)


def _checker(size, tile=16):
    Image, ImageDraw, _ImageFont, _ImageFilter = _load_pil()
    w, h = size
    bg = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(bg)
    for y in range(0, h, tile):
        for x in range(0, w, tile):
            c = (235, 234, 229, 255) if ((x // tile + y // tile) % 2 == 0) else (210, 210, 205, 255)
            d.rectangle([x, y, x + tile - 1, y + tile - 1], fill=c)
    return bg


def _panel(path: Path, label: str, target=(360, 320)):
    Image, ImageDraw, ImageFont, _ImageFilter = _load_pil()
    try:
        font = ImageFont.truetype("arial.ttf", 13)
    except Exception:
        font = ImageFont.load_default()
    img = Image.open(path).convert("RGBA")
    bbox = img.getbbox() or (0, 0, img.width, img.height)
    img = img.crop(bbox)
    img.thumbnail((target[0] - 18, target[1] - 42), Image.Resampling.NEAREST)
    panel = Image.new("RGBA", target, (245, 244, 239, 255))
    x = (target[0] - img.width) // 2
    y = 34 + (target[1] - 42 - img.height) // 2
    panel.alpha_composite(_checker(img.size), (x, y))
    panel.alpha_composite(img, (x, y))
    ImageDraw.Draw(panel).text((8, 8), label, fill=(20, 20, 20, 255), font=font)
    return panel.convert("RGB")


def _contact(paths: list, labels: list, out_path: Path, cols: int = 2, panel_size=(360, 320)) -> str:
    Image, _ImageDraw, _ImageFont, _ImageFilter = _load_pil()
    rows = int(math.ceil(len(paths) / float(cols)))
    sheet = Image.new("RGB", (panel_size[0] * cols, panel_size[1] * rows), (235, 234, 229))
    for i, path in enumerate(paths):
        sheet.paste(_panel(path, labels[i], panel_size), ((i % cols) * panel_size[0], (i // cols) * panel_size[1]))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path)
    return str(out_path)


def _compose_map(tile_path: Path, out_path: Path) -> str:
    Image, _ImageDraw, _ImageFont, _ImageFilter = _load_pil()
    manifest = geometry.load_manifest()
    pitch = math.radians(float(manifest["pitch_deg"]))
    yaw = math.radians(float(manifest["yaw_deg"]))
    edge_px = float(manifest["px_per_hex_edge"])
    sqrt3 = math.sqrt(3.0)
    bx = (math.cos(yaw), math.sin(yaw) * math.sin(pitch))
    by = (-math.sin(yaw), math.cos(yaw) * math.sin(pitch))

    def ground(v):
        x, y = v
        return (bx[0] * x + by[0] * y, bx[1] * x + by[1] * y)

    def center_flat(q, r):
        return (1.5 * q * edge_px, sqrt3 * (r + q * 0.5) * edge_px)

    coords = []
    radius = 3
    for q in range(-radius, radius + 1):
        for r in range(-radius, radius + 1):
            s = -q - r
            if max(abs(q), abs(r), abs(s)) <= radius and (q, r) not in {(-3, 0), (3, 0), (0, -3), (0, 3)}:
                coords.append((q, r))
    entries = []
    for q, r in coords:
        sx, sy = ground(center_flat(q, r))
        entries.append({"sort": (sx, sy), "pos": (sx, sy)})
    entries.sort(key=lambda e: (e["sort"][1], e["sort"][0]))

    minx = min(e["pos"][0] - 256 for e in entries)
    maxx = max(e["pos"][0] + 256 for e in entries)
    miny = min(e["pos"][1] - 256 for e in entries)
    maxy = max(e["pos"][1] + 256 for e in entries)
    pad = 80
    canvas = Image.new("RGBA", (int(math.ceil(maxx - minx + pad * 2)), int(math.ceil(maxy - miny + pad * 2))), (0, 0, 0, 0))
    tile = Image.open(tile_path).convert("RGBA")
    for e in entries:
        x = int(round(e["pos"][0] - minx + pad - 256))
        y = int(round(e["pos"][1] - miny + pad - 256))
        canvas.alpha_composite(tile, (x, y))
    preview = Image.new("RGBA", canvas.size, (238, 236, 229, 255))
    preview.alpha_composite(canvas, (0, 0))
    bbox = canvas.getbbox() or (0, 0, canvas.width, canvas.height)
    bbox = (max(0, bbox[0] - 32), max(0, bbox[1] - 32), min(canvas.width, bbox[2] + 32), min(canvas.height, bbox[3] + 32))
    preview.crop(bbox).convert("RGB").save(out_path)
    return str(out_path)


def _white_ratio_in_uv(uv_path: Path) -> float:
    Image, _ImageDraw, _ImageFont, _ImageFilter = _load_pil()
    img = Image.open(uv_path).convert("RGBA")
    total = 0
    white = 0
    for r, g, b, a in img.getdata():
        if a > 0:
            total += 1
            if r > 235 and g > 235 and b > 235:
                white += 1
    return white / max(total, 1)


def _white_ratio_in_rgb(path: Path) -> float:
    Image, _ImageDraw, _ImageFont, _ImageFilter = _load_pil()
    img = Image.open(path).convert("RGB")
    total = img.width * img.height
    white = 0
    for r, g, b in img.getdata():
        if r > 246 and g > 246 and b > 246:
            white += 1
    return white / max(total, 1)


def contact(run_name: str = RUN_NAME) -> dict:
    run_dir = _run_dir(run_name)
    raw_paths = sorted((run_dir / "raw").glob("raw_*.png"))
    baked = _read_json(run_dir / "logs" / "bake.json")
    baked512 = []
    for out in baked["outputs"]:
        src = Path(out["baked_2048"])
        dst = run_dir / "baked_512" / src.name.replace("_2048", "_512_sharp80")
        _downsample_and_sharpen(src, dst)
        baked512.append(dst)

    raw_contact = _contact(raw_paths, ["raw_%02d" % (i + 1) for i in range(len(raw_paths))], run_dir / "raw_contact.png", cols=2)
    baked_contact = _contact(baked512, ["beveled no-ink %02d" % (i + 1) for i in range(len(baked512))], run_dir / "baked_tile_contact.png", cols=2)

    representative_index = min(max(REPRESENTATIVE_TILE_INDEX, 1), len(baked512))
    representative_tile = baked512[representative_index - 1]
    current_tile = (
        archive_paths.existing_run(_repo_root(), "original-no-ink-map-20260617-01")
        / "baked_512_original_no_ink"
        / "tile03_original_no_ink_512_sharp80.png"
    )
    compare_paths = [current_tile, representative_tile]
    compare = _contact(compare_paths, ["current hard edge tile03", "beveled prototype tile%02d" % representative_index], run_dir / "compare_current_vs_beveled.png", cols=2, panel_size=(420, 340))
    current_map = _compose_map(current_tile, run_dir / "map_current_tile03_preview.png")
    beveled_map = _compose_map(representative_tile, run_dir / "map_beveled_preview.png")

    prepared = _read_json(run_dir / "logs" / "prepare.json")
    uv_white = [{"index": item["index"], "white_ratio": _white_ratio_in_uv(Path(item["uv"]))} for item in prepared["items"]]
    raw_white = [{"index": i + 1, "white_ratio": _white_ratio_in_rgb(path)} for i, path in enumerate(raw_paths)]
    prompt_path = run_dir / "prompt.txt"
    prompt_text = prompt_path.read_text(encoding="utf-8") if prompt_path.exists() else ""
    report_md = (
        "# Beveled Tile Prototype\n\n"
        "Candidate-only prototype for concept-style rounded top seams.\n\n"
        "## Parameters\n\n"
        "- pipeline: `mode3_top_edge_bevel` / `倒角`\n"
        "- pitch/yaw: current manifest `35.26 / -15`\n"
        "- bevel_inset_world: `%.3f`\n"
        "- bevel_drop_world: `%.3f`\n"
        "- representative tile: `tile%02d`\n"
        "- bake: `2048 internal -> 512 Lanczos + UnsharpMask(radius=0.75, percent=80, threshold=2)`\n"
        "- ink: no Blender Freestyle / no Blender ink\n\n"
        "## Prompt\n\n```text\n%s\n```\n\n"
        "## Outputs\n\n"
        "- raw contact: `%s`\n"
        "- baked tile contact: `%s`\n"
        "- current vs beveled: `%s`\n"
        "- current map: `%s`\n"
        "- beveled map: `%s`\n\n"
        "## Raw White Background Ratio\n\n%s\n\n"
        "## UV White Ratio\n\n%s\n"
        "\n## Visual Conclusion\n\n"
        "- The explicit bevel mesh works: the top-wall join becomes a visible chamfer band instead of only a flat black outline.\n"
        "- This default is not final: in the stitched map the bevel reads as a repeated golden rim, so tile-to-tile seams are more visible than the concept reference.\n"
        "- The next pass should narrow and darken the bevel band, or make shared seams choose one owner side, so the map reads as dark crevice plus light catch instead of double highlight.\n"
        % (
            BEVEL_INSET_WORLD,
            BEVEL_DROP_WORLD,
            representative_index,
            prompt_text.strip(),
            raw_contact,
            baked_contact,
            compare,
            current_map,
            beveled_map,
            "\n".join("- raw_%02d: %.2f%%" % (int(x["index"]), x["white_ratio"] * 100.0) for x in raw_white),
            "\n".join("- raw_%02d: %.4f%%" % (int(x["index"]), x["white_ratio"] * 100.0) for x in uv_white),
        )
    )
    (run_dir / "REPORT.md").write_text(report_md, encoding="utf-8")
    summary = {
        "run_dir": str(run_dir),
        "raw_contact": raw_contact,
        "baked_tile_contact": baked_contact,
        "compare_current_vs_beveled": compare,
        "map_current_tile03_preview": current_map,
        "map_beveled_preview": beveled_map,
        "representative_tile_index": representative_index,
        "raw_white_ratio": raw_white,
        "uv_white_ratio": uv_white,
    }
    _write_json(run_dir / "logs" / "contact.json", summary)
    return summary


def validate_templates(run_name: str = RUN_NAME, template_dir: "str | None" = None) -> dict:
    run_dir = _run_dir(run_name)
    src_dir = Path(template_dir) if template_dir else run_dir / "templates"
    results = {}
    for name in ["beveled_design_e0", "beveled_uv_e0"]:
        data = _read_json(src_dir / ("%s.json" % name))
        required = ["top"] + ["bevel_%d" % i for i in range(6)] + ["wall_%d" % int(i) for i in data["wall_order"]]
        missing = [x for x in required if x not in data["faces"] or len(_face_poly(data["faces"][x])) == 0]
        results[name] = {"canvas": data["canvas"], "required_count": len(required), "missing": missing}
        if missing:
            raise ValueError("%s missing faces: %s" % (name, missing))
    return results


def main():
    ap = argparse.ArgumentParser(description="Candidate-only beveled tile prototype")
    ap.add_argument("--stage", choices=["templates", "validate", "prepare", "contact"], required=True)
    ap.add_argument("--run-name", default=RUN_NAME)
    ap.add_argument("--template-out", default=None, help="write template files outside the candidate run directory")
    ap.add_argument("--template-dir", default=None, help="validate template files outside the candidate run directory")
    ap.add_argument("--pitch-deg", type=float, default=None, help="override manifest pitch_deg for template generation")
    ap.add_argument("--yaw-deg", type=float, default=None, help="override manifest yaw_deg for template generation")
    args = ap.parse_args()
    if args.stage == "templates":
        out = templates(args.run_name, template_out=args.template_out, pitch_deg=args.pitch_deg, yaw_deg=args.yaw_deg)
    elif args.stage == "validate":
        out = validate_templates(args.run_name, template_dir=args.template_dir)
    elif args.stage == "prepare":
        out = prepare(args.run_name)
    else:
        out = contact(args.run_name)
    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
