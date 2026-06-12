# texgen.make_templates — 线稿模板生成：四版本 SVG + PNG 底图 + sidecar JSON
#
# 四版本（CONTEXT.md）：3D 全貌 / UV 展开 / 双联 / 俯视网格。几何全部来自 texgen.geometry
# （角度/比例读 baked manifest.json）。SVG = 人审视图；PNG = gpt-image-2 底图（同几何 PIL 直绘）；
# sidecar JSON = warp / QC 的运行时契约（多边形像素坐标、scale、manifest 摘录）。
#
# 用法（repo 根）：
#   python blender/scripts/texgen/make_templates.py            # 全套（e0/e1/e2 × 3 + grid）
#   python blender/scripts/texgen/make_templates.py -e 0       # 只 e0
#   python blender/scripts/texgen/make_templates.py -o <dir>   # 自定义输出目录（默认 blender/templates/）

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from texgen import geometry as G

from PIL import Image, ImageDraw

LINE_COLOR = (40, 40, 40)
LINE_W = 4


# ---------------------------------------------------------------- 绘制原语（SVG 文本 + PIL 同步出）

class Sheet:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.svg = []
        self.img = Image.new("RGB", (w, h), (255, 255, 255))
        self.draw = ImageDraw.Draw(self.img)

    def polygon(self, pts, width=LINE_W):
        d = "M " + " L ".join("%.2f %.2f" % (x, y) for x, y in pts) + " Z"
        self.svg.append('<path d="%s" fill="none" stroke="rgb%s" stroke-width="%d" stroke-linejoin="round"/>' % (d, LINE_COLOR, width))
        self.draw.polygon([tuple(p) for p in pts], outline=LINE_COLOR, width=width)

    def line(self, a, b, width=LINE_W):
        self.svg.append('<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="rgb%s" stroke-width="%d" stroke-linecap="round"/>' % (a[0], a[1], b[0], b[1], LINE_COLOR, width))
        self.draw.line([tuple(a), tuple(b)], fill=LINE_COLOR, width=width)

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
    faces = layout["faces"]
    sheet.polygon(faces["top"]["polygon_px"])
    for name, f in faces.items():
        if name.startswith("wall_"):
            sheet.polygon(f["quad_px"])
    return sheet


def draw_uv(layout: dict, prefix: str = "", sheet: "Sheet | None" = None) -> Sheet:
    """unfold net 生产参考图：只画面轮廓（铰接边即面分割线），无文字/虚线/对应刻线。"""
    if sheet is None:
        sheet = Sheet(*layout["canvas"])
    faces = layout["faces"]
    sheet.polygon(faces[prefix + "top"]["polygon_px"])
    for i in layout["wall_order"]:
        sheet.polygon(faces["%swall_%d" % (prefix, i)]["quad_px"])
    return sheet


def draw_dual(layout: dict) -> Sheet:
    sheet = Sheet(*layout["canvas"])
    dx = layout["divider_x"]
    sheet.line((dx, 0), (dx, layout["canvas"][1]), width=2)
    faces = layout["faces"]
    sheet.polygon(faces["design_top"]["polygon_px"])
    for name, f in faces.items():
        if name.startswith("design_wall_"):
            sheet.polygon(f["quad_px"])
    draw_uv(layout, prefix="uv_", sheet=sheet)
    return sheet


def draw_grid(layout: dict) -> Sheet:
    sheet = Sheet(*layout["canvas"])
    for cell in layout["cells"].values():
        sheet.polygon(cell["polygon_px"])
    return sheet


# ---------------------------------------------------------------- 入口

def generate(out_dir: str, elevations) -> list:
    manifest = G.load_manifest()
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
    g = G.grid_layout(manifest)
    emit("template_grid", g, draw_grid(g))
    return written


def main():
    ap = argparse.ArgumentParser(description="生成线稿模板（SVG + PNG 底图 + sidecar JSON）")
    ap.add_argument("-e", "--elevation", type=int, choices=[0, 1, 2], default=None, help="只生成指定海拔档（默认 0/1/2 全出）")
    ap.add_argument("-o", "--out", default=os.path.join(G.repo_root(), "blender", "templates"), help="输出目录")
    args = ap.parse_args()
    elevations = [args.elevation] if args.elevation is not None else [0, 1, 2]
    written = generate(args.out, elevations)
    print("TEMPLATES WRITTEN (%d files):" % len(written))
    for p in written:
        print("  " + os.path.relpath(p, G.repo_root()))


if __name__ == "__main__":
    main()
