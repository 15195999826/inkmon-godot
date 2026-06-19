# texgen.warp — 确定性几何后处理：正交反投影 warp + 俯视网格 mask 裁切
#
# warp（design_warp 方案 A′ 的核心）：设计稿（3D 全貌模板几何）→ UV 贴图。
# 正交投影下每个平面面片的 设计稿像素 ↔ UV 像素 是精确仿射 —— 顶面 + 可见侧壁逐面
# 解 3 点仿射、逐面重采样、按 UV island 多边形 mask 合成（往返恒等性来自 adr/0009 角度冻结）。
#
# cut（顶面网格填充流收获）：俯视网格画布 + 已知 cell 位置 → mask 裁出单格顶面（零 warp）。
#
# dual（dual_canvas 方案 B 的收获）：双联画布右 panel（UV 展开，等比缩放居中）→ 标准 UV 画布。
# 右 panel 与 UV 画布是相似变换 —— 仿射从 sidecar 的 uv_top ↔ UV 模板 top 三角点直接解出，
# 不复制 geometry.dual_layout 的布局公式（sidecar 即契约）。
#
# atlas（Route 3.1）：双联 atlas 右 panel（top hex + continuous wall strip）→ 标准 atlas 画布。
#
# 用法（repo 根）：
#   python blender/scripts/texgen/warp.py design <design.png> -e 0 -o <uv_out.png>
#   python blender/scripts/texgen/warp.py dual-design <dual.png> -e 0 -o <design_out.png>
#   python blender/scripts/texgen/warp.py dual <dual.png> -e 0 -o <uv_out.png>
#   python blender/scripts/texgen/warp.py atlas <dual_atlas.png> -e 0 -o <atlas_out.png>
#   python blender/scripts/texgen/warp.py cut <grid.png> -q 0 -r 0 -o <top_out.png>
#   python blender/scripts/texgen/warp.py relayout <old_uv.png> -e 0 --old-sidecar <旧.json> -o <new_uv.png>
#   （sidecar 默认从 blender/templates/standard-templates/ 按海拔/类型取；--sidecar 可显式指定）

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from texgen import geometry as G

TEMPLATES_DIR = os.path.join(G.repo_root(), "blender", "templates", "standard-templates")


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


# ---------------------------------------------------------------- 旧 UV 布局 → 新 UV 布局（迁移）

def relayout_uv(uv_png: str, old_sidecar: dict, new_sidecar: dict, out_png: str) -> dict:
    """已批准 UV 贴图跨布局迁移：face 同名（top/wall_i）→ 逐面仿射原样搬运，内容不变。
    与 warp_design_to_uv 同一机器（face_correspondences 只看 face 名与 3 控制点）。"""
    return warp_design_to_uv(uv_png, old_sidecar, new_sidecar, out_png)


# ---------------------------------------------------------------- dual 右 panel → UV

def extract_dual_uv(dual_png: str, dual_sidecar: dict, uv_sidecar: dict, out_png: str) -> dict:
    img = Image.open(dual_png).convert("RGBA")
    dw, dh = dual_sidecar["canvas"]
    if img.size != (dw, dh):
        raise ValueError("双联图尺寸 %s ≠ 模板画布 %s" % (img.size, (dw, dh)))
    uw, uh = uv_sidecar["canvas"]
    # 全 panel 单仿射：相似变换由 uv_top 三角点唯一确定（角点 0/2/4 非退化）
    src_p = dual_sidecar["faces"]["uv_top"]["polygon_px"]
    dst_p = uv_sidecar["faces"]["top"]["polygon_px"]
    coeffs = affine_coeffs([dst_p[0], dst_p[2], dst_p[4]], [src_p[0], src_p[2], src_p[4]])
    flat = img.transform((uw, uh), Image.Transform.AFFINE, coeffs, resample=Image.Resampling.BICUBIC)
    canvas = Image.new("RGBA", (uw, uh), (0, 0, 0, 0))
    for f in uv_sidecar["faces"].values():
        mask = _poly_mask((uw, uh), f.get("polygon_px") or f.get("quad_px"))
        canvas.paste(flat, (0, 0), mask)
    canvas.save(out_png)
    m = np.array([[coeffs[0], coeffs[1]], [coeffs[3], coeffs[4]]])
    sv = np.linalg.svd(np.linalg.inv(m), compute_uv=False)
    return {"upscale_max": float(sv.max()), "upscale_min": float(sv.min())}


