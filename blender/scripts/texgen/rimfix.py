# texgen.rimfix — 确定性棱线重描：设计稿内部共享边按模板原位重画
#
# 动机（Round 2.5 实证）：gpt-image-2 在高墙海拔（e1/e2）会把草/土顶棱画成有机翻边/软过渡，
# 把模板棱线整段埋掉——措辞迭代 4 版 0/11 证实提示词不可修。但内部棱线位置是先验已知的
# （sidecar 即契约），与 warp/cut/sprite_key 同属"裁切对齐永远由我们做"（CONTEXT.md）：
# 模型管纹理，几何归我们。
#
# 只重描**内部共享边**（top↔wall 顶棱、wall↔wall 竖棱）；外轮廓（剪影）绝不重描——
# 模型把剪影画歪是真几何废稿，必须留给 QC 判死（IoU/coverage/silhouette edge_dev 职责不变）。
#
# 用法（repo 根）：
#   python blender/scripts/texgen/rimfix.py <design.png> -e 1 -o <out.png>
#   （sidecar 默认 blender/templates/template_design_e<N>.json；--sidecar 可显式指定）

import argparse
import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from texgen.make_templates import LINE_COLOR, LINE_W

TEMPLATES_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "templates")


def _face_polygons(sidecar: dict) -> dict:
    polys = {}
    for name, face in sidecar["faces"].items():
        polys[name] = face.get("polygon_px") or face.get("quad_px")
    return polys


def _edge_key(a, b):
    """端点量化 + 排序，让两个面各自记录的同一条边落到同一个 key。"""
    pa = (round(a[0], 1), round(a[1], 1))
    pb = (round(b[0], 1), round(b[1], 1))
    return (pa, pb) if pa <= pb else (pb, pa)


def interior_edges(sidecar: dict) -> list:
    """被 ≥2 个面共享的边 = 内部棱线（顶棱/竖棱）；只出现一次的是外轮廓，不返回。"""
    seen = {}
    for poly in _face_polygons(sidecar).values():
        n = len(poly)
        for i in range(n):
            key = _edge_key(poly[i], poly[(i + 1) % n])
            seen[key] = seen.get(key, 0) + 1
    return [key for key, count in seen.items() if count >= 2]


def redraw_rims(img: Image.Image, sidecar: dict) -> "tuple[Image.Image, int]":
    out = img.convert("RGB").copy()
    draw = ImageDraw.Draw(out)
    edges = interior_edges(sidecar)
    for a, b in edges:
        draw.line([a, b], fill=LINE_COLOR, width=LINE_W)
        # 端点圆头，避免与既有线相接处缺角
        r = LINE_W / 2.0
        for px, py in (a, b):
            draw.ellipse([px - r, py - r, px + r, py + r], fill=LINE_COLOR)
    return out, len(edges)


def main():
    ap = argparse.ArgumentParser(description="设计稿内部棱线按模板原位重描（外轮廓不碰）")
    ap.add_argument("image")
    ap.add_argument("-e", "--elevation", type=int, choices=[0, 1, 2], default=0)
    ap.add_argument("--sidecar", help="默认 templates/template_design_e<N>.json")
    ap.add_argument("-o", "--out", required=True)
    args = ap.parse_args()

    sidecar_path = args.sidecar or os.path.join(TEMPLATES_DIR, "template_design_e%d.json" % args.elevation)
    with open(sidecar_path, "r", encoding="utf-8") as f:
        sidecar = json.load(f)

    img = Image.open(args.image)
    out, n = redraw_rims(img, sidecar)
    out.save(args.out)
    print("RIMFIX OK -> %s  (%d interior edges redrawn)" % (args.out, n))


if __name__ == "__main__":
    main()
