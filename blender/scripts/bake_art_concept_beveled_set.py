"""Bake concept-style explicit top-edge bevel tile assets for art exploration."""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import subprocess
import sys
import tempfile
import traceback
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import bake_assets  # noqa: E402
from texgen import geometry, tile_pipeline_modes  # noqa: E402


TERRAINS = ("grass", "dirt", "stone", "water")
ELEVATIONS = (0, 1, 2)
DECOR_ANCHORS = {
    "decor_pine": [256.0, 372.0],
    "decor_pine_tall": [256.0, 404.0],
    "decor_bush": [256.0, 324.0],
    "decor_rocks": [256.0, 322.0],
}
DECOR_SIZE_PX = [512, 512]
BEVEL_INSET_WORLD = 0.055
BEVEL_DROP_WORLD = 0.035
DEFAULT_EXTRA_STROKE_PX = 1
DEFAULT_CHIP_COUNT_PER_EDGE = 3
DEFAULT_CHIP_DEPTH_WORLD = 0.070
DEFAULT_CHIP_WIDTH_RATIO = 0.100
DEFAULT_CHIP_SEGMENTS_PER_EDGE = 12
DEFAULT_CHIP_SEED = 20260625


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _rel(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(_repo_root()).as_posix()
    except ValueError:
        return str(resolved)


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _face_poly(face: dict) -> list:
    return face.get("polygon_px") or face["quad_px"]


def _poly_center(points: list) -> tuple[float, float]:
    return (
        sum(p[0] for p in points) / len(points),
        sum(p[1] for p in points) / len(points),
    )


def _inset_point(point, center, inset_px: float):
    if inset_px <= 0.0:
        return point
    dx = center[0] - point[0]
    dy = center[1] - point[1]
    dist = math.hypot(dx, dy)
    if dist <= 1e-6:
        return point
    step = min(inset_px, dist - 1e-6) / dist
    return (point[0] + dx * step, point[1] + dy * step)


def _lerp2(a, b, t: float) -> tuple[float, float]:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _lerp3(a, b, t: float) -> tuple[float, float, float]:
    return (
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
    )


def _edge_inward_normal(edge_index: int) -> tuple[float, float]:
    angle = math.radians(60.0 * edge_index + 30.0)
    return (-math.cos(angle), -math.sin(angle))


def _chip_specs(edge_index: int) -> list[dict]:
    cfg = bake_assets.CONFIG
    count = max(0, int(cfg.get("chip_count_per_edge", 0)))
    if count <= 0:
        return []
    rng = random.Random(int(cfg.get("chip_seed", DEFAULT_CHIP_SEED)) + edge_index * 7919)
    specs = []
    for _idx in range(count):
        center = rng.uniform(0.16, 0.84)
        half_width = float(cfg.get("chip_width_ratio", DEFAULT_CHIP_WIDTH_RATIO)) * rng.uniform(0.75, 1.25)
        depth = float(cfg.get("chip_depth_world", DEFAULT_CHIP_DEPTH_WORLD)) * rng.uniform(0.55, 1.0)
        specs.append({"center": center, "half_width": half_width, "depth": depth})
    return specs


def _chip_extra_at(specs: list[dict], t: float) -> float:
    if t < 0.035 or t > 0.965:
        return 0.0
    extra = 0.0
    for spec in specs:
        half_width = max(1e-6, float(spec["half_width"]))
        falloff = max(0.0, 1.0 - abs(t - float(spec["center"])) / half_width)
        extra = max(extra, float(spec["depth"]) * falloff)
    return extra


def _chipped_bevel_world(manifest: dict, elevation: int) -> dict:
    w = _bevel_world(manifest, elevation)
    segments = max(2, int(bake_assets.CONFIG.get("chip_segments_per_edge", DEFAULT_CHIP_SEGMENTS_PER_EDGE)))
    inner: list[tuple[float, float, float]] = []
    outer: list[tuple[float, float, float]] = []
    bottom: list[tuple[float, float, float]] = []
    meta: list[dict] = []
    edge_indices: list[list[int]] = []
    edge_t_values: list[list[float]] = []

    for edge_index in range(6):
        specs = _chip_specs(edge_index)
        t_values = {i / float(segments) for i in range(segments)}
        for spec in specs:
            center = float(spec["center"])
            half_width = float(spec["half_width"])
            for value in (center - half_width, center, center + half_width):
                if 0.0 <= value < 1.0:
                    t_values.add(value)
        ordered_t = sorted(t_values)
        edge_t_values.append(ordered_t)
        edge_indices.append([])

        inward = _edge_inward_normal(edge_index)
        for t in ordered_t:
            idx = len(inner)
            extra = _chip_extra_at(specs, t)
            base_inner = _lerp3(w["inner"][edge_index], w["inner"][(edge_index + 1) % 6], t)
            inner.append((base_inner[0] + inward[0] * extra, base_inner[1] + inward[1] * extra, base_inner[2]))
            outer.append(_lerp3(w["outer"][edge_index], w["outer"][(edge_index + 1) % 6], t))
            bottom.append(_lerp3(w["bottom"][edge_index], w["bottom"][(edge_index + 1) % 6], t))
            meta.append({"edge": edge_index, "t": t, "chip_extra_world": extra})
            edge_indices[edge_index].append(idx)

    return {
        "inner": inner,
        "outer": outer,
        "bottom": bottom,
        "meta": meta,
        "edge_indices": edge_indices,
        "edge_t_values": edge_t_values,
    }


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
    if bake_assets.CONFIG.get("rim_profile") == "chipped":
        return _build_chipped_beveled_mesh(uv_path, uv_sidecar_path, elevation)

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
            face_info = uv["faces"][face_name]
            source_poly = _face_poly(face_info)
            center = face_info.get("center_px") or _poly_center(source_poly)
            inset_px = float(bake_assets.CONFIG.get("uv_inset_px", 0.0))
            coords = [uv_of(_inset_point(point, center, inset_px)) for point in source_poly]
        for k in range(poly.loop_total):
            uv_layer.data[loop_index + k].uv = coords[k]
        loop_index += poly.loop_total

    obj = bpy.data.objects.new(f"concept_beveled_tile_e{elevation}", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(bake_assets._tile_material_image("mat_concept_beveled_candidate", str(uv_path)))
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def _top_uv(uv: dict, edge_index: int, t: float, chip_extra_world: float) -> tuple[float, float]:
    top = uv["faces"]["top"]
    poly = _face_poly(top)
    point = _lerp2(poly[edge_index], poly[(edge_index + 1) % 6], t)
    if chip_extra_world > 0.0:
        center = top.get("center_px") or _poly_center(poly)
        px_per_unit = float(top.get("px_per_unit", uv.get("px_per_unit", 256.0)))
        step_px = chip_extra_world * px_per_unit
        dx = center[0] - point[0]
        dy = center[1] - point[1]
        dist = math.hypot(dx, dy)
        if dist > 1e-6:
            point = (point[0] + dx / dist * step_px, point[1] + dy / dist * step_px)
    return point


def _bevel_inner_uv(uv: dict, edge_index: int, t: float, chip_extra_world: float) -> tuple[float, float]:
    return _top_uv(uv, edge_index, t, chip_extra_world)


def _bevel_outer_uv(uv: dict, edge_index: int, t: float) -> tuple[float, float]:
    q = uv["faces"][f"bevel_{edge_index}"]["quad_px"]
    return _lerp2(q[3], q[2], t)


def _wall_uv(uv: dict, edge_index: int, t: float, bottom: bool) -> tuple[float, float]:
    face_name = f"wall_{edge_index}"
    mapped = face_name if face_name in uv["faces"] else f"wall_{(edge_index + 3) % 6}"
    q = uv["faces"][mapped]["quad_px"]
    return _lerp2(q[3], q[2], t) if bottom else _lerp2(q[0], q[1], t)


def _build_chipped_beveled_mesh(uv_path: Path, uv_sidecar_path: Path, elevation: int):
    manifest = geometry.load_manifest()
    uv = _read_json(uv_sidecar_path)
    w = _chipped_bevel_world(manifest, elevation)
    count = len(w["inner"])
    verts = []
    verts.extend(w["inner"])
    verts.extend(w["outer"])
    verts.extend(w["bottom"])

    face_defs: list[tuple[str, list[int], list[tuple[float, float]]]] = []
    top_indices = list(range(count))
    top_uvs = [
        _top_uv(uv, int(item["edge"]), float(item["t"]), float(item["chip_extra_world"]))
        for item in w["meta"]
    ]
    face_defs.append(("top", top_indices, top_uvs))

    for edge_index in range(6):
        indices = w["edge_indices"][edge_index] + [w["edge_indices"][(edge_index + 1) % 6][0]]
        t_values = w["edge_t_values"][edge_index] + [1.0]
        chip_values = [
            float(w["meta"][idx]["chip_extra_world"]) for idx in w["edge_indices"][edge_index]
        ] + [0.0]
        for seg in range(len(indices) - 1):
            a = indices[seg]
            b = indices[seg + 1]
            t0 = t_values[seg]
            t1 = t_values[seg + 1]
            c0 = chip_values[seg]
            c1 = chip_values[seg + 1]
            face_defs.append((
                f"bevel_{edge_index}",
                [a, b, count + b, count + a],
                [
                    _bevel_inner_uv(uv, edge_index, t0, c0),
                    _bevel_inner_uv(uv, edge_index, t1, c1),
                    _bevel_outer_uv(uv, edge_index, t1),
                    _bevel_outer_uv(uv, edge_index, t0),
                ],
            ))
            face_defs.append((
                f"wall_{edge_index}",
                [count + a, count + b, count * 2 + b, count * 2 + a],
                [
                    _wall_uv(uv, edge_index, t0, False),
                    _wall_uv(uv, edge_index, t1, False),
                    _wall_uv(uv, edge_index, t1, True),
                    _wall_uv(uv, edge_index, t0, True),
                ],
            ))

    face_defs.append(("bottom", list(range(count * 3 - 1, count * 2 - 1, -1)), [uv["faces"]["top"]["center_px"]] * count))

    mesh = bpy.data.meshes.new(f"concept_beveled_tile_e{elevation}_chipped_mesh")
    mesh.from_pydata([tuple(v) for v in verts], [], [indices for _name, indices, _uvs in face_defs])
    mesh.update()

    uv_layer = mesh.uv_layers.new(name="UVMap")
    cw, ch = uv["canvas"]

    def uv_of(point):
        return (point[0] / cw, 1.0 - point[1] / ch)

    loop_index = 0
    for poly_index, (_face_name, _indices, coords_px) in enumerate(face_defs):
        poly = mesh.polygons[poly_index]
        for k in range(poly.loop_total):
            uv_layer.data[loop_index + k].uv = uv_of(coords_px[k])
        loop_index += poly.loop_total

    obj = bpy.data.objects.new(f"concept_beveled_tile_e{elevation}_chipped", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(bake_assets._tile_material_image("mat_concept_beveled_chipped_candidate", str(uv_path)))
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def _to_vec3(point) -> Vector:
    return Vector((float(point[0]), float(point[1]), float(point[2])))


def _project_world_to_px(point) -> tuple[float, float]:
    scene = bpy.context.scene
    cam = scene.camera
    canvas = float(bake_assets.CONFIG["canvas_px"])
    co = world_to_camera_view(scene, cam, _to_vec3(point))
    return (co.x * canvas, (1.0 - co.y) * canvas)


def _wall_visible(outer_a, outer_b, bottom_b, view_dir: Vector) -> bool:
    a = _to_vec3(outer_a)
    b = _to_vec3(outer_b)
    c = _to_vec3(bottom_b)
    normal = (b - a).cross(c - a)
    if normal.length < 1e-6:
        return False
    normal.normalize()
    return normal.dot(view_dir) < -1e-5


def _line_path(points, *, width_px: float, alpha: int, wobble_px: float, seed: int, kind: str) -> dict:
    return {
        "points": [_project_world_to_px(p) for p in points],
        "width_px": width_px,
        "alpha": int(max(0, min(255, alpha))),
        "wobble_px": max(0.0, float(wobble_px)),
        "seed": int(seed),
        "kind": kind,
    }


def _bevel_edge_indices(w: dict, edge_index: int, chipped_rim: bool) -> list[int]:
    if not chipped_rim:
        return [edge_index, (edge_index + 1) % 6]
    return list(w["edge_indices"][edge_index]) + [w["edge_indices"][(edge_index + 1) % 6][0]]


def _bevel_corner_index(w: dict, edge_index: int, chipped_rim: bool) -> int:
    if not chipped_rim:
        return edge_index % 6
    return int(w["edge_indices"][edge_index % 6][0])


def _collect_painter_bevel_lines(
    elevation: int,
    chipped_rim: bool,
    *,
    line_width_px: float,
    line_alpha: int,
    line_wobble_px: float,
    cracks_enabled: bool,
    crack_seed: int,
) -> list[dict]:
    manifest = geometry.load_manifest()
    w = _chipped_bevel_world(manifest, elevation) if chipped_rim else _bevel_world(manifest, elevation)
    scene = bpy.context.scene
    view_dir = scene.camera.rotation_euler.to_matrix() @ Vector((0.0, 0.0, -1.0))

    visible_edges = []
    for edge_index in range(6):
        a = _bevel_corner_index(w, edge_index, chipped_rim)
        b = _bevel_corner_index(w, edge_index + 1, chipped_rim)
        visible_edges.append(_wall_visible(w["outer"][a], w["outer"][b], w["bottom"][b], view_dir))

    # If face winding is inverted by a future mesh edit, keep the pass useful.
    if not any(visible_edges):
        visible_edges = [not item for item in visible_edges]

    lines: list[dict] = []
    seed = int(crack_seed) + elevation * 1009
    for edge_index, visible in enumerate(visible_edges):
        if not visible:
            continue
        indices = _bevel_edge_indices(w, edge_index, chipped_rim)
        lines.append(_line_path(
            [w["outer"][idx] for idx in indices],
            width_px=line_width_px,
            alpha=line_alpha,
            wobble_px=line_wobble_px,
            seed=seed + edge_index * 17 + 1,
            kind="outer_wall_top",
        ))
        lines.append(_line_path(
            [w["bottom"][idx] for idx in indices],
            width_px=line_width_px,
            alpha=int(line_alpha * 0.9),
            wobble_px=line_wobble_px,
            seed=seed + edge_index * 17 + 2,
            kind="wall_bottom",
        ))

    for corner_index in range(6):
        if not (visible_edges[corner_index] or visible_edges[(corner_index - 1) % 6]):
            continue
        idx = _bevel_corner_index(w, corner_index, chipped_rim)
        lines.append(_line_path(
            [w["outer"][idx], w["bottom"][idx]],
            width_px=line_width_px,
            alpha=int(line_alpha * 0.95),
            wobble_px=line_wobble_px * 0.8,
            seed=seed + corner_index * 23 + 101,
            kind="wall_vertical_corner",
        ))

    if cracks_enabled:
        for edge_index, visible in enumerate(visible_edges):
            if not visible:
                continue
            a = _bevel_corner_index(w, edge_index, chipped_rim)
            b = _bevel_corner_index(w, edge_index + 1, chipped_rim)
            rng = random.Random(seed + edge_index * 811)
            for crack_idx in range(3):
                t = rng.uniform(0.18, 0.82)
                start_f = rng.uniform(0.18, 0.62)
                end_f = min(0.92, start_f + rng.uniform(0.08, 0.22))
                top = _lerp3(w["outer"][a], w["outer"][b], t)
                bottom = _lerp3(w["bottom"][a], w["bottom"][b], t)
                start = _lerp3(top, bottom, start_f)
                end = _lerp3(top, bottom, end_f)
                lines.append(_line_path(
                    [start, end],
                    width_px=max(0.25, line_width_px * 0.75),
                    alpha=int(line_alpha * 0.65),
                    wobble_px=line_wobble_px * 0.65,
                    seed=seed + edge_index * 97 + crack_idx * 7 + 401,
                    kind="wall_crack",
                ))
                if rng.random() < 0.35:
                    branch_t = max(0.08, min(0.92, t + rng.choice([-1.0, 1.0]) * rng.uniform(0.035, 0.08)))
                    branch_f = min(0.92, start_f + rng.uniform(0.035, 0.09))
                    branch_top = _lerp3(w["outer"][a], w["outer"][b], branch_t)
                    branch_bottom = _lerp3(w["bottom"][a], w["bottom"][b], branch_t)
                    branch_end = _lerp3(branch_top, branch_bottom, branch_f)
                    mid = _lerp3(start, end, rng.uniform(0.35, 0.7))
                    lines.append(_line_path(
                        [mid, branch_end],
                        width_px=max(0.2, line_width_px * 0.55),
                        alpha=int(line_alpha * 0.45),
                        wobble_px=line_wobble_px * 0.45,
                        seed=seed + edge_index * 97 + crack_idx * 7 + 701,
                        kind="wall_crack_branch",
                    ))
    return lines


def apply_painter_bevel_lines(
    image_path: Path,
    elevation: int,
    chipped_rim: bool,
    *,
    line_width_px: float,
    line_alpha: int,
    line_wobble_px: float,
    cracks_enabled: bool,
    crack_seed: int,
) -> None:
    lines = _collect_painter_bevel_lines(
        elevation,
        chipped_rim,
        line_width_px=line_width_px,
        line_alpha=line_alpha,
        line_wobble_px=line_wobble_px,
        cracks_enabled=cracks_enabled,
        crack_seed=crack_seed,
    )
    if not lines:
        return
    helper = r'''
import json
import math
import random
import sys
from pathlib import Path
from PIL import Image, ImageDraw

request = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
path = Path(request["image_path"])
scale = int(request["scale"])
image = Image.open(path).convert("RGBA")
overlay = Image.new("RGBA", (image.width * scale, image.height * scale), (0, 0, 0, 0))
draw = ImageDraw.Draw(overlay, "RGBA")

def expanded_points(points, max_step=18.0):
    out = []
    for idx in range(len(points) - 1):
        x0, y0 = points[idx]
        x1, y1 = points[idx + 1]
        dist = math.hypot(x1 - x0, y1 - y0)
        steps = max(1, int(math.ceil(dist / max_step)))
        for step in range(steps):
            if idx > 0 and step == 0:
                continue
            t = step / steps
            out.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    out.append(tuple(points[-1]))
    return out

def jittered(points, seed, amplitude):
    rng = random.Random(seed)
    expanded = expanded_points(points)
    if len(expanded) <= 2 or amplitude <= 0:
        return expanded
    out = []
    for idx, (x, y) in enumerate(expanded):
        if idx == 0 or idx == len(expanded) - 1:
            out.append((x, y))
            continue
        px, py = expanded[idx - 1]
        nx, ny = expanded[idx + 1]
        dx = nx - px
        dy = ny - py
        length = math.hypot(dx, dy) or 1.0
        ox = -dy / length
        oy = dx / length
        amount = rng.uniform(-amplitude, amplitude)
        out.append((x + ox * amount, y + oy * amount))
    return out

for line in request["lines"]:
    points = [tuple(p) for p in line["points"]]
    if len(points) < 2:
        continue
    for pass_index, strength in enumerate((1.0, 0.42)):
        pts = jittered(points, int(line["seed"]) + pass_index * 100003, float(line["wobble_px"]) * (1.0 + pass_index * 0.35))
        scaled = [(x * scale, y * scale) for x, y in pts]
        width = max(1, int(round(float(line["width_px"]) * scale * (1.0 - pass_index * 0.22))))
        alpha = max(0, min(255, int(float(line["alpha"]) * strength)))
        draw.line(scaled, fill=(0, 0, 0, alpha), width=width)

overlay = overlay.resize(image.size, Image.Resampling.LANCZOS)
Image.alpha_composite(image, overlay).save(path)
'''
    python_exe = os.environ.get("PYTHON", "python")
    with tempfile.TemporaryDirectory(prefix="inkmon_painter_bevel_lines_") as temp_dir:
        request_path = Path(temp_dir) / "request.json"
        helper_path = Path(temp_dir) / "painter_bevel_lines.py"
        request_path.write_text(json.dumps({
            "image_path": str(image_path),
            "scale": 8,
            "lines": lines,
        }, ensure_ascii=False), encoding="utf-8")
        helper_path.write_text(helper, encoding="utf-8")
        result = subprocess.run(
            [python_exe, str(helper_path), str(request_path)],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            raise RuntimeError(
                "painter bevel lines failed:\nSTDOUT:\n%s\nSTDERR:\n%s"
                % (result.stdout, result.stderr)
            )


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
        "comment": "Concept explicit top-edge bevel bake set. Source raw style: docs/concept.jpg. No fable texture/decor referenced.",
        "pipeline": pipeline["id"],
        "pipeline_name": pipeline["zh_name"],
        "pitch_deg": cfg["pitch_deg"],
        "yaw_deg": cfg["yaw_deg"],
        "hex_orientation": "flat_top",
        "sun_elevation_deg": cfg["sun_elevation_deg"],
        "sun_azimuth_deg": cfg["sun_azimuth_deg"],
        "material_mode": cfg.get("tile_image_material_mode", "emission"),
        "uv_inset_px": cfg.get("uv_inset_px", 0.0),
        "ink_color": list(cfg.get("ink_color", (0.16, 0.12, 0.08))),
        "stroke_mode": cfg.get("stroke_mode", "default"),
        "extra_stroke_px": cfg.get("extra_stroke_px", 0),
        "extra_stroke_scope": cfg.get("extra_stroke_scope", "none"),
        "painter_line_mode": cfg.get("painter_line_mode", "none"),
        "painter_line_width_px": cfg.get("painter_line_width_px", 0.0),
        "painter_line_alpha": cfg.get("painter_line_alpha", 0),
        "painter_line_wobble_px": cfg.get("painter_line_wobble_px", 0.0),
        "painter_cracks_enabled": cfg.get("painter_cracks_enabled", False),
        "ink_thickness_position": cfg.get("ink_thickness_position", "INSIDE"),
        "ink_select_crease": cfg.get("ink_select_crease", True),
        "ink_wobble_px": cfg.get("ink_wobble_px", 0.0),
        "px_per_unit": cfg["px_per_unit"],
        "hex_edge_world": cfg["hex_edge"],
        "px_per_hex_edge": cfg["px_per_unit"] * cfg["hex_edge"],
        "thickness_world": cfg["thickness"],
        "elevation_step_world": cfg["elevation_step"],
        "water_recess_world": cfg["water_recess"],
        "bevel_inset_world": BEVEL_INSET_WORLD,
        "bevel_drop_world": BEVEL_DROP_WORLD,
        "rim_profile": cfg.get("rim_profile", "regular"),
        "chip_count_per_edge": cfg.get("chip_count_per_edge", 0),
        "chip_depth_world": cfg.get("chip_depth_world", 0.0),
        "chip_width_ratio": cfg.get("chip_width_ratio", 0.0),
        "chip_segments_per_edge": cfg.get("chip_segments_per_edge", 0),
        "chip_seed": cfg.get("chip_seed", None),
        "assets": assets,
    }


def bake_set(
    uv_dir: Path,
    out_dir: Path,
    samples: int,
    ink_enabled: bool,
    bevel_inset_world: float | None = None,
    bevel_drop_world: float | None = None,
    uv_inset_px: float = 0.0,
    black_ink: bool = False,
    extra_stroke: bool = False,
    extra_stroke_px: float = DEFAULT_EXTRA_STROKE_PX,
    painter_lines: bool = False,
    painter_line_width_px: float = 0.55,
    painter_line_alpha: int = 92,
    painter_line_wobble_px: float = 0.45,
    painter_cracks: bool = False,
    painter_seed: int = 20260625,
    chipped_rim: bool = False,
    chip_count_per_edge: int = DEFAULT_CHIP_COUNT_PER_EDGE,
    chip_depth_world: float = DEFAULT_CHIP_DEPTH_WORLD,
    chip_width_ratio: float = DEFAULT_CHIP_WIDTH_RATIO,
    chip_segments_per_edge: int = DEFAULT_CHIP_SEGMENTS_PER_EDGE,
    chip_seed: int = DEFAULT_CHIP_SEED,
    only_keys: set[str] | None = None,
) -> dict:
    global BEVEL_INSET_WORLD, BEVEL_DROP_WORLD
    if bevel_inset_world is not None:
        BEVEL_INSET_WORLD = bevel_inset_world
    if bevel_drop_world is not None:
        BEVEL_DROP_WORLD = bevel_drop_world
    pipeline = bake_assets.apply_tile_pipeline_mode(tile_pipeline_modes.MODE3_TOP_EDGE_BEVEL)
    bake_assets.CONFIG["samples"] = samples
    bake_assets.CONFIG["ink_enabled"] = ink_enabled
    bake_assets.CONFIG["uv_inset_px"] = uv_inset_px
    if black_ink:
        bake_assets.CONFIG["ink_color"] = (0.0, 0.0, 0.0)
        bake_assets.CONFIG["ink_corner_color"] = (0.0, 0.0, 0.0)
    bake_assets.CONFIG["stroke_mode"] = "extra_stroke" if extra_stroke else "default"
    bake_assets.CONFIG["ink_thickness_position"] = "INSIDE"
    bake_assets.CONFIG["ink_thickness_noise_px"] = None
    bake_assets.CONFIG["ink_select_silhouette"] = True
    bake_assets.CONFIG["ink_select_border"] = True
    bake_assets.CONFIG["ink_select_crease"] = True
    bake_assets.CONFIG["ink_select_external_contour"] = True
    bake_assets.CONFIG["extra_stroke_px"] = 0
    bake_assets.CONFIG["extra_stroke_scope"] = "none"
    bake_assets.CONFIG["painter_line_mode"] = "lower_wall_edges_and_cracks" if painter_lines else "none"
    bake_assets.CONFIG["painter_line_width_px"] = max(0.0, float(painter_line_width_px)) if painter_lines else 0.0
    bake_assets.CONFIG["painter_line_alpha"] = max(0, min(255, int(painter_line_alpha))) if painter_lines else 0
    bake_assets.CONFIG["painter_line_wobble_px"] = max(0.0, float(painter_line_wobble_px)) if painter_lines else 0.0
    bake_assets.CONFIG["painter_cracks_enabled"] = bool(painter_cracks) if painter_lines else False
    bake_assets.CONFIG["painter_seed"] = int(painter_seed) if painter_lines else None
    bake_assets.CONFIG["rim_profile"] = "chipped" if chipped_rim else "regular"
    bake_assets.CONFIG["chip_count_per_edge"] = max(0, int(chip_count_per_edge)) if chipped_rim else 0
    bake_assets.CONFIG["chip_depth_world"] = max(0.0, float(chip_depth_world)) if chipped_rim else 0.0
    bake_assets.CONFIG["chip_width_ratio"] = max(0.0, float(chip_width_ratio)) if chipped_rim else 0.0
    bake_assets.CONFIG["chip_segments_per_edge"] = max(2, int(chip_segments_per_edge)) if chipped_rim else 0
    bake_assets.CONFIG["chip_seed"] = int(chip_seed) if chipped_rim else None
    if extra_stroke:
        bake_assets.CONFIG["ink_enabled"] = False
        bake_assets.CONFIG["uv_inset_px"] = 0.0
        bake_assets.CONFIG["ink_thickness_px"] = 0.0
        bake_assets.CONFIG["ink_wobble_px"] = 0.0
        bake_assets.CONFIG["ink_corner_wobble_px"] = 0.0
        bake_assets.CONFIG["ink_thickness_noise_px"] = 0.0
        bake_assets.CONFIG["ink_thickness_position"] = "ALPHA_OUTSIDE"
        bake_assets.CONFIG["ink_select_crease"] = False
        bake_assets.CONFIG["extra_stroke_px"] = max(0.0, float(extra_stroke_px))
        bake_assets.CONFIG["extra_stroke_scope"] = "alpha_silhouette_only_no_top_face"
    if painter_lines:
        bake_assets.CONFIG["ink_enabled"] = False
    bake_assets.CONFIG["tile_smooth_enabled"] = False
    out_dir.mkdir(parents=True, exist_ok=True)
    sidecar_dir = uv_dir / "sidecars"
    results: dict[str, dict] = {}

    for terrain in TERRAINS:
        for elevation in ELEVATIONS:
            key = f"{terrain}_e{elevation}"
            if only_keys is not None and key not in only_keys:
                continue
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
            if painter_lines:
                apply_painter_bevel_lines(
                    out_path,
                    elevation,
                    chipped_rim,
                    line_width_px=float(bake_assets.CONFIG["painter_line_width_px"]),
                    line_alpha=int(bake_assets.CONFIG["painter_line_alpha"]),
                    line_wobble_px=float(bake_assets.CONFIG["painter_line_wobble_px"]),
                    cracks_enabled=bool(bake_assets.CONFIG["painter_cracks_enabled"]),
                    crack_seed=int(bake_assets.CONFIG["painter_seed"]),
                )
            if extra_stroke and float(bake_assets.CONFIG.get("extra_stroke_px", 0)) > 0:
                bake_assets.apply_alpha_extra_stroke(
                    [out_path],
                    float(bake_assets.CONFIG["extra_stroke_px"]),
                )
            results[key] = {"uv": _rel(uv_path), "baked": _rel(out_path), "uv_sidecar": _rel(uv_sidecar_path)}

    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(build_manifest(pipeline), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    report = {
        "source_script": _rel(Path(__file__)),
        "pipeline": pipeline,
        "pipeline_mode": tile_pipeline_modes.MODE3_TOP_EDGE_BEVEL,
        "uv_dir": _rel(uv_dir),
        "out_dir": _rel(out_dir),
        "manifest": _rel(manifest_path),
        "samples": samples,
        "ink_enabled": ink_enabled,
        "uv_inset_px": bake_assets.CONFIG["uv_inset_px"],
        "black_ink": black_ink,
        "extra_stroke": extra_stroke,
        "extra_stroke_px": bake_assets.CONFIG.get("extra_stroke_px", 0),
        "painter_lines": painter_lines,
        "painter_line_mode": bake_assets.CONFIG.get("painter_line_mode", "none"),
        "painter_line_width_px": bake_assets.CONFIG.get("painter_line_width_px", 0.0),
        "painter_line_alpha": bake_assets.CONFIG.get("painter_line_alpha", 0),
        "painter_line_wobble_px": bake_assets.CONFIG.get("painter_line_wobble_px", 0.0),
        "painter_cracks_enabled": bake_assets.CONFIG.get("painter_cracks_enabled", False),
        "painter_seed": bake_assets.CONFIG.get("painter_seed", None),
        "only_keys": sorted(only_keys) if only_keys is not None else None,
        "mesh_contract": {
            "type": "explicit_top_edge_bevel_chipped" if chipped_rim else "explicit_top_edge_bevel",
            "bevel_inset_world": BEVEL_INSET_WORLD,
            "bevel_drop_world": BEVEL_DROP_WORLD,
            "rim_profile": bake_assets.CONFIG.get("rim_profile", "regular"),
            "chip_count_per_edge": bake_assets.CONFIG.get("chip_count_per_edge", 0),
            "chip_depth_world": bake_assets.CONFIG.get("chip_depth_world", 0.0),
            "chip_width_ratio": bake_assets.CONFIG.get("chip_width_ratio", 0.0),
            "chip_segments_per_edge": bake_assets.CONFIG.get("chip_segments_per_edge", 0),
            "chip_seed": bake_assets.CONFIG.get("chip_seed", None),
            "tile_smooth_enabled": bake_assets.CONFIG.get("tile_smooth_enabled"),
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
    parser.add_argument("--uv-dir", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=16)
    parser.add_argument("--ink", action="store_true")
    parser.add_argument("--bevel-inset-world", type=float, default=None)
    parser.add_argument("--bevel-drop-world", type=float, default=None)
    parser.add_argument("--uv-inset-px", type=float, default=0.0)
    parser.add_argument("--black-ink", action="store_true")
    parser.add_argument("--extra-stroke", action="store_true")
    parser.add_argument("--extra-stroke-px", type=float, default=DEFAULT_EXTRA_STROKE_PX)
    parser.add_argument("--painter-lines", action="store_true")
    parser.add_argument("--painter-line-width-px", type=float, default=0.55)
    parser.add_argument("--painter-line-alpha", type=int, default=92)
    parser.add_argument("--painter-line-wobble-px", type=float, default=0.45)
    parser.add_argument("--painter-cracks", action="store_true")
    parser.add_argument("--painter-seed", type=int, default=20260625)
    parser.add_argument("--only", action="append", default=[])
    parser.add_argument("--chipped-rim", action="store_true")
    parser.add_argument("--chip-count-per-edge", type=int, default=DEFAULT_CHIP_COUNT_PER_EDGE)
    parser.add_argument("--chip-depth-world", type=float, default=DEFAULT_CHIP_DEPTH_WORLD)
    parser.add_argument("--chip-width-ratio", type=float, default=DEFAULT_CHIP_WIDTH_RATIO)
    parser.add_argument("--chip-segments-per-edge", type=int, default=DEFAULT_CHIP_SEGMENTS_PER_EDGE)
    parser.add_argument("--chip-seed", type=int, default=DEFAULT_CHIP_SEED)
    args = parser.parse_args(argv)
    try:
        result = bake_set(
            args.uv_dir.resolve(),
            args.out_dir.resolve(),
            args.samples,
            args.ink,
            bevel_inset_world=args.bevel_inset_world,
            bevel_drop_world=args.bevel_drop_world,
            uv_inset_px=args.uv_inset_px,
            black_ink=args.black_ink,
            extra_stroke=args.extra_stroke,
            extra_stroke_px=args.extra_stroke_px,
            painter_lines=args.painter_lines,
            painter_line_width_px=args.painter_line_width_px,
            painter_line_alpha=args.painter_line_alpha,
            painter_line_wobble_px=args.painter_line_wobble_px,
            painter_cracks=args.painter_cracks,
            painter_seed=args.painter_seed,
            chipped_rim=args.chipped_rim,
            chip_count_per_edge=args.chip_count_per_edge,
            chip_depth_world=args.chip_depth_world,
            chip_width_ratio=args.chip_width_ratio,
            chip_segments_per_edge=args.chip_segments_per_edge,
            chip_seed=args.chip_seed,
            only_keys=set(args.only) if args.only else None,
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
