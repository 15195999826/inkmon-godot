# bake_assets.py — Inkmon 标准地块美术管线：Blender 资产工厂
#
# 参数化生成 hex 棱柱地块（草/土/石/水 × 海拔 0-2）与装饰模型（针叶树/石头堆/灌木），
# 固定正交相机 + 统一日光，逐资产烘焙带 alpha PNG 并写 manifest.json（角度/比例单一真相）。
#
# 用法：
#   交互（MCP）:  exec(open(r"blender/scripts/bake_assets.py").read()); bake_all()
#   命令行:       blender --background --python blender/scripts/bake_assets.py
#
# 几何对齐契约（与 Godot inkmon/presentation/render2d/core/iso_projection.gd 同源）：
#   - Godot 平面坐标 (px, py)（y 向下）↔ Blender 世界 (px, -py, 0)（Z 朝上）
#   - 相机 rotation_euler = (90° - pitch, 0, yaw)，正交；世界原点投到画布正中心 = 锚点
#   - hex 朝向 = flat-top（概念图为准）：角点在 Blender XY 平面角度 = 60°·i；
#     Godot 端 flat-top axial 布局 center = hex_edge · (1.5·q, √3·(r + q/2))
#   - 海拔不进模型：所有 tile 顶面恒在 z=0，海拔差只体现为侧壁更深；Godot 端用
#     height_to_screen(elevation*elevation_step) 抬升锚点

import bpy
import bmesh
import math
import json
import os
from mathutils import Euler, Vector

# ============================================================ 参数（单一真相，改这里 → 重烘 → Godot 自动跟随）

CONFIG = {
    # 视角（adr/0008 用户拍板：真等轴 35.26° / yaw -15°）
    "pitch_deg": 35.26,
    "yaw_deg": -15.0,
    # 日光：画面左上 → 右下，仰角约 50°（azimuth 为绕世界 Z 的旋转，-45° ≈ 画面对角）
    "sun_elevation_deg": 50.0,
    "sun_azimuth_deg": -45.0,
    "sun_energy": 4.0,
    "sun_color": (1.0, 0.96, 0.88),
    "sun_softness_deg": 8.0,
    "ambient_color": (0.55, 0.60, 0.66),
    "ambient_strength": 0.35,
    # 几何（世界单位；hex_edge = 外接圆半径 = 1.0）
    "hex_edge": 1.0,
    "thickness": 0.55,          # 海拔 0 的棱柱深度（顶面 z=0，向下）
    "elevation_step": 0.5,      # 每级海拔追加的侧壁深度
    "water_recess": 0.12,       # 水面相对地表的下沉
    "bevel_width": 0.06,
    "bevel_segments": 3,
    # 手绘墨线（Freestyle）
    "ink_enabled": True,
    "ink_color": (0.16, 0.12, 0.08),   # 暖墨褐（线性空间）
    "ink_thickness_px": 3.2,
    "ink_wobble_px": 1.5,              # 手绘抖动幅度
    # 出图
    "px_per_unit": 128,         # 1 世界单位 = 128 px → px_per_hex_edge = 128
    "canvas_px": 512,
    "samples": 64,
    # 输出（相对 blend 文件所在 blender/ 目录）
    "output_rel": "//../inkmon/tools/tile_pipeline/assets/baked",
}

TERRAINS = ["grass", "dirt", "stone", "water"]
ELEVATIONS = [0, 1, 2]
## 每地形的贴图变体数（噪声偏移采样，打破拼装重复感）
TERRAIN_VARIANTS = {"grass": 3, "dirt": 2, "stone": 2, "water": 2}


def _srgb(hexstr):
    """'#RRGGBB' sRGB → Blender 线性 RGB tuple。"""
    h = hexstr.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


