# texgen.make_templates — 线稿模板生成：四版本 SVG + PNG 底图 + sidecar JSON
#
# 四版本（CONTEXT.md）：3D 全貌 / UV 展开 / 双联 / 俯视网格。几何全部来自 texgen.geometry
# （角度/比例读 baked manifest.json）。SVG = 人审视图；PNG = gpt-image-2 底图（同几何 PIL 直绘）；
# sidecar JSON = warp / QC 的运行时契约（多边形像素坐标、scale、manifest 摘录）。
#
# 用法（repo 根）：
#   python blender/scripts/texgen/make_templates.py            # 全套（e0/e1/e2 × 3 + grid）
#   python blender/scripts/texgen/make_templates.py -e 0       # 只 e0
#   python blender/scripts/texgen/make_templates.py -o <dir>   # 自定义输出目录（默认 blender/templates/standard-templates/）
#   python blender/scripts/texgen/make_templates.py --yaw-deg 0 -o blender/templates/yawzero-templates

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from texgen import geometry as G

from PIL import Image, ImageDraw

LINE_COLOR = (40, 40, 40)
LINE_W = 4
UV_FILL_COLOR = (246, 246, 242)
UV_HINGE_W = 3
ATLAS_GUIDE_COLOR = (178, 178, 170)
ATLAS_GUIDE_W = 2


# ---------------------------------------------------------------- 绘制原语（SVG 文本 + PIL 同步出）

class Sheet:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.svg = []
        self.img = Image.new("RGB", (w, h), (255, 255, 255))
        self.draw = ImageDraw.Draw(self.img)

    def fill_polygon(self, pts, fill=UV_FILL_COLOR):
        d = "M " + " L ".join("%.2f %.2f" % (x, y) for x, y in pts) + " Z"
        self.svg.append('<path d="%s" fill="rgb%s" stroke="none"/>' % (d, fill))
        self.draw.polygon([tuple(p) for p in pts], fill=fill)

    def polygon(self, pts, width=LINE_W):
        d = "M " + " L ".join("%.2f %.2f" % (x, y) for x, y in pts) + " Z"
        self.svg.append('<path d="%s" fill="none" stroke="rgb%s" stroke-width="%d" stroke-linejoin="round"/>' % (d, LINE_COLOR, width))
        self.draw.polygon([tuple(p) for p in pts], outline=LINE_COLOR, width=width)

    def line(self, a, b, width=LINE_W):
        self.svg.append('<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="rgb%s" stroke-width="%d" stroke-linecap="round"/>' % (a[0], a[1], b[0], b[1], LINE_COLOR, width))
        self.draw.line([tuple(a), tuple(b)], fill=LINE_COLOR, width=width)

    def guide_polygon(self, pts, width=ATLAS_GUIDE_W):
        d = "M " + " L ".join("%.2f %.2f" % (x, y) for x, y in pts) + " Z"
        self.svg.append('<path d="%s" fill="none" stroke="rgb%s" stroke-width="%d" stroke-linejoin="round"/>' % (d, ATLAS_GUIDE_COLOR, width))
        self.draw.polygon([tuple(p) for p in pts], outline=ATLAS_GUIDE_COLOR, width=width)

    def save(self, path_stem: str):
        svg_path = path_stem + ".svg"
        png_path = path_stem + ".png"
        with open(svg_path, "w", encoding="utf-8") as f:
            f.write('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n' % (self.w, self.h, self.w, self.h))
            f.write('<rect width="%d" height="%d" fill="white"/>\n' % (self.w, self.h))
            f.write("\n".join(self.svg))
            f.write("\n</svg>\n")
        self.img.save(png_path)
        return [svg_path, png_path]


# ---------------------------------------------------------------- 四版本

def draw_design(layout: dict) -> Sheet:
    sheet = Sheet(*layout["canvas"])
    _draw_design_edges(sheet, layout)
    return sheet


def _face_poly(face: dict) -> list:
    return face.get("polygon_px") or face["quad_px"]


def _wall_names(layout: dict, prefix: str = "") -> list:
    faces = layout["faces"]
    if "wall_order" in layout:
        return ["%swall_%d" % (prefix, int(i)) for i in layout["wall_order"]]

    names = [name for name in faces.keys() if name.startswith(prefix + "wall_")]
    return sorted(names, key=lambda n: int(n.rsplit("_", 1)[1]))


def _design_polys(layout: dict, prefix: str = "") -> list:
    faces = layout["faces"]
    polys = [_face_poly(faces[prefix + "top"])]
    for name in _wall_names(layout, prefix):
        polys.append(_face_poly(faces[name]))
    return polys


def _draw_design_edges(sheet: Sheet, layout: dict, prefix: str = ""):
    """3D template: draw each geometric edge once.

    Drawing each face polygon separately double-strokes shared top/wall and
    wall/wall edges, which biases image generation toward dirty duplicate seams.
    """
    outer, hinges = _uv_edges(_design_polys(layout, prefix))
    for a, b in outer + hinges:
        sheet.line(a, b, width=LINE_W)


def _edge_key(a, b):
    pa = (round(a[0], 1), round(a[1], 1))
    pb = (round(b[0], 1), round(b[1], 1))
    return (pa, pb) if pa <= pb else (pb, pa)


def _uv_polys(layout: dict, prefix: str) -> list:
    faces = layout["faces"]
    polys = [_face_poly(faces[prefix + "top"])]
    for i in layout["wall_order"]:
        polys.append(_face_poly(faces["%swall_%d" % (prefix, i)]))
    return polys


