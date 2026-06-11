# texgen.make_placeholder — 手工占位图：不花一张 gpt-image-2 验证几何链路数学
#
# 产出三件（默认 blender/templates/placeholders/）：
#   placeholder_design_e<N>.png — 按 3D 全貌模板几何精确填充：顶面绿底网格纹（warp 反拉伸
#     1.73x 肉眼可验）、三可见侧壁异色横条砖纹（左中右 红/黄/蓝 调，对应关系可验）
#   placeholder_sprite_bush.png — 透明底灌木 sprite（故意偏离画布中心 + 底部留白，
#     验证 alpha bottom-center 锚点自动计算）
#   placeholder_grid.png — 俯视网格 7 格各填异色 + 同心环纹（mask 裁切可验）
#
# 用法（repo 根）：python blender/scripts/texgen/make_placeholder.py [-e 0]

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from texgen import geometry as G

from PIL import Image, ImageDraw

OUT_DIR_DEFAULT = os.path.join(G.repo_root(), "blender", "templates", "placeholders")


def _fill_poly_pattern(img: Image.Image, polygon, base, stripe, spacing=24, horizontal=True):
    """多边形内填 base 色 + stripe 色条纹（先画满层再 mask 粘贴）。"""
    layer = Image.new("RGB", img.size, base)
    d = ImageDraw.Draw(layer)
    w, h = img.size
    if horizontal:
        for y in range(0, h, spacing):
            d.line([(0, y), (w, y)], fill=stripe, width=6)
    else:
        for x in range(0, w, spacing):
            d.line([(x, 0), (x, h)], fill=stripe, width=6)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon([tuple(p) for p in polygon], fill=255)
    img.paste(layer, (0, 0), mask)


def _fill_poly_grid(img: Image.Image, polygon, base, line, spacing=32):
    layer = Image.new("RGB", img.size, base)
    d = ImageDraw.Draw(layer)
    w, h = img.size
    for y in range(0, h, spacing):
        d.line([(0, y), (w, y)], fill=line, width=4)
    for x in range(0, w, spacing):
        d.line([(x, 0), (x, h)], fill=line, width=4)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon([tuple(p) for p in polygon], fill=255)
    img.paste(layer, (0, 0), mask)


def make_design(manifest: dict, elevation: int, out_png: str):
    layout = G.design_layout(manifest, elevation)
    img = Image.new("RGB", tuple(layout["canvas"]), (255, 255, 255))
    faces = layout["faces"]
    _fill_poly_grid(img, faces["top"]["polygon_px"], (110, 150, 70), (60, 90, 40))
    wall_tints = [((150, 80, 60), (100, 50, 40)), ((170, 140, 70), (120, 95, 45)), ((80, 110, 150), (50, 75, 110))]
    order = G.visible_walls(manifest)
    for k, i in enumerate(order):
        base, stripe = wall_tints[k % len(wall_tints)]
        _fill_poly_pattern(img, faces["wall_%d" % i]["quad_px"], base, stripe, spacing=22)
    img.save(out_png)
    return out_png


def make_sprite(out_png: str, canvas=(512, 512)):
    """灌木团：椭圆簇，水平偏右 + 底部留 70px 空白（锚点自动算的反证物）。"""
    img = Image.new("RGBA", canvas, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = canvas[0] // 2 + 40, canvas[1] - 70  # 故意不居中
    blobs = [
        (cx - 90, cy - 150, cx + 30, cy - 30, (70, 100, 50, 255)),
        (cx - 30, cy - 180, cx + 100, cy - 50, (90, 120, 60, 255)),
        (cx - 60, cy - 110, cx + 70, cy, (60, 90, 45, 255)),
        (cx + 10, cy - 120, cx + 120, cy - 10, (80, 110, 55, 255)),
    ]
    for x0, y0, x1, y1, c in blobs:
        d.ellipse([x0, y0, x1, y1], fill=c)
    d.ellipse([cx - 40, cy - 140, cx + 40, cy - 70], fill=(110, 140, 75, 255))
    img.save(out_png)
    return out_png


def make_grid(manifest: dict, out_png: str):
    layout = G.grid_layout(manifest)
    img = Image.new("RGB", tuple(layout["canvas"]), (255, 255, 255))
    palette = [
        (110, 150, 70), (150, 80, 60), (170, 140, 70), (80, 110, 150),
        (130, 90, 130), (60, 170, 160), (160, 110, 90),
    ]
    for k, (key, cell) in enumerate(sorted(layout["cells"].items())):
        base = palette[k % len(palette)]
        poly = cell["polygon_px"]
        mask = Image.new("L", img.size, 0)
        ImageDraw.Draw(mask).polygon([tuple(p) for p in poly], fill=255)
        layer = Image.new("RGB", img.size, base)
        d = ImageDraw.Draw(layer)
        ccx, ccy = cell["center_px"]
        for ring in range(20, 260, 40):
            d.ellipse([ccx - ring, ccy - ring, ccx + ring, ccy + ring],
                      outline=tuple(max(0, c - 35) for c in base), width=5)
        img.paste(layer, (0, 0), mask)
    img.save(out_png)
    return out_png


def main():
    ap = argparse.ArgumentParser(description="生成手工占位图（设计稿/sprite/俯视网格）")
    ap.add_argument("-e", "--elevation", type=int, choices=[0, 1, 2], default=0)
    ap.add_argument("-o", "--out", default=OUT_DIR_DEFAULT)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    manifest = G.load_manifest()
    written = [
        make_design(manifest, args.elevation, os.path.join(args.out, "placeholder_design_e%d.png" % args.elevation)),
        make_sprite(os.path.join(args.out, "placeholder_sprite_bush.png")),
        make_grid(manifest, os.path.join(args.out, "placeholder_grid.png")),
    ]
    print("PLACEHOLDERS WRITTEN:")
    for p in written:
        print("  " + os.path.relpath(p, G.repo_root()))


if __name__ == "__main__":
    main()