# 概念图配色：苔藓橄榄绿顶面 + 米色石板 + 棕土/砌石侧壁 + 灰蓝水带，低饱和暖灰
PALETTE = {
    "grass_top": _srgb("#8A8C50"),
    "grass_side": _srgb("#6E5F46"),
    "dirt_top": _srgb("#8A7A52"),
    "dirt_side": _srgb("#685A43"),
    "stone_top": _srgb("#A39B81"),
    "stone_side": _srgb("#7E7665"),
    "water_top": _srgb("#7593A4"),
    "water_side": _srgb("#56697A"),
    "pine_leaf_a": _srgb("#3A4C2E"),
    "pine_leaf_b": _srgb("#56683C"),
    "trunk": _srgb("#6B4E36"),
    "bush": _srgb("#677747"),
    "rock": _srgb("#7B7466"),
}


# ============================================================ 场景 / 相机 / 光

def clear_assets():
    """删掉所有非基建对象（保留 camera/sun/catcher 之外全删，孤儿数据顺带清）。"""
    keep = {"BakeCamera", "BakeSun", "ShadowCatcher"}
    for obj in list(bpy.data.objects):
        if obj.name not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)


def setup_stage():
    """相机 + 日光 + 世界环境 + 渲染设置（幂等，可重复调）。"""
    scene = bpy.context.scene
    cfg = CONFIG

    # 相机：正交，rot = (90-pitch, 0, yaw)，沿视线后退使原点处于画布中心
    cam = bpy.data.objects.get("BakeCamera")
    if cam is None:
        cam_data = bpy.data.cameras.new("BakeCamera")
        cam = bpy.data.objects.new("BakeCamera", cam_data)
        scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = cfg["canvas_px"] / cfg["px_per_unit"]
    cam.data.clip_start = 0.1
    cam.data.clip_end = 100.0
    cam.rotation_euler = Euler((
        math.radians(90.0 - cfg["pitch_deg"]),
        0.0,
        math.radians(cfg["yaw_deg"]),
    ), "XYZ")
    view_dir = cam.rotation_euler.to_matrix() @ Vector((0.0, 0.0, -1.0))
    cam.location = -view_dir * 20.0
    scene.camera = cam

    # 日光：画面左上 → 右下
    sun = bpy.data.objects.get("BakeSun")
    if sun is None:
        sun_data = bpy.data.lights.new("BakeSun", type="SUN")
        sun = bpy.data.objects.new("BakeSun", sun_data)
        scene.collection.objects.link(sun)
    sun.data.energy = cfg["sun_energy"]
    sun.data.color = cfg["sun_color"]
    sun.data.angle = math.radians(cfg["sun_softness_deg"])
    sun.rotation_euler = Euler((
        math.radians(90.0 - cfg["sun_elevation_deg"]),
        0.0,
        math.radians(cfg["sun_azimuth_deg"]),
    ), "XYZ")
    sun.location = Vector((4.0, 4.0, 8.0))

    # 世界环境光（冷灰补光，与暖日光互补）
    world = bpy.data.worlds.get("BakeWorld")
    if world is None:
        world = bpy.data.worlds.new("BakeWorld")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    bg = next((n for n in nt.nodes if n.type == "BACKGROUND"), None)
    if bg is None:
        bg = nt.nodes.new("ShaderNodeBackground")
    out = next((n for n in nt.nodes if n.type == "OUTPUT_WORLD"), None)
    if out is None:
        out = nt.nodes.new("ShaderNodeOutputWorld")
    if not any(l.to_node == out for l in nt.links):
        nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    bg.inputs["Color"].default_value = (*cfg["ambient_color"], 1.0)
    bg.inputs["Strength"].default_value = cfg["ambient_strength"]

    # 渲染：Cycles GPU + 透明片 + Standard 色彩（保配色不被 Filmic 洗灰）
    scene.render.engine = "CYCLES"
    scene.cycles.samples = cfg["samples"]
    scene.cycles.use_denoising = True
    try:
        bpy.context.preferences.addons["cycles"].preferences.compute_device_type = "OPTIX"
        scene.cycles.device = "GPU"
    except Exception:
        pass
    # Freestyle 手绘墨线：物体轮廓 + crease，Perlin 抖动模拟手绘笔触
    scene.render.use_freestyle = cfg["ink_enabled"]
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = 1.0
    vl = bpy.context.view_layer
    vl.use_freestyle = cfg["ink_enabled"]
    fs = vl.freestyle_settings
    fs.crease_angle = math.radians(120.0)
    if not fs.linesets:
        fs.linesets.new("ink")
    ls = fs.linesets[0]
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = True
    ls.select_external_contour = True
    style = ls.linestyle
    style.color = cfg["ink_color"]
    style.thickness = cfg["ink_thickness_px"]
    style.thickness_position = "INSIDE"
    mod = next((m for m in style.geometry_modifiers if m.type == "PERLIN_NOISE_2D"), None)
    if mod is None:
        mod = style.geometry_modifiers.new("wobble", "PERLIN_NOISE_2D")
    mod.amplitude = cfg["ink_wobble_px"]
    mod.frequency = 12.0
    mod.octaves = 2
    tmod = next((m for m in style.thickness_modifiers if m.type == "NOISE"), None)
    if tmod is None:
        tmod = style.thickness_modifiers.new("taper", "NOISE")
    tmod.amplitude = cfg["ink_thickness_px"] * 0.5
    tmod.period = 18.0

    scene.render.film_transparent = True
    scene.render.resolution_x = cfg["canvas_px"]
    scene.render.resolution_y = cfg["canvas_px"]
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"