def extract_dual_design(dual_png: str, dual_sidecar: dict, design_sidecar: dict, out_png: str) -> dict:
    """双联左 panel → 标准 design 画布。

    输出仍只是 design_warp 的输入，不是最终 sprite。
    """
    img = Image.open(dual_png).convert("RGBA")
    dw, dh = dual_sidecar["canvas"]
    if img.size != (dw, dh):
        raise ValueError("双联图尺寸 %s ≠ 模板画布 %s" % (img.size, (dw, dh)))
    ow, oh = design_sidecar["canvas"]
    src_p = dual_sidecar["faces"]["design_top"]["polygon_px"]
    dst_p = design_sidecar["faces"]["top"]["polygon_px"]
    coeffs = affine_coeffs([dst_p[0], dst_p[2], dst_p[4]], [src_p[0], src_p[2], src_p[4]])
    flat = img.transform((ow, oh), Image.Transform.AFFINE, coeffs, resample=Image.Resampling.BICUBIC)
    canvas = Image.new("RGBA", (ow, oh), (0, 0, 0, 0))
    for face in design_sidecar["faces"].values():
        mask = _poly_mask((ow, oh), face.get("polygon_px") or face.get("quad_px"))
        canvas.paste(flat, (0, 0), mask)
    canvas.save(out_png)
    m = np.array([[coeffs[0], coeffs[1]], [coeffs[3], coeffs[4]]])
    sv = np.linalg.svd(np.linalg.inv(m), compute_uv=False)
    return {"upscale_max": float(sv.max()), "upscale_min": float(sv.min())}


def extract_dual_atlas(dual_png: str, dual_sidecar: dict, atlas_sidecar: dict, out_png: str) -> dict:
    img = Image.open(dual_png).convert("RGBA")
    dw, dh = dual_sidecar["canvas"]
    if img.size != (dw, dh):
        raise ValueError("双联 atlas 图尺寸 %s ≠ 模板画布 %s" % (img.size, (dw, dh)))
    aw, ah = atlas_sidecar["canvas"]
    src_p = dual_sidecar["faces"]["atlas_top"]["polygon_px"]
    dst_p = atlas_sidecar["faces"]["top"]["polygon_px"]
    coeffs = affine_coeffs([dst_p[0], dst_p[2], dst_p[4]], [src_p[0], src_p[2], src_p[4]])
    flat = img.transform((aw, ah), Image.Transform.AFFINE, coeffs, resample=Image.Resampling.BICUBIC)
    canvas = Image.new("RGBA", (aw, ah), (0, 0, 0, 0))
    for face in atlas_sidecar["faces"].values():
        mask = _poly_mask((aw, ah), face.get("polygon_px") or face.get("quad_px"))
        canvas.paste(flat, (0, 0), mask)
    canvas.save(out_png)
    m = np.array([[coeffs[0], coeffs[1]], [coeffs[3], coeffs[4]]])
    sv = np.linalg.svd(np.linalg.inv(m), compute_uv=False)
    return {"upscale_max": float(sv.max()), "upscale_min": float(sv.min())}


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


# ---------------------------------------------------------------- UV 顶面 → 网格种子（cut 的逆操作）

