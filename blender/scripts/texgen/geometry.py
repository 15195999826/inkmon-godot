# texgen.geometry — 生图管线几何单一真相（线稿模板 / warp / QC / bake UV 四方共享）
#
# 角度、px_per_hex_edge、hex_orientation、厚度等全部读 assets/baked/manifest.json，
# 本模块不写第二份相机/比例常量；模板画布与 UV 排布常量是生图模板系统自己的契约，
# 只在此处定义一次（make_templates 写 sidecar JSON，warp/QC 读 sidecar，bake 直接 import）。
#
# 坐标系约定：
#   - Blender 世界 (x, y, z)，Z 朝上；Godot 平面 (gx, gy)（y 向下）= (x, -y)
#   - 屏幕/图像像素 y 向下；投影公式与 InkMonRender2DIsoProjection.ground_basis 同源：
#       screen_x =  x·cosψ + y·sinψ
#       screen_y = -[(-x·sinψ + y·cosψ)·sin(pitch) + z·cos(pitch)]   （y 向下为正）
#
# 纯 stdlib（math/json/os），Blender 内嵌 Python 可直接 import。

import json
import math
import os

# ---------------------------------------------------------------- manifest

_REPO_ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
MANIFEST_PATH = os.path.join(_REPO_ROOT, "inkmon美术探索", "fable-圆角-v1", "assets", "baked", "manifest.json")


def repo_root() -> str:
    return _REPO_ROOT


def load_manifest(path: "str | None" = None) -> dict:
    with open(path or MANIFEST_PATH, "r", encoding="utf-8") as f:
        m = json.load(f)
    if m.get("hex_orientation") != "flat_top":
        raise ValueError("texgen 只支持 flat_top（manifest hex_orientation=%r）" % m.get("hex_orientation"))
    return m


# ---------------------------------------------------------------- 模板系统契约常量（单处定义）

DESIGN_CANVAS = (1024, 1024)   # 3D 全貌版画布（gpt-image-2 方形档）
DESIGN_MARGIN = 64.0

UV_CANVAS = (1536, 1024)       # UV 展开版画布（gpt-image-2 横版档；e2 unfold net 宽 ≈1199px，1024 方画布装不下）
UV_PX_PER_UNIT = 256.0         # UV 贴图纹素密度（= 2× baked px_per_unit，顶面网格流同密度）
UV_MARGIN = 32.0
UV_LAYOUT_VERSION = "net_v2"   # 纸模 unfold net（侧壁铰接 hex 边）；旧行排布局贴图按画布尺寸硬隔离

DUAL_CANVAS = (1536, 1024)     # 双联版（gpt-image-2 横版档）：左 3D 全貌右 UV 展开
DUAL_PANEL_MARGIN = 48.0

ATLAS_CANVAS = (1024, 1024)    # atlas 标准版：top hex + continuous wall strip
ATLAS_PX_PER_UNIT = 256.0
ATLAS_MARGIN = 96.0

GRID_CANVAS = (1536, 1536)     # 俯视网格版：中心 + 一环共 7 格
GRID_PX_PER_UNIT = 256.0       # 与 UV_PX_PER_UNIT 一致 → 种子顶面零缩放贴入

GRID_RING1 = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]  # flat-top axial 一环

SQRT3 = math.sqrt(3.0)


# ---------------------------------------------------------------- 投影

def projector(manifest: dict):
    """返回 project(x, y, z) -> (sx, sy)（屏幕单位 = 世界单位，y 向下，原点 = 世界原点投影）。"""
    pitch = math.radians(float(manifest["pitch_deg"]))
    yaw = math.radians(float(manifest["yaw_deg"]))
    cy, sy_ = math.cos(yaw), math.sin(yaw)
    sp, cp = math.sin(pitch), math.cos(pitch)

    def project(x: float, y: float, z: float = 0.0):
        sx = x * cy + y * sy_
        sy = -((-x * sy_ + y * cy) * sp + z * cp)
        return (sx, sy)

    return project