def ensure_shadow_catcher(visible: bool):
    """装饰烘焙用接地影捕捉平面（透明片上只留影子）。"""
    catcher = bpy.data.objects.get("ShadowCatcher")
    if catcher is None:
        mesh = bpy.data.meshes.new("ShadowCatcherMesh")
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=6.0)
        bm.to_mesh(mesh)
        bm.free()
        catcher = bpy.data.objects.new("ShadowCatcher", mesh)
        bpy.context.scene.collection.objects.link(catcher)
        catcher.is_shadow_catcher = True
    catcher.hide_render = not visible
    catcher.hide_viewport = not visible


# ============================================================ 材质（手绘质感：每地形专属 shader + bump 微凹凸；墨线由 Freestyle 全局加）

def _sock(node, ident):
    """Mix 等多态节点按 identifier 取 socket（按 name 取会撞到 float 版 A/B）。"""
    for s in node.inputs:
        if s.identifier == ident:
            return s
    return node.inputs[ident]


def _new_mat(name, roughness=0.92):
    mat = bpy.data.materials.get(name)
    if mat is not None:
        bpy.data.materials.remove(mat)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = roughness
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat, nt, bsdf


def _obj_coords(nt, offset=(0.0, 0.0, 0.0)):
    """物体空间坐标；offset = 变体采样偏移（同一套噪声换一片区域 = 新变体）。"""
    tex = nt.nodes.new("ShaderNodeTexCoord")
    if offset == (0.0, 0.0, 0.0):
        return tex.outputs["Object"]
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Location"].default_value = offset
    nt.links.new(tex.outputs["Object"], mapping.inputs["Vector"])
    return mapping.outputs["Vector"]


def _variant_offset(variant: int):
    return (variant * 7.31, variant * 4.17, variant * 2.93)


def _mix_color(nt, fac_socket_or_value, a, b):
    """a/b 可以是 RGB tuple 或输出 socket；fac 同理。返回输出 socket。"""
    node = nt.nodes.new("ShaderNodeMix")
    node.data_type = "RGBA"
    if isinstance(fac_socket_or_value, (int, float)):
        _sock(node, "Factor_Float").default_value = fac_socket_or_value
    else:
        nt.links.new(fac_socket_or_value, _sock(node, "Factor_Float"))
    for ident, val in (("A_Color", a), ("B_Color", b)):
        if isinstance(val, tuple):
            _sock(node, ident).default_value = (*val, 1.0)
        else:
            nt.links.new(val, _sock(node, ident))
    return node.outputs[2] if node.outputs[2].identifier == "Result_Color" else \
        next(o for o in node.outputs if o.identifier == "Result_Color")