def _uv_edges(polys: list) -> "tuple[list, list]":
    seen = {}
    edges = {}
    for poly in polys:
        for i, a in enumerate(poly):
            b = poly[(i + 1) % len(poly)]
            key = _edge_key(a, b)
            seen[key] = seen.get(key, 0) + 1
            edges[key] = (a, b)
    outer = [edges[k] for k, count in seen.items() if count == 1]
    hinges = [edges[k] for k, count in seen.items() if count > 1]
    return outer, hinges


def draw_uv(layout: dict, prefix: str = "", sheet: "Sheet | None" = None) -> Sheet:
    """unfold net 生产参考图：浅底连通纸模 + 单次外轮廓 + 铰接线。

    不把每个 face 单独描闭合边，避免模型把 top / side wall 理解成几张分离贴纸。
    """
    if sheet is None:
        sheet = Sheet(*layout["canvas"])
    polys = _uv_polys(layout, prefix)
    for poly in polys:
        sheet.fill_polygon(poly)
    outer, hinges = _uv_edges(polys)
    for a, b in outer:
        sheet.line(a, b, width=LINE_W)
    for a, b in hinges:
        sheet.line(a, b, width=UV_HINGE_W)
    return sheet


def draw_dual(layout: dict) -> Sheet:
    sheet = Sheet(*layout["canvas"])
    dx = layout["divider_x"]
    sheet.line((dx, 0), (dx, layout["canvas"][1]), width=2)
    _draw_design_edges(sheet, layout, prefix="design_")
    draw_uv(layout, prefix="uv_", sheet=sheet)
    return sheet


def draw_atlas(layout: dict, prefix: str = "", sheet: "Sheet | None" = None) -> Sheet:
    """atlas 参考图：浅灰 guide，右侧内容应被 AI 当 material source 而非结构线。"""
    if sheet is None:
        sheet = Sheet(*layout["canvas"])
    faces = layout["faces"]
    sheet.guide_polygon(_face_poly(faces[prefix + "top"]))
    sheet.guide_polygon(_face_poly(faces[prefix + "wall_strip"]))
    return sheet


def draw_dual_atlas(layout: dict) -> Sheet:
    sheet = Sheet(*layout["canvas"])
    dx = layout["divider_x"]
    sheet.line((dx, 0), (dx, layout["canvas"][1]), width=2)
    _draw_design_edges(sheet, layout, prefix="design_")
    draw_atlas(layout, prefix="atlas_", sheet=sheet)
    return sheet


def draw_grid(layout: dict) -> Sheet:
    sheet = Sheet(*layout["canvas"])
    for cell in layout["cells"].values():
        sheet.polygon(cell["polygon_px"])
    return sheet


# ---------------------------------------------------------------- 入口

def generate(out_dir: str, elevations, pitch_deg=None, yaw_deg=None) -> list:
    manifest = G.load_manifest()
    if pitch_deg is not None:
        manifest["pitch_deg"] = float(pitch_deg)
    if yaw_deg is not None:
        manifest["yaw_deg"] = float(yaw_deg)
    os.makedirs(out_dir, exist_ok=True)
    written = []

    def emit(stem: str, layout: dict, sheet: Sheet):
        paths = sheet.save(os.path.join(out_dir, stem))
        sidecar = os.path.join(out_dir, stem + ".json")
        with open(sidecar, "w", encoding="utf-8") as f:
            json.dump(layout, f, ensure_ascii=False, indent=2)
        written.extend(paths + [sidecar])

    for e in elevations:
        d = G.design_layout(manifest, e)
        emit("template_design_e%d" % e, d, draw_design(d))
        u = G.uv_layout(manifest, e)
        emit("template_uv_e%d" % e, u, draw_uv(u))
        du = G.dual_layout(manifest, e)
        emit("template_dual_e%d" % e, du, draw_dual(du))
        a = G.atlas_layout(manifest, e)
        emit("template_atlas_e%d" % e, a, draw_atlas(a))
        da = G.dual_atlas_layout(manifest, e)
        emit("template_dual_atlas_e%d" % e, da, draw_dual_atlas(da))
    g = G.grid_layout(manifest)
    emit("template_grid", g, draw_grid(g))
    return written


def main():
    ap = argparse.ArgumentParser(description="生成线稿模板（SVG + PNG 底图 + sidecar JSON）")
    ap.add_argument("-e", "--elevation", type=int, choices=[0, 1, 2], default=None, help="只生成指定海拔档（默认 0/1/2 全出）")
    ap.add_argument("-o", "--out", default=os.path.join(G.repo_root(), "blender", "templates", "standard-templates"), help="输出目录")
    ap.add_argument("--pitch-deg", type=float, default=None, help="覆盖 manifest pitch_deg（默认使用正式 manifest）")
    ap.add_argument("--yaw-deg", type=float, default=None, help="覆盖 manifest yaw_deg（默认使用正式 manifest）")
    args = ap.parse_args()
    elevations = [args.elevation] if args.elevation is not None else [0, 1, 2]
    written = generate(args.out, elevations, pitch_deg=args.pitch_deg, yaw_deg=args.yaw_deg)
    print("TEMPLATES WRITTEN (%d files):" % len(written))
    for p in written:
        print("  " + os.path.relpath(p, G.repo_root()))


if __name__ == "__main__":
    main()