def hex_corner(i: int, edge: float = 1.0):
    """flat-top hex 角点 i（Blender XY 平面，逆时针，角点在 60°·i）。"""
    a = math.radians(60.0 * i)
    return (math.cos(a) * edge, math.sin(a) * edge)


def tile_depth(manifest: dict, elevation: int) -> float:
    return float(manifest["thickness_world"]) + elevation * float(manifest["elevation_step_world"])


def visible_walls(manifest: dict) -> list:
    """冻结相机下可见侧壁下标（壁 i = 角点 i→i+1），按屏幕投影 x 从左到右排序。"""
    pitch = math.radians(float(manifest["pitch_deg"]))
    yaw = math.radians(float(manifest["yaw_deg"]))
    # view_dir = Rz(yaw)·Rx(90°-pitch)·(0,0,-1)，其 XY 分量；to_cam = -view_dir
    alpha = math.radians(90.0) - pitch
    vx = -math.sin(yaw) * math.sin(alpha)
    vy = math.cos(yaw) * math.sin(alpha)
    to_cam = (-vx, -vy)
    project = projector(manifest)
    edge = float(manifest["hex_edge_world"])
    out = []
    for i in range(6):
        na = math.radians(60.0 * i + 30.0)
        n = (math.cos(na), math.sin(na))
        if n[0] * to_cam[0] + n[1] * to_cam[1] > 1e-9:
            ax, ay = hex_corner(i, edge)
            bx, by = hex_corner(i + 1, edge)
            mid_sx = (project(ax, ay, 0.0)[0] + project(bx, by, 0.0)[0]) * 0.5
            out.append((mid_sx, i))
    out.sort()
    return [i for (_, i) in out]


def wall_corners_lr(manifest, wall: int):
    """壁 wall 的左右角点（从壁外侧朝壁看，z 朝上时的左→右），返回 ((lx,ly),(rx,ry))。
    角点按 manifest 的 hex_edge_world 缩放（manifest=None 时退化为单位 edge）。"""
    edge = float(manifest["hex_edge_world"]) if manifest else 1.0
    na = math.radians(60.0 * wall + 30.0)
    # 朝壁看（视线 = -normal）时屏幕右方向 = (-sinθ, cosθ)
    right = (-math.sin(na), math.cos(na))
    a = hex_corner(wall, edge)
    b = hex_corner(wall + 1, edge)
    d = (b[0] - a[0], b[1] - a[1])
    if d[0] * right[0] + d[1] * right[1] >= 0.0:
        return a, b
    return b, a


# ---------------------------------------------------------------- 面几何（世界 → 各画布像素）

def _faces_world(manifest: dict, elevation: int):
    """tile 的 top + 可见壁面世界几何（角点按 manifest 的 hex_edge_world 缩放）。
    top: 6 角点 (x,y,0)；wall_i: 参数化 p(t,d) = lerp(left,right,t) - (0,0,d·depth)。"""
    depth = tile_depth(manifest, elevation)
    edge = float(manifest["hex_edge_world"])
    walls = {}
    for i in visible_walls(manifest):
        left, right = wall_corners_lr(manifest, i)
        walls[i] = {"left": left, "right": right, "depth": depth}
    top = [hex_corner(i, edge) for i in range(6)]
    return top, walls