def _map_range(nt, value_socket, from_min, from_max, to_min=0.0, to_max=1.0):
    node = nt.nodes.new("ShaderNodeMapRange")
    node.clamp = True
    node.inputs["From Min"].default_value = from_min
    node.inputs["From Max"].default_value = from_max
    node.inputs["To Min"].default_value = to_min
    node.inputs["To Max"].default_value = to_max
    nt.links.new(value_socket, node.inputs["Value"])
    return node.outputs["Result"]


def _noise(nt, coords, scale, detail=3.0, distortion=0.0):
    node = nt.nodes.new("ShaderNodeTexNoise")
    node.inputs["Scale"].default_value = scale
    node.inputs["Detail"].default_value = detail
    node.inputs["Distortion"].default_value = distortion
    nt.links.new(coords, node.inputs["Vector"])
    return node.outputs["Fac"]


def _shift(rgb, value=1.0, sat=1.0):
    """同色系深浅变体（在 sRGB→linear 之后直接乘，足够用）。"""
    r, g, b = (c * value for c in rgb)
    if sat != 1.0:
        gray = (r + g + b) / 3.0
        r, g, b = (gray + (c - gray) * sat for c in (r, g, b))
    return (min(r, 1.0), min(g, 1.0), min(b, 1.0))


def _bump(nt, bsdf, height_socket, strength=0.15):
    node = nt.nodes.new("ShaderNodeBump")
    node.inputs["Strength"].default_value = strength
    nt.links.new(height_socket, node.inputs["Height"])
    nt.links.new(node.outputs["Normal"], bsdf.inputs["Normal"])


def _top_side_mix(nt, top_color_socket, side_color_socket):
    """法线 Z → 顶/侧分色（bevel 过渡自然渐变）。"""
    geom = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geom.outputs["Normal"], sep.inputs["Vector"])
    fac = _map_range(nt, sep.outputs["Z"], 0.35, 0.75)
    return _mix_color(nt, fac, side_color_socket, top_color_socket)


def _masonry_side(nt, coords, base_rgb, rim_rgb=None, rim_noise=False):
    """侧壁砌石：沿 z 的层带 mortar 暗缝 + 块面深浅抖动（只依赖 z → 六个朝向都不拉伸）。
    rim_rgb = 顶缘染色（草唇/苔藓爬石）；rim_noise=True 时苔斑式断续。"""
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coords, sep.inputs["Vector"])
    bands_vec = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(sep.outputs["Z"], bands_vec.inputs["X"])
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.inputs["Scale"].default_value = 1.5
    wave.inputs["Distortion"].default_value = 2.4
    wave.inputs["Detail"].default_value = 2.0
    nt.links.new(bands_vec.outputs["Vector"], wave.inputs["Vector"])
    mortar = _map_range(nt, wave.outputs["Fac"], 0.06, 0.20, 1.0, 0.0)  # 窄暗缝
    jitter = _noise(nt, coords, 2.4, detail=3.0)
    block_fac = _map_range(nt, jitter, 0.3, 0.7, 0.0, 0.5)
    blocks = _mix_color(nt, block_fac, base_rgb, _shift(base_rgb, 0.80))
    color = _mix_color(nt, mortar, blocks, _shift(base_rgb, 0.58))
    if rim_rgb is not None:
        # 注意：变体偏移过的 coords 不能用来定位"顶缘"——必须用未偏移的物体 z
        geo_sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        raw = nt.nodes.new("ShaderNodeTexCoord")
        nt.links.new(raw.outputs["Object"], geo_sep.inputs["Vector"])
        rim_fac = _map_range(nt, geo_sep.outputs["Z"], -0.24, -0.05, 0.0, 0.9)
        if rim_noise:
            gate = _map_range(nt, _noise(nt, coords, 5.0, detail=3.0), 0.42, 0.62, 0.0, 1.0)
            mul = nt.nodes.new("ShaderNodeMath")
            mul.operation = "MULTIPLY"
            nt.links.new(rim_fac, mul.inputs[0])
            nt.links.new(gate, mul.inputs[1])
            rim_fac = mul.outputs["Value"]
        color = _mix_color(nt, rim_fac, color, rim_rgb)
    return color


