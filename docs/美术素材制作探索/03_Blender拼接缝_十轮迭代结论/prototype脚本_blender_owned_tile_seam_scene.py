from __future__ import annotations

import json
import math
import os
from pathlib import Path

import bpy
from mathutils import Euler, Vector


RUN_DIR = Path(__file__).resolve().parent
REPO_ROOT = Path(__file__).resolve().parents[4]

TEMPLATE_JSON = REPO_ROOT / "blender" / "templates" / "template_design_e0.json"
MANIFEST_JSON = REPO_ROOT / "inkmon" / "tools" / "tile_pipeline" / "assets" / "baked" / "manifest.json"
RAW_DIR = REPO_ROOT / "blender" / "textures" / "_candidates" / "single-stage-tile-6-variants-20260617-01" / "raw"

RAW_TILES = [
    ("grass_meadow", RAW_DIR / "tile_01_grass_meadow.png"),
    ("cracked_dry_earth", RAW_DIR / "tile_02_cracked_dry_earth.png"),
    ("mossy_flagstone", RAW_DIR / "tile_03_mossy_flagstone.png"),
    ("dirt_arena", RAW_DIR / "tile_04_dirt_arena.png"),
    ("pale_limestone", RAW_DIR / "tile_05_pale_limestone.png"),
    ("dark_forest_floor", RAW_DIR / "tile_06_dark_forest_floor.png"),
]

SIDE_TO_NEIGHBOR = {
    0: (1, 0),
    1: (0, 1),
    2: (-1, 1),
    3: (-1, 0),
    4: (0, -1),
    5: (1, -1),
}

MAP_CELLS = [
    (q, r)
    for q in range(-2, 3)
    for r in range(-2, 3)
    if max(abs(q), abs(r), abs(-q - r)) <= 2
]
CELL_TILE = {cell: (idx * 5 + 2) % len(RAW_TILES) for idx, cell in enumerate(sorted(MAP_CELLS))}

BACKGROUND_RGBA = (78 / 255.0, 81 / 255.0, 73 / 255.0, 1.0)
SEAM_PARAMS = {
    "draw_mode": "blender_mesh_render",
    "dark_width_world": 0.018,
    "dark_color": [0.045, 0.039, 0.028, 1.0],
    "highlight_width_world": 0.006,
    "highlight_offset_world": 0.014,
    "highlight_color": [0.68, 0.60, 0.38, 1.0],
    "z_lift": 0.006,
    "side_wall_policy": "exterior_only",
}


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def rel(path: Path) -> str:
    return path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()


def axial_center(q: int, r: int, edge: float) -> tuple[float, float]:
    return 1.5 * q * edge, math.sqrt(3.0) * (r + q * 0.5) * edge


def hex_corner(side: int, radius: float) -> Vector:
    angle = math.radians(60.0 * side)
    return Vector((math.cos(angle) * radius, math.sin(angle) * radius, 0.0))


def uv_of(layout: dict, px: float, py: float) -> tuple[float, float]:
    cw, ch = layout["canvas"]
    return px / float(cw), 1.0 - py / float(ch)


def image_material(name: str, path: Path):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (1, 1, 1, 1)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(path))
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Strength"].default_value = 1.0
    nt.links.new(tex.outputs["Color"], emit.inputs["Color"])
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return mat


def flat_material(name: str, color: list[float]):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = tuple(color)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = tuple(color)
    bsdf.inputs["Alpha"].default_value = color[3]
    bsdf.inputs["Roughness"].default_value = 0.95
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat.blend_method = "BLEND"
    mat.use_screen_refraction = False
    return mat


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for datablock_list in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(datablock_list):
            if item.users == 0:
                datablock_list.remove(item)