def design_layout(manifest: dict, elevation: int) -> dict:
    """3D 全貌版：各面顶点的画布像素坐标。scale 按 e2 包围盒统一（三档同比例）。"""
    project = projector(manifest)
    cw, ch = DESIGN_CANVAS

    def tile_bbox(elev):
        pts = []
        depth = tile_depth(manifest, elev)
        edge = float(manifest["hex_edge_world"])
        for i in range(6):
            x, y = hex_corner(i, edge)
            pts.append(project(x, y, 0.0))
            pts.append(project(x, y, -depth))
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        return min(xs), min(ys), max(xs), max(ys)

    bx0, by0, bx1, by1 = tile_bbox(2)  # 统一 scale 基准 = 最高档
    scale = min((cw - 2 * DESIGN_MARGIN) / (bx1 - bx0), (ch - 2 * DESIGN_MARGIN) / (by1 - by0))
    ex0, ey0, ex1, ey1 = tile_bbox(elevation)
    ox = cw / 2.0 - (ex0 + ex1) / 2.0 * scale
    oy = ch / 2.0 - (ey0 + ey1) / 2.0 * scale

    def to_px(world_xyz):
        sx, sy = project(*world_xyz)
        return (sx * scale + ox, sy * scale + oy)

    top, walls = _faces_world(manifest, elevation)
    faces = {"top": {"polygon_px": [to_px((x, y, 0.0)) for (x, y) in top]}}
    for i, w in walls.items():
        lx, ly = w["left"]
        rx, ry = w["right"]
        d = w["depth"]
        faces["wall_%d" % i] = {
            # quad 顺序：左上(t0,d0) 右上(t1,d0) 右下(t1,d1) 左下(t0,d1)
            "quad_px": [
                to_px((lx, ly, 0.0)), to_px((rx, ry, 0.0)),
                to_px((rx, ry, -d)), to_px((lx, ly, -d)),
            ],
        }
    return {
        "template": "design",
        "elevation": elevation,
        "canvas": [cw, ch],
        "scale_px_per_unit": scale,
        "origin_px": [ox, oy],
        "faces": faces,
        "manifest": _manifest_excerpt(manifest),
    }


def uv_layout(manifest: dict, elevation: int) -> dict:
    """UV 展开版（纸模 unfold net）：顶面 hex（正俯视朝向：世界 +y = 图像上）+ 可见壁 quad
    直接铰接在各自 hex 边上、沿边外法线展开 depth；整个 net 按 bbox 居中画布。
    壁 quad 参数化与 design_layout 一致：左上(t0,d0) 右上(t1,d0) 右下(t1,d1) 左下(t0,d1)。"""
    cw, ch = UV_CANVAS
    s = UV_PX_PER_UNIT
    edge = float(manifest["hex_edge_world"])
    depth = tile_depth(manifest, elevation)
    order = visible_walls(manifest)

    def img(x, y):
        return (x * s, -y * s)  # 图像 y 向下 → 世界 y 取负（先以世界原点为锚，后整体平移居中）

    top_poly = [img(*hex_corner(i, edge)) for i in range(6)]
    wall_quads = {}
    for i in order:
        left, right = wall_corners_lr(manifest, i)
        na = math.radians(60.0 * i + 30.0)
        nx, ny = math.cos(na) * depth, math.sin(na) * depth  # 壁外法线 × depth = 展开位移
        wall_quads[i] = [
            img(*left), img(*right),
            img(right[0] + nx, right[1] + ny), img(left[0] + nx, left[1] + ny),
        ]

    all_pts = top_poly + [p for q in wall_quads.values() for p in q]
    xs = [p[0] for p in all_pts]
    ys = [p[1] for p in all_pts]
    if (max(xs) - min(xs)) > cw - 2 * UV_MARGIN or (max(ys) - min(ys)) > ch - 2 * UV_MARGIN:
        raise ValueError("UV unfold net 超出画布：bbox %.0f×%.0f vs 可用 %.0f×%.0f（调 UV_CANVAS/UV_PX_PER_UNIT）"
                         % (max(xs) - min(xs), max(ys) - min(ys), cw - 2 * UV_MARGIN, ch - 2 * UV_MARGIN))
    ox = cw / 2.0 - (min(xs) + max(xs)) / 2.0
    oy = ch / 2.0 - (min(ys) + max(ys)) / 2.0

    def shift(p):
        return (p[0] + ox, p[1] + oy)

    faces = {"top": {"polygon_px": [shift(p) for p in top_poly], "center_px": [ox, oy], "px_per_unit": s}}
    for i in order:
        faces["wall_%d" % i] = {"quad_px": [shift(p) for p in wall_quads[i]]}
    return {
        "template": "uv",
        "layout": UV_LAYOUT_VERSION,
        "elevation": elevation,
        "canvas": [cw, ch],
        "px_per_unit": s,
        "faces": faces,
        "wall_order": order,
        "manifest": _manifest_excerpt(manifest),
    }