def _tile_material_grass_like(name, top_rgb, side_rgb, speckle=True, variant=0, rim_noise=False):
    """草/土：色块斑驳 + 草簇/砾石噪点 + 砌石侧壁（顶缘草唇）。"""
    mat, nt, bsdf = _new_mat(name)
    co = _obj_coords(nt, _variant_offset(variant))
    # 大块斑驳（painterly 色域起伏）
    mottle = _noise(nt, co, 2.6, detail=4.0, distortion=0.4)
    mottle_fac = _map_range(nt, mottle, 0.32, 0.68, 0.0, 0.55)
    top = _mix_color(nt, mottle_fac, _shift(top_rgb, 1.10, 1.05), _shift(top_rgb, 0.82))
    if speckle:
        # 草簇/碎石噪点：高频窄带提亮 + 压暗各一层
        sp = _noise(nt, co, 22.0, detail=2.0)
        light_fac = _map_range(nt, sp, 0.60, 0.66, 0.0, 0.6)
        top = _mix_color(nt, light_fac, top, _shift(top_rgb, 1.28, 1.1))
        dark_fac = _map_range(nt, sp, 0.40, 0.34, 0.0, 0.5)
        top = _mix_color(nt, dark_fac, top, _shift(top_rgb, 0.62))
    side = _masonry_side(nt, co, side_rgb, rim_rgb=_shift(top_rgb, 0.92), rim_noise=rim_noise)
    nt.links.new(_top_side_mix(nt, top, side), bsdf.inputs["Base Color"])
    bump_h = _noise(nt, co, 16.0, detail=4.0)
    _bump(nt, bsdf, bump_h, 0.18)
    return mat


def _tile_material_stone(name, top_rgb, side_rgb, variant=0):
    """石板：voronoi 裂缝暗线 + 石板色块抖动 + 砌石侧壁（概念图的米色碎石板）。"""
    mat, nt, bsdf = _new_mat(name)
    co = _obj_coords(nt, _variant_offset(variant))
    vor_edge = nt.nodes.new("ShaderNodeTexVoronoi")
    vor_edge.feature = "DISTANCE_TO_EDGE"
    vor_edge.inputs["Scale"].default_value = 3.0
    nt.links.new(co, vor_edge.inputs["Vector"])
    crack = _map_range(nt, vor_edge.outputs["Distance"], 0.02, 0.07, 1.0, 0.0)
    vor_cell = nt.nodes.new("ShaderNodeTexVoronoi")
    vor_cell.inputs["Scale"].default_value = 3.0
    nt.links.new(co, vor_cell.inputs["Vector"])
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(vor_cell.outputs["Color"], sep.inputs["Color"])
    plate_fac = _map_range(nt, sep.outputs["Red"], 0.0, 1.0, 0.0, 0.45)
    plates = _mix_color(nt, plate_fac, _shift(top_rgb, 1.08), _shift(top_rgb, 0.80, 0.9))
    mottle = _noise(nt, co, 7.0, detail=3.0)
    mottle_fac = _map_range(nt, mottle, 0.35, 0.65, 0.0, 0.3)
    plates = _mix_color(nt, mottle_fac, plates, _shift(top_rgb, 0.9))
    top = _mix_color(nt, crack, plates, _shift(top_rgb, 0.40, 0.8))
    # 苔藓爬石：石壁顶缘噪声断续的苔绿
    side = _masonry_side(nt, co, side_rgb, rim_rgb=_shift(PALETTE["grass_top"], 0.82), rim_noise=True)
    nt.links.new(_top_side_mix(nt, top, side), bsdf.inputs["Base Color"])
    crack_bump = _map_range(nt, vor_edge.outputs["Distance"], 0.0, 0.08, 0.0, 1.0)
    _bump(nt, bsdf, crack_bump, 0.35)
    return mat