def make_tile_mesh(
    name: str,
    center: tuple[float, float],
    raw_material,
    layout: dict,
    radius: float,
    depth: float,
    side_faces: list[int],
):
    top = [hex_corner(i, radius) for i in range(6)]
    bottom = [Vector((v.x, v.y, -depth)) for v in top]
    verts = [(v.x, v.y, v.z) for v in top + bottom]
    faces = [tuple(range(6))]
    face_tags = ["top"]
    for side in side_faces:
        nxt = (side + 1) % 6
        faces.append((side, nxt, nxt + 6, side + 6))
        face_tags.append(f"wall_{side}")

    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    top_poly = layout["faces"]["top"]["polygon_px"]

    for poly, tag in zip(mesh.polygons, face_tags):
        if tag == "top":
            for loop_index in poly.loop_indices:
                vi = mesh.loops[loop_index].vertex_index
                uv_layer.data[loop_index].uv = uv_of(layout, *top_poly[vi])
        else:
            quad = layout["faces"][tag]["quad_px"]
            for local_i, loop_index in enumerate(poly.loop_indices):
                uv_layer.data[loop_index].uv = uv_of(layout, *quad[local_i])

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = (center[0], center[1], 0.0)
    obj.data.materials.append(raw_material)
    return obj


def make_strip_mesh(name: str, points: list[Vector], material) -> None:
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata([(p.x, p.y, p.z) for p in points], [], [(0, 1, 2, 3)])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material)


def ground_projector(manifest: dict):
    pitch = math.radians(float(manifest["pitch_deg"]))
    yaw = math.radians(float(manifest["yaw_deg"]))
    cy = math.cos(yaw)
    sy = math.sin(yaw)
    sp = math.sin(pitch)

    def project(vec: Vector) -> Vector:
        return Vector((vec.x * cy + vec.y * -sy, vec.x * sy * sp + vec.y * cy * sp))

    return project


def make_seams(manifest: dict, dark_mat, highlight_mat) -> list[dict]:
    cells = set(MAP_CELLS)
    radius = float(manifest["hex_edge_world"])
    project = ground_projector(manifest)
    screen_light = Vector((-0.52, -0.85)).normalized()
    dark_half = SEAM_PARAMS["dark_width_world"] * 0.5
    hi_half = SEAM_PARAMS["highlight_width_world"] * 0.5
    z = SEAM_PARAMS["z_lift"]
    edges = []

    for q, r in MAP_CELLS:
        cx, cy = axial_center(q, r, radius)
        center = Vector((cx, cy, 0.0))
        for side, delta in SIDE_TO_NEIGHBOR.items():
            other = (q + delta[0], r + delta[1])
            if other not in cells or (q, r) > other:
                continue
            a = center + hex_corner(side, radius)
            b = center + hex_corner((side + 1) % 6, radius)
            edge_vec = (b - a).normalized()
            normals = [Vector((-edge_vec.y, edge_vec.x, 0.0)), Vector((edge_vec.y, -edge_vec.x, 0.0))]
            lit_normal = max(normals, key=lambda n: project(n).normalized().dot(screen_light))

            dark_pts = [
                Vector((a.x + lit_normal.x * dark_half, a.y + lit_normal.y * dark_half, z)),
                Vector((b.x + lit_normal.x * dark_half, b.y + lit_normal.y * dark_half, z)),
                Vector((b.x - lit_normal.x * dark_half, b.y - lit_normal.y * dark_half, z)),
                Vector((a.x - lit_normal.x * dark_half, a.y - lit_normal.y * dark_half, z)),
            ]
            make_strip_mesh(f"seam_dark_{q}_{r}_{side}", dark_pts, dark_mat)

            off = SEAM_PARAMS["highlight_offset_world"]
            hi_pts = [
                Vector((a.x + lit_normal.x * (off + hi_half), a.y + lit_normal.y * (off + hi_half), z + 0.002)),
                Vector((b.x + lit_normal.x * (off + hi_half), b.y + lit_normal.y * (off + hi_half), z + 0.002)),
                Vector((b.x + lit_normal.x * (off - hi_half), b.y + lit_normal.y * (off - hi_half), z + 0.002)),
                Vector((a.x + lit_normal.x * (off - hi_half), a.y + lit_normal.y * (off - hi_half), z + 0.002)),
            ]
            make_strip_mesh(f"seam_highlight_{q}_{r}_{side}", hi_pts, highlight_mat)
            edges.append(
                {
                    "cell_a": [q, r],
                    "cell_b": [other[0], other[1]],
                    "side": side,
                    "a_world": [round(a.x, 4), round(a.y, 4), 0.0],
                    "b_world": [round(b.x, 4), round(b.y, 4), 0.0],
                }
            )
    return edges