def dual_layout(manifest: dict, elevation: int) -> dict:
    """双联版：左 panel = 3D 全貌（重 fit），右 panel = UV net bbox 等比放大居中。"""
    cw, ch = DUAL_CANVAS
    panel_w = cw / 2.0

    # 左：design_layout 已含统一 scale，整体再缩放平移进左 panel
    base = design_layout(manifest, elevation)
    src_w, src_h = DESIGN_CANVAS
    k = min((panel_w - 2 * DUAL_PANEL_MARGIN) / src_w, (ch - 2 * DUAL_PANEL_MARGIN) / src_h)
    lox = (panel_w - src_w * k) / 2.0
    loy = (ch - src_h * k) / 2.0

    def remap_l(p):
        return (p[0] * k + lox, p[1] * k + loy)

    # 右：按实际 UV net bbox 等比缩进右 panel。
    # 旧版按整个 1536x1024 UV 画布缩放，右 panel 有大量空白，提取时分辨率损失过大。
    uv = uv_layout(manifest, elevation)
    uv_pts = []
    for f in uv["faces"].values():
        uv_pts.extend(f.get("polygon_px") or f["quad_px"])
    min_x = min(p[0] for p in uv_pts)
    max_x = max(p[0] for p in uv_pts)
    min_y = min(p[1] for p in uv_pts)
    max_y = max(p[1] for p in uv_pts)
    net_w = max_x - min_x
    net_h = max_y - min_y
    k2 = min((panel_w - 2 * DUAL_PANEL_MARGIN) / net_w, (ch - 2 * DUAL_PANEL_MARGIN) / net_h)
    rox = panel_w + (panel_w - net_w * k2) / 2.0 - min_x * k2
    roy = (ch - net_h * k2) / 2.0 - min_y * k2

    def remap_r(p):
        return (p[0] * k2 + rox, p[1] * k2 + roy)

    faces = {}
    for name, f in base["faces"].items():
        key = "design_" + name
        if "polygon_px" in f:
            faces[key] = {"polygon_px": [remap_l(p) for p in f["polygon_px"]]}
        else:
            faces[key] = {"quad_px": [remap_l(p) for p in f["quad_px"]]}
    for name, f in uv["faces"].items():
        key = "uv_" + name
        if "polygon_px" in f:
            faces[key] = {"polygon_px": [remap_r(p) for p in f["polygon_px"]]}
        else:
            faces[key] = {"quad_px": [remap_r(p) for p in f["quad_px"]]}
    return {
        "template": "dual",
        "elevation": elevation,
        "canvas": [cw, ch],
        "divider_x": panel_w,
        "design_scale": base["scale_px_per_unit"] * k,
        "uv_px_per_unit": UV_PX_PER_UNIT * k2,
        "uv_net_bbox": [min_x, min_y, max_x, max_y],
        "faces": faces,
        "wall_order": uv["wall_order"],
        "manifest": _manifest_excerpt(manifest),
    }


