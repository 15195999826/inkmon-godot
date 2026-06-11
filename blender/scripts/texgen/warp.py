# texgen.warp — 确定性几何后处理：正交反投影 warp + 俯视网格 mask 裁切
#
# warp（design_warp 方案 A′ 的核心）：设计稿（3D 全貌模板几何）→ UV 贴图。
# 正交投影下每个平面面片的 设计稿像素 ↔ UV 像素 是精确仿射 —— 顶面 + 可见侧壁逐面
# 解 3 点仿射、逐面重采样、按 UV island 多边形 mask 合成（往返恒等性来自 adr/0009 角度冻结）。
#
# cut（顶面网格填充流收获）：俯视网格画布 + 已知 cell 位置 → mask 裁出单格顶面（零 warp）。
#
# 用法（repo 根）：
#   python blender/scripts/texgen/warp.py design <design.png> -e 0 -o <uv_out.png>
#   python blender/scripts/texgen/warp.py cut <grid.png> -q 0 -r 0 -o <top_out.png>
#   （sidecar 默认从 blender/templates/ 按海拔/类型取；--sidecar 可显式指定）

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from texgen import geometry as G

TEMPLATES_DIR = os.path.join(G.repo_root(), "blender", "templates")


def load_sidecar(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def default_sidecar(template: str, elevation: int = 0) -> str:
    if template == "grid":
        return os.path.join(TEMPLATES_DIR, "template_grid.json")
    return os.path.join(TEMPLATES_DIR, "template_%s_e%d.json" % (template, elevation))


# ---------------------------------------------------------------- 仿射

def affine_coeffs(dst_tri, src_tri):
    """解 PIL Image.transform(AFFINE) 系数：输出(dst)像素 (x,y) ← 输入(src) (a·x+b·y+c, d·x+e·y+f)。"""
    a = np.zeros((6, 6))
    b = np.zeros(6)
    for k in range(3):
        dx, dy = dst_tri[k]
        sx, sy = src_tri[k]
        a[2 * k] = [dx, dy, 1, 0, 0, 0]
        a[2 * k + 1] = [0, 0, 0, dx, dy, 1]
        b[2 * k] = sx
        b[2 * k + 1] = sy
    return tuple(np.linalg.solve(a, b))


def _poly_mask(size, polygon, supersample: int = 4) -> Image.Image:
    """抗锯齿多边形 mask（超采样后缩回）。"""
    w, h = size
    big = Image.new("L", (w * supersample, h * supersample), 0)
    d = ImageDraw.Draw(big)
    d.polygon([(x * supersample, y * supersample) for (x, y) in polygon], fill=255)
    return big.resize((w, h), Image.Resampling.LANCZOS)


# ---------------------------------------------------------------- design → UV

def warp_design_to_uv(design_png: str, design_sidecar: dict, uv_sidecar: dict, out_png: str) -> dict:
    img = Image.open(design_png).convert("RGBA")
    dw, dh = design_sidecar["canvas"]
    if img.size != (dw, dh):
        raise ValueError("设计稿尺寸 %s ≠ 模板画布 %s" % (img.size, (dw, dh)))
    uw, uh = uv_sidecar["canvas"]
    canvas = Image.new("RGBA", (uw, uh), (0, 0, 0, 0))
    report = {}
    for face, src_tri, dst_tri, dst_poly in G.face_correspondences(design_sidecar, uv_sidecar):
        coeffs = affine_coeffs(dst_tri, src_tri)
        warped = img.transform((uw, uh), Image.Transform.AFFINE, coeffs, resample=Image.Resampling.BICUBIC)
        mask = _poly_mask((uw, uh), dst_poly)
        canvas.paste(warped, (0, 0), mask)
        # 记录每面的有效缩放（仿射线性部分奇异值 = 轴向拉伸量，src→dst）
        m = np.array([[coeffs[0], coeffs[1]], [coeffs[3], coeffs[4]]])
        sv = np.linalg.svd(np.linalg.inv(m), compute_uv=False)
        report[face] = {"stretch_max": float(sv.max()), "stretch_min": float(sv.min())}
    canvas.save(out_png)
    return report


# ---------------------------------------------------------------- grid → 单格顶面

def cut_grid_cell(grid_png: str, grid_sidecar: dict, q: int, r: int, out_png: str, pad_px: int = 8) -> dict:
    img = Image.open(grid_png).convert("RGBA")
    gw, gh = grid_sidecar["canvas"]
    if img.size != (gw, gh):
        raise ValueError("网格图尺寸 %s ≠ 模板画布 %s" % (img.size, (gw, gh)))
    key = "%d_%d" % (q, r)
    cells = grid_sidecar["cells"]
    if key not in cells:
        raise KeyError("cell (%d,%d) 不在模板内，可用：%s" % (q, r, sorted(cells)))
    poly = cells[key]["polygon_px"]
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    x0, y0 = int(min(xs)) - pad_px, int(min(ys)) - pad_px
    x1, y1 = int(max(xs)) + pad_px, int(max(ys)) + pad_px
    mask = _poly_mask(img.size, poly)
    cut = Image.new("RGBA", img.size, (0, 0, 0, 0))
    cut.paste(img, (0, 0), mask)
    cut = cut.crop((x0, y0, x1, y1))
    cut.save(out_png)
    return {
        "cell": [q, r],
        "crop_px": [x0, y0, x1, y1],
        "size_px": [cut.width, cut.height],
        "px_per_unit": grid_sidecar["px_per_unit"],
    }


# ---------------------------------------------------------------- CLI

def main():
    ap = argparse.ArgumentParser(description="正交反投影 warp / 俯视网格 mask 裁切")
    sub = ap.add_subparsers(dest="cmd", required=True)

    d = sub.add_parser("design", help="设计稿 → UV 贴图（逐面仿射）")
    d.add_argument("image")
    d.add_argument("-e", "--elevation", type=int, choices=[0, 1, 2], default=0)
    d.add_argument("--design-sidecar", default=None)
    d.add_argument("--uv-sidecar", default=None)
    d.add_argument("-o", "--out", required=True)

    c = sub.add_parser("cut", help="俯视网格 → 单格顶面 mask 裁切")
    c.add_argument("image")
    c.add_argument("-q", type=int, required=True)
    c.add_argument("-r", type=int, required=True)
    c.add_argument("--sidecar", default=None)
    c.add_argument("-o", "--out", required=True)

    args = ap.parse_args()
    if args.cmd == "design":
        ds = load_sidecar(args.design_sidecar or default_sidecar("design", args.elevation))
        us = load_sidecar(args.uv_sidecar or default_sidecar("uv", args.elevation))
        report = warp_design_to_uv(args.image, ds, us, args.out)
        print("WARP OK ->", args.out)
        for face, info in report.items():
            print("  %-8s stretch %.3f .. %.3f" % (face, info["stretch_min"], info["stretch_max"]))
    else:
        gs = load_sidecar(args.sidecar or default_sidecar("grid"))
        info = cut_grid_cell(args.image, gs, args.q, args.r, args.out)
        print("CUT OK ->", args.out)
        print("  cell %s crop %s size %s px_per_unit %s" % (info["cell"], info["crop_px"], info["size_px"], info["px_per_unit"]))


if __name__ == "__main__":
    main()