def _tile_material_water(name, top_rgb, side_rgb, variant=0):
    """水：明暗波带 + 高光涟漪细线（手绘水面的"板块感"），侧壁深一档。"""
    mat, nt, bsdf = _new_mat(name, roughness=0.35)
    co = _obj_coords(nt, _variant_offset(variant))
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.inputs["Scale"].default_value = 2.0
    wave.inputs["Distortion"].default_value = 2.6
    wave.inputs["Detail"].default_value = 2.0
    nt.links.new(co, wave.inputs["Vector"])
    fac = _map_range(nt, wave.outputs["Fac"], 0.1, 0.9, 0.0, 0.6)
    top = _mix_color(nt, fac, _shift(top_rgb, 1.08), _shift(top_rgb, 0.74))
    # 涟漪高光细线：voronoi 边缘 → 窄亮线（手绘水的"碎板"反光）
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 4.5
    nt.links.new(co, vor.inputs["Vector"])
    edge_fac = _map_range(nt, vor.outputs["Distance"], 0.015, 0.05, 0.7, 0.0)
    top = _mix_color(nt, edge_fac, top, _shift(top_rgb, 1.38, 0.8))
    side = _mix_color(nt, 0.0, side_rgb, side_rgb)
    nt.links.new(_top_side_mix(nt, top, side), bsdf.inputs["Base Color"])
    _bump(nt, bsdf, _noise(nt, co, 5.0, detail=2.0), 0.06)
    return mat


def _decor_material(name, rgb, mottle_amount=0.5, bump_strength=0.2, bump_scale=12.0):
    mat, nt, bsdf = _new_mat(name)
    co = _obj_coords(nt)
    mottle = _noise(nt, co, 5.0, detail=3.0)
    fac = _map_range(nt, mottle, 0.3, 0.7, 0.0, mottle_amount)
    color = _mix_color(nt, fac, _shift(rgb, 1.10), _shift(rgb, 0.74))
    nt.links.new(color, bsdf.inputs["Base Color"])
    _bump(nt, bsdf, _noise(nt, co, bump_scale, detail=4.0), bump_strength)
    return mat


def build_materials(variant: int = 0):
    """variant 只影响 tile 噪声采样区（装饰单变体即可）；材质名带变体号防互删。"""
    suffix = "_v%d" % variant
    mats = {
        "grass": _tile_material_grass_like("mat_tile_grass" + suffix, PALETTE["grass_top"], PALETTE["grass_side"], variant=variant),
        "dirt": _tile_material_grass_like("mat_tile_dirt" + suffix, PALETTE["dirt_top"], PALETTE["dirt_side"], variant=variant, rim_noise=True),
        "stone": _tile_material_stone("mat_tile_stone" + suffix, PALETTE["stone_top"], PALETTE["stone_side"], variant=variant),
        "water": _tile_material_water("mat_tile_water" + suffix, PALETTE["water_top"], PALETTE["water_side"], variant=variant),
        "pine_a": _decor_material("mat_pine_a", PALETTE["pine_leaf_a"], 0.6, 0.3, 18.0),
        "pine_b": _decor_material("mat_pine_b", PALETTE["pine_leaf_b"], 0.6, 0.3, 18.0),
        "trunk": _decor_material("mat_trunk", PALETTE["trunk"], 0.4, 0.25, 9.0),
        "bush": _decor_material("mat_bush", PALETTE["bush"], 0.55, 0.3, 14.0),
        "rock": _decor_material("mat_rock", PALETTE["rock"], 0.85, 0.4, 7.0),
    }
    return mats


# ============================================================ 建模

def _add_bevel(obj, width=None, segments=None):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = CONFIG["bevel_width"] if width is None else width
    mod.segments = CONFIG["bevel_segments"] if segments is None else segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(40.0)


def _smooth(obj, angle_deg=40.0):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.data.set_sharp_from_angle(angle=math.radians(angle_deg))