def atlas_layout(manifest: dict, elevation: int) -> dict:
    """Blender-friendly atlas：顶面 hex + 连续侧壁 strip。

    右侧生图不再生成 paper-net wall panels，而是给 Blender 采样的 material source：
    top 是正俯视 hex albedo；wall_strip 是按 visible wall_order 横向连续展开的侧壁材质。
    """
    cw, ch = ATLAS_CANVAS
    s = ATLAS_PX_PER_UNIT
    edge = float(manifest["hex_edge_world"])
    depth = tile_depth(manifest, elevation)
    order = visible_walls(manifest)
    top_center = (cw * 0.5, 310.0)

    def top_img(x, y):
        return (top_center[0] + x * s, top_center[1] - y * s)

    top_poly = [top_img(*hex_corner(i, edge)) for i in range(6)]
    strip_w = len(order) * edge * s
    strip_h = depth * s
    strip_x0 = (cw - strip_w) * 0.5
    strip_y0 = 730.0
    if strip_y0 + strip_h > ch - ATLAS_MARGIN * 0.25:
        strip_y0 = ch - strip_h - ATLAS_MARGIN * 0.5
    strip = [
        (strip_x0, strip_y0),
        (strip_x0 + strip_w, strip_y0),
        (strip_x0 + strip_w, strip_y0 + strip_h),
        (strip_x0, strip_y0 + strip_h),
    ]
    segments = {}
    for idx, wall in enumerate(order):
        x0 = strip_x0 + idx * edge * s
        x1 = x0 + edge * s
        segments["wall_%d" % wall] = {
            "range_px": [x0, x1],
            "quad_px": [(x0, strip_y0), (x1, strip_y0), (x1, strip_y0 + strip_h), (x0, strip_y0 + strip_h)],
        }

    return {
        "template": "atlas",
        "layout": "top_hex_wall_strip_v1",
        "elevation": elevation,
        "canvas": [cw, ch],
        "px_per_unit": s,
        "faces": {
            "top": {"polygon_px": top_poly, "center_px": [top_center[0], top_center[1]], "px_per_unit": s},
            "wall_strip": {"quad_px": strip, "px_per_unit": s},
        },
        "wall_order": order,
        "wall_segments": segments,
        "manifest": _manifest_excerpt(manifest),
    }


def dual_atlas_layout(manifest: dict, elevation: int) -> dict:
    """双联 atlas 版：左 panel = 3D target，右 panel = top hex + continuous wall strip。"""
    cw, ch = DUAL_CANVAS
    panel_w = cw / 2.0

    base = design_layout(manifest, elevation)
    src_w, src_h = DESIGN_CANVAS
    k = min((panel_w - 2 * DUAL_PANEL_MARGIN) / src_w, (ch - 2 * DUAL_PANEL_MARGIN) / src_h)
    lox = (panel_w - src_w * k) / 2.0
    loy = (ch - src_h * k) / 2.0

    def remap_l(p):
        return (p[0] * k + lox, p[1] * k + loy)

    atlas = atlas_layout(manifest, elevation)
    atlas_pts = []
    for f in atlas["faces"].values():
        atlas_pts.extend(f.get("polygon_px") or f["quad_px"])
    min_x = min(p[0] for p in atlas_pts)
    max_x = max(p[0] for p in atlas_pts)
    min_y = min(p[1] for p in atlas_pts)
    max_y = max(p[1] for p in atlas_pts)
    atlas_w = max_x - min_x
    atlas_h = max_y - min_y
    k2 = min((panel_w - 2 * DUAL_PANEL_MARGIN) / atlas_w, (ch - 2 * DUAL_PANEL_MARGIN) / atlas_h)
    rox = panel_w + (panel_w - atlas_w * k2) / 2.0 - min_x * k2
    roy = (ch - atlas_h * k2) / 2.0 - min_y * k2

    def remap_r(p):
        return (p[0] * k2 + rox, p[1] * k2 + roy)

    faces = {}
    for name, f in base["faces"].items():
        key = "design_" + name
        if "polygon_px" in f:
            faces[key] = {"polygon_px": [remap_l(p) for p in f["polygon_px"]]}
        else:
            faces[key] = {"quad_px": [remap_l(p) for p in f["quad_px"]]}
    for name, f in atlas["faces"].items():
        key = "atlas_" + name
        if "polygon_px" in f:
            faces[key] = {"polygon_px": [remap_r(p) for p in f["polygon_px"]]}
        else:
            faces[key] = {"quad_px": [remap_r(p) for p in f["quad_px"]]}

    segments = {}
    for name, seg in atlas["wall_segments"].items():
        segments[name] = {
            "range_px": [seg["range_px"][0] * k2 + rox, seg["range_px"][1] * k2 + rox],
            "quad_px": [remap_r(p) for p in seg["quad_px"]],
        }

    return {
        "template": "dual_atlas",
        "elevation": elevation,
        "canvas": [cw, ch],
        "divider_x": panel_w,
        "design_scale": base["scale_px_per_unit"] * k,
        "atlas_px_per_unit": ATLAS_PX_PER_UNIT * k2,
        "atlas_bbox": [min_x, min_y, max_x, max_y],
        "faces": faces,
        "wall_order": atlas["wall_order"],
        "wall_segments": segments,
        "manifest": _manifest_excerpt(manifest),
    }