def seed_grid_cells(uv_png: str, uv_sidecar: dict, grid_png: str, grid_sidecar: dict,
                    cells: list, out_png: str) -> dict:
    """UV 贴图的顶面 island 按 1:1 纹素密度贴入俯视网格指定格位（顶面网格填充流的种子摆放）。"""
    uv = Image.open(uv_png).convert("RGBA")
    uw, uh = uv_sidecar["canvas"]
    if uv.size != (uw, uh):
        raise ValueError("UV 贴图尺寸 %s ≠ 模板画布 %s" % (uv.size, (uw, uh)))
    s_uv = float(uv_sidecar["faces"]["top"]["px_per_unit"])
    s_grid = float(grid_sidecar["px_per_unit"])
    if abs(s_uv - s_grid) > 1e-6:
        raise ValueError("纹素密度不一致：uv %.3f vs grid %.3f（零缩放贴入前提破坏）" % (s_uv, s_grid))
    canvas = Image.open(grid_png).convert("RGBA")
    if canvas.size != tuple(grid_sidecar["canvas"]):
        raise ValueError("网格底图尺寸 %s ≠ 模板画布 %s" % (canvas.size, grid_sidecar["canvas"]))
    mask = _poly_mask(uv.size, uv_sidecar["faces"]["top"]["polygon_px"])
    cx, cy = uv_sidecar["faces"]["top"]["center_px"]
    placed = []
    for key in cells:
        if key not in grid_sidecar["cells"]:
            raise KeyError("cell %s 不在模板内，可用：%s" % (key, sorted(grid_sidecar["cells"])))
        gx, gy = grid_sidecar["cells"][key]["center_px"]
        off = (int(round(gx - cx)), int(round(gy - cy)))
        canvas.paste(uv, off, mask)
        placed.append({"cell": key, "offset_px": list(off)})
    canvas.save(out_png)
    return {"placed": placed}


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

    dd = sub.add_parser("dual-design", help="双联左 panel → 标准 design 画布")
    dd.add_argument("image")
    dd.add_argument("-e", "--elevation", type=int, choices=[0, 1, 2], default=0)
    dd.add_argument("--dual-sidecar", default=None)
    dd.add_argument("--design-sidecar", default=None)
    dd.add_argument("-o", "--out", required=True)

    r = sub.add_parser("relayout", help="旧布局 UV 贴图 → 现行布局（逐面仿射搬运，迁移用）")
    r.add_argument("image")
    r.add_argument("-e", "--elevation", type=int, choices=[0, 1, 2], default=0)
    r.add_argument("--old-sidecar", required=True, help="生成该贴图时的 UV sidecar（如 git 历史里的 template_uv_e<N>.json）")
    r.add_argument("--uv-sidecar", default=None)
    r.add_argument("-o", "--out", required=True)

    b = sub.add_parser("dual", help="双联右 panel → 标准 UV 画布（单仿射放大 + 面 mask）")
    b.add_argument("image")
    b.add_argument("-e", "--elevation", type=int, choices=[0, 1, 2], default=0)
    b.add_argument("--dual-sidecar", default=None)
    b.add_argument("--uv-sidecar", default=None)
    b.add_argument("-o", "--out", required=True)

    a = sub.add_parser("atlas", help="双联 atlas 右 panel → 标准 atlas 画布")
    a.add_argument("image")
    a.add_argument("-e", "--elevation", type=int, choices=[0, 1, 2], default=0)
    a.add_argument("--dual-sidecar", default=None)
    a.add_argument("--atlas-sidecar", default=None)
    a.add_argument("-o", "--out", required=True)

    c = sub.add_parser("cut", help="俯视网格 → 单格顶面 mask 裁切")
    c.add_argument("image")
    c.add_argument("-q", type=int, required=True)
    c.add_argument("-r", type=int, required=True)
    c.add_argument("--sidecar", default=None)
    c.add_argument("-o", "--out", required=True)

    s = sub.add_parser("seed", help="UV 顶面 island 1:1 贴入俯视网格格位（cut 的逆操作）")
    s.add_argument("uv_image")
    s.add_argument("--cells", required=True, help="逗号分隔 axial 键，如 0_0,1_0,-1_1")
    s.add_argument("-e", "--elevation", type=int, choices=[0, 1, 2], default=0)
    s.add_argument("--uv-sidecar", default=None)
    s.add_argument("--grid-image", default=None, help="网格底图（默认线稿模板 template_grid.png）")
    s.add_argument("--grid-sidecar", default=None)
    s.add_argument("-o", "--out", required=True)

    args = ap.parse_args()
    if args.cmd == "design":
        ds = load_sidecar(args.design_sidecar or default_sidecar("design", args.elevation))
        us = load_sidecar(args.uv_sidecar or default_sidecar("uv", args.elevation))
        report = warp_design_to_uv(args.image, ds, us, args.out)
        print("WARP OK ->", args.out)
        for face, info in report.items():
            print("  %-8s stretch %.3f .. %.3f" % (face, info["stretch_min"], info["stretch_max"]))
    elif args.cmd == "dual-design":
        ds = load_sidecar(args.dual_sidecar or default_sidecar("dual", args.elevation))
        design = load_sidecar(args.design_sidecar or default_sidecar("design", args.elevation))
        info = extract_dual_design(args.image, ds, design, args.out)
        print("DUAL LEFT->DESIGN OK ->", args.out)
        print("  upscale %.3f .. %.3f（左 panel → design 画布分辨率放大量）" % (info["upscale_min"], info["upscale_max"]))
    elif args.cmd == "relayout":
        old = load_sidecar(args.old_sidecar)
        us = load_sidecar(args.uv_sidecar or default_sidecar("uv", args.elevation))
        if old.get("layout") == us.get("layout"):
            raise ValueError("新旧 sidecar layout 相同（%r）—— relayout 是跨布局迁移，确认 --old-sidecar 来源" % old.get("layout"))
        report = relayout_uv(args.image, old, us, args.out)
        print("RELAYOUT OK ->", args.out)
        for face, info in report.items():
            print("  %-8s stretch %.3f .. %.3f" % (face, info["stretch_min"], info["stretch_max"]))
    elif args.cmd == "dual":
        ds = load_sidecar(args.dual_sidecar or default_sidecar("dual", args.elevation))
        us = load_sidecar(args.uv_sidecar or default_sidecar("uv", args.elevation))
        info = extract_dual_uv(args.image, ds, us, args.out)
        print("DUAL EXTRACT OK ->", args.out)
        print("  upscale %.3f .. %.3f（右 panel → UV 画布分辨率放大量）" % (info["upscale_min"], info["upscale_max"]))
    elif args.cmd == "atlas":
        ds = load_sidecar(args.dual_sidecar or default_sidecar("dual_atlas", args.elevation))
        atlas = load_sidecar(args.atlas_sidecar or default_sidecar("atlas", args.elevation))
        info = extract_dual_atlas(args.image, ds, atlas, args.out)
        print("ATLAS EXTRACT OK ->", args.out)
        print("  upscale %.3f .. %.3f（右 panel → atlas 画布分辨率放大量）" % (info["upscale_min"], info["upscale_max"]))
    elif args.cmd == "seed":
        us = load_sidecar(args.uv_sidecar or default_sidecar("uv", args.elevation))
        gs = load_sidecar(args.grid_sidecar or default_sidecar("grid"))
        grid_img = args.grid_image or os.path.join(TEMPLATES_DIR, "template_grid.png")
        info = seed_grid_cells(args.uv_image, us, grid_img, gs, args.cells.split(","), args.out)
        print("SEED OK ->", args.out)
        for p in info["placed"]:
            print("  cell %-6s offset %s" % (p["cell"], p["offset_px"]))
    else:
        gs = load_sidecar(args.sidecar or default_sidecar("grid"))
        info = cut_grid_cell(args.image, gs, args.q, args.r, args.out)
        print("CUT OK ->", args.out)
        print("  cell %s crop %s size %s px_per_unit %s" % (info["cell"], info["crop_px"], info["size_px"], info["px_per_unit"]))


if __name__ == "__main__":
    main()