def setup_camera_and_render(manifest: dict) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 64
    scene.render.resolution_x = 2400
    scene.render.resolution_y = 1572
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"

    world = bpy.data.worlds.new("CandidateWorld")
    world.color = BACKGROUND_RGBA[:3]
    scene.world = world

    cam_data = bpy.data.cameras.new("CandidateCamera")
    cam = bpy.data.objects.new("CandidateCamera", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    pitch = math.radians(float(manifest["pitch_deg"]))
    yaw = math.radians(float(manifest["yaw_deg"]))
    cam.rotation_euler = Euler((math.radians(90.0) - pitch, 0.0, yaw), "XYZ")
    cam.data.type = "ORTHO"
    scene.camera = cam

    depsgraph = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in scene.objects:
        if obj.type != "MESH":
            continue
        obj_eval = obj.evaluated_get(depsgraph)
        for corner in obj_eval.bound_box:
            points.append(obj_eval.matrix_world @ Vector(corner))
    rot = cam.rotation_euler.to_matrix()
    right = rot @ Vector((1.0, 0.0, 0.0))
    up = rot @ Vector((0.0, 1.0, 0.0))
    view_dir = rot @ Vector((0.0, 0.0, -1.0))
    xs = [p.dot(right) for p in points]
    ys = [p.dot(up) for p in points]
    mid_x = (min(xs) + max(xs)) * 0.5
    mid_y = (min(ys) + max(ys)) * 0.5
    center = right * mid_x + up * mid_y
    x_range = max(xs) - min(xs)
    y_range = max(ys) - min(ys)
    aspect = scene.render.resolution_x / scene.render.resolution_y
    cam.data.ortho_scale = max(y_range, x_range / aspect) * 1.10
    cam.location = center - view_dir * 24.0


def build_scene(with_seam: bool) -> dict:
    clear_scene()
    layout = read_json(TEMPLATE_JSON)
    manifest = read_json(MANIFEST_JSON)
    radius = float(manifest["hex_edge_world"])
    depth = float(manifest["thickness_world"])
    cells = set(MAP_CELLS)

    materials = [image_material(f"mat_{label}", path) for label, path in RAW_TILES]
    for q, r in MAP_CELLS:
        center = axial_center(q, r, radius)
        tile_idx = CELL_TILE[(q, r)]
        exterior_visible_sides = []
        for side in (3, 4, 5):
            dq, dr = SIDE_TO_NEIGHBOR[side]
            if (q + dq, r + dr) not in cells:
                exterior_visible_sides.append(side)
        make_tile_mesh(
            f"tile_{q}_{r}_{RAW_TILES[tile_idx][0]}",
            center,
            materials[tile_idx],
            layout,
            radius,
            depth,
            exterior_visible_sides,
        )

    dark_mat = flat_material("mat_seam_dark", SEAM_PARAMS["dark_color"])
    highlight_mat = flat_material("mat_seam_highlight", SEAM_PARAMS["highlight_color"])
    edges = make_seams(manifest, dark_mat, highlight_mat) if with_seam else []
    setup_camera_and_render(manifest)
    return {"edges": edges}


def render(path: Path) -> None:
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    RUN_DIR.mkdir(parents=True, exist_ok=True)
    for _label, path in RAW_TILES:
        if not path.exists():
            raise FileNotFoundError(path)

    build_scene(with_seam=False)
    render(RUN_DIR / "map_no_seam_baseline.png")

    seam_info = build_scene(with_seam=True)
    render(RUN_DIR / "map_blender_seam_preview.png")

    metadata = {
        "renderer": "Blender",
        "draw_mode": "blender_mesh_render",
        "raw_usage": "raw images are face texture sources only; final map preview is Blender render",
        "side_wall_policy": SEAM_PARAMS["side_wall_policy"],
        "params": SEAM_PARAMS,
        "cell_count": len(MAP_CELLS),
        "shared_edge_count": len(seam_info["edges"]),
        "map_cells": [list(c) for c in MAP_CELLS],
        "edges": seam_info["edges"],
        "outputs": {
            "baseline": rel(RUN_DIR / "map_no_seam_baseline.png"),
            "seam_preview": rel(RUN_DIR / "map_blender_seam_preview.png"),
        },
    }
    (RUN_DIR / "seam_geometry.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