def build_hex_tile(terrain: str, elevation: int, mats) -> bpy.types.Object:
    """hex 棱柱：顶面 z=0（水面下沉 water_recess），深度 = thickness + elevation*step。"""
    cfg = CONFIG
    r = cfg["hex_edge"]
    top_z = -cfg["water_recess"] if terrain == "water" else 0.0
    depth = cfg["thickness"] + elevation * cfg["elevation_step"]

    bm = bmesh.new()
    verts = []
    for i in range(6):
        a = math.radians(60.0 * i)  # flat-top：角点在 0°/60°/...，左右出尖、上下平边
        verts.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, top_z)))
    top_face = bm.faces.new(verts)
    ret = bmesh.ops.extrude_face_region(bm, geom=[top_face])
    new_verts = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=new_verts, vec=(0.0, 0.0, -(depth - (0.0 - top_z))))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    mesh = bpy.data.meshes.new("tile_%s_e%d" % (terrain, elevation))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("tile_%s_e%d" % (terrain, elevation), mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mats[terrain])
    _add_bevel(obj)
    _smooth(obj)
    return obj


def _box(name, size, location, rot_z_deg, mat):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.scale = size
    obj.location = location
    obj.rotation_euler = Euler((0.0, 0.0, math.radians(rot_z_deg)), "XYZ")
    obj.data.materials.append(mat)
    return obj


def _join(objs, name):
    ctx = bpy.context
    for o in ctx.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    ctx.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    joined = ctx.view_layer.objects.active
    joined.name = name
    return joined