def grid_layout(manifest: dict) -> dict:
    """俯视网格版：正俯视中心 + 一环 7 格 hex 轮廓（正俯视 = UV 本身，零 warp）。
    cell 像素中心公式与 Godot flat-top axial 同源：center = edge·(1.5q, √3(r+q/2))。"""
    cw, ch = GRID_CANVAS
    s = GRID_PX_PER_UNIT
    edge = float(manifest["hex_edge_world"])
    ox, oy = cw / 2.0, ch / 2.0
    cells = {}
    for (q, r) in [(0, 0)] + GRID_RING1:
        ccx = ox + 1.5 * q * edge * s
        ccy = oy + SQRT3 * (r + q / 2.0) * edge * s
        poly = []
        for i in range(6):
            x, y = hex_corner(i, edge)
            poly.append((ccx + x * s, ccy - y * s))  # 与 uv top island 同朝向（世界 +y = 图像上）
        cells["%d_%d" % (q, r)] = {"center_px": [ccx, ccy], "polygon_px": poly}
    return {
        "template": "grid",
        "canvas": [cw, ch],
        "px_per_unit": s,
        "cells": cells,
        "manifest": _manifest_excerpt(manifest),
    }


def _manifest_excerpt(manifest: dict) -> dict:
    return {
        "pitch_deg": float(manifest["pitch_deg"]),
        "yaw_deg": float(manifest["yaw_deg"]),
        "hex_orientation": manifest["hex_orientation"],
        "px_per_hex_edge": float(manifest["px_per_hex_edge"]),
        "hex_edge_world": float(manifest["hex_edge_world"]),
        "thickness_world": float(manifest["thickness_world"]),
        "elevation_step_world": float(manifest["elevation_step_world"]),
    }


# ---------------------------------------------------------------- warp 对应关系（design ↔ UV 的逐面控制点）

def face_correspondences(design: dict, uv: dict) -> list:
    """逐面仿射控制点：[(face_name, src_tri_px, dst_tri_px, dst_mask_poly_px)]。
    src = design 画布像素，dst = uv 画布像素；每面 3 个对应点唯一确定仿射。"""
    out = []
    # 顶面：取角点 0/2/4（非退化三角形）
    src_p = design["faces"]["top"]["polygon_px"]
    dst_p = uv["faces"]["top"]["polygon_px"]
    out.append(("top", [src_p[0], src_p[2], src_p[4]], [dst_p[0], dst_p[2], dst_p[4]], dst_p))
    for name in design["faces"]:
        if not name.startswith("wall_"):
            continue
        sq = design["faces"][name]["quad_px"]
        dq = uv["faces"][name]["quad_px"]
        # quad 顺序一致（左上/右上/右下/左下）→ 取前 3 点
        out.append((name, sq[:3], dq[:3], dq))
    return out