def _frustum(name, w_bottom, w_top, height, z_base, rot_z_deg, mat):
    """方台（底大顶小的方块）：方块感针叶树的层单元。底面中心在 (0,0,z_base)。"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        s = (w_top if v.co.z > 0.0 else w_bottom) * 0.5
        v.co.x *= s * 2.0
        v.co.y *= s * 2.0
        v.co.z = (v.co.z + 0.5) * height
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = (0.0, 0.0, z_base)
    obj.rotation_euler = Euler((0.0, 0.0, math.radians(rot_z_deg)), "XYZ")
    obj.data.materials.append(mat)
    return obj


def build_pine(mats, tall=False) -> bpy.types.Object:
    """方块感针叶树：方柱树干 + 渐缩方台冠层（frustum 收分），层间错转。锚点 = 落地中心 z=0。"""
    # girth 控横向、h 控纵向 —— 概念图树是"高瘦深绿"，加高别加肥。
    # 画布约束：总高 H ≤ canvas/2/px_per_unit/cos(pitch) ≈ 2.45 世界单位
    girth = 1.0 if not tall else 1.15
    h = 1.30 if not tall else 1.22
    parts = []
    parts.append(_box("trunk", (0.14, 0.14, 0.56), (0.0, 0.0, 0.27), 0.0, mats["trunk"]))
    layer_specs = [
        # (底宽, 顶宽, 层高, 错转角)
        (0.68, 0.38, 0.56, -8.0),
        (0.50, 0.26, 0.50, 14.0),
        (0.33, 0.06, 0.46, -4.0),
    ]
    if tall:
        layer_specs.insert(0, (0.80, 0.52, 0.48, 8.0))
    z = 0.44
    for i, (wb, wt, lh, rot) in enumerate(layer_specs):
        mat = mats["pine_a"] if i % 2 == 0 else mats["pine_b"]
        parts.append(_frustum("leaf%d" % i, wb * girth, wt * girth, lh * h, z, rot, mat))
        z += lh * h * 0.72
    obj = _join(parts, "decor_pine_tall" if tall else "decor_pine")
    _add_bevel(obj, width=0.035, segments=2)
    _smooth(obj)
    return obj


def build_rocks(mats) -> bpy.types.Object:
    """石头堆：3 块错位斜方块，大 bevel 磨圆。"""
    specs = [
        ((0.42, 0.36, 0.30), (-0.12, 0.06, 0.12), 18.0),
        ((0.30, 0.27, 0.22), (0.22, -0.10, 0.09), -25.0),
        ((0.20, 0.18, 0.16), (0.02, -0.24, 0.06), 40.0),
    ]
    parts = [
        _box("rock%d" % i, size, loc, rot, mats["rock"])
        for i, (size, loc, rot) in enumerate(specs)
    ]
    obj = _join(parts, "decor_rocks")
    _add_bevel(obj, width=0.08, segments=3)
    _smooth(obj, angle_deg=60.0)
    return obj


def build_bush(mats) -> bpy.types.Object:
    """圆冠灌木：低分段 icosphere 压扁，faceted 低多边形质感。"""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.5)
    mesh = bpy.data.meshes.new("decor_bush")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("decor_bush", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.scale = (0.78, 0.78, 0.55)
    obj.location = (0.0, 0.0, 0.24)
    obj.data.materials.append(mats["bush"])
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    _add_bevel(obj, width=0.05, segments=2)
    return obj


DECOR_BUILDERS = {
    "decor_pine": lambda mats: build_pine(mats, tall=False),
    "decor_pine_tall": lambda mats: build_pine(mats, tall=True),
    "decor_rocks": build_rocks,
    "decor_bush": build_bush,
}


# ============================================================ 烘焙

def _output_dir() -> str:
    path = bpy.path.abspath(CONFIG["output_rel"])
    os.makedirs(path, exist_ok=True)
    return path


def render_to(filepath: str):
    bpy.context.scene.render.filepath = filepath
    bpy.ops.render.render(write_still=True)


def bake_all(subset=None):
    """全量烘焙：tiles（每地形多变体）+ decors + manifest.json。subset=资产名列表时只烘子集。"""
    setup_stage()
    out_dir = _output_dir()
    cfg = CONFIG
    center = cfg["canvas_px"] / 2.0

    assets = {}

    # tiles：variant 外层（材质重建一次服务全 elevation）
    variant_mats = {}
    for terrain in TERRAINS:
        n_var = TERRAIN_VARIANTS.get(terrain, 1)
        for elev in ELEVATIONS:
            name = "tile_%s_e%d" % (terrain, elev)
            variant_files = ["%s_v%d.png" % (name, v) for v in range(n_var)]
            assets[name] = {
                "file": variant_files[0],
                "variants": variant_files,
                "kind": "tile",
                "terrain": terrain,
                "elevation": elev,
                "anchor_px": [center, center],
                "size_px": [cfg["canvas_px"], cfg["canvas_px"]],
            }
            if subset is not None and name not in subset:
                continue
            for v, fname in enumerate(variant_files):
                if v not in variant_mats:
                    variant_mats[v] = build_materials(variant=v)
                clear_assets()
                ensure_shadow_catcher(False)
                build_hex_tile(terrain, elev, variant_mats[v])
                render_to(os.path.join(out_dir, fname))
                print("baked", fname)

    # decors（带接地影，单变体；重建材质 —— tile 变体循环会反复删建同名装饰材质，旧引用必死）
    mats = build_materials()
    for name, builder in DECOR_BUILDERS.items():
        assets[name] = {
            "file": name + ".png",
            "variants": [name + ".png"],
            "kind": "decor",
            "anchor_px": [center, center],
            "size_px": [cfg["canvas_px"], cfg["canvas_px"]],
        }
        if subset is not None and name not in subset:
            continue
        clear_assets()
        ensure_shadow_catcher(True)
        builder(mats)
        render_to(os.path.join(out_dir, name + ".png"))
        print("baked", name)

    ensure_shadow_catcher(False)

    manifest = {
        "comment": "tile 美术管线单一真相：Blender bake_assets.py 写，Godot 读。anchor = 资产原点"
                   "（tile=顶面中心@海拔0平面 / decor=落地点）在图中的像素位置；海拔抬升由 Godot 按"
                   " elevation*elevation_step_world*cos(pitch) 计算。",
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
        "assets": assets,
    }
    manifest_path = os.path.join(out_dir, "manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print("manifest ->", manifest_path)
    return manifest_path


def build_showcase():
    """检视用：把全部资产摆一排（不烘焙，只为 test.blend 可视检查）。"""
    setup_stage()
    mats = build_materials()
    clear_assets()
    ensure_shadow_catcher(False)
    x = 0.0
    for terrain in TERRAINS:
        for elev in ELEVATIONS:
            obj = build_hex_tile(terrain, elev, mats)
            obj.location.x = x
            x += 2.2
    x = 0.0
    for name, builder in DECOR_BUILDERS.items():
        obj = builder(mats)
        obj.location = (x, -3.0, 0.0)
        x += 2.2


if __name__ == "__main__":
    bake_all()
