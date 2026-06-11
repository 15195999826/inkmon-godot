# texgen.qc — 数据级 QC：模板边缘偏差 / alpha 覆盖率 / 轮廓匹配（超阈值判废）
#
# 评估对象 = 生成图（GPT 设计稿 / warp 产物 / 俯视网格收获），期望几何 = 模板 sidecar JSON。
# 截图自评不可信几何（memory 案底）—— 对齐类问题一律走这里的数值断言：
#   - edge_deviation：沿期望多边形边采样，法向扫描前景图梯度峰 → 实际边缘偏移 px
#   - coverage：期望多边形内的前景占比（alpha 有效时按 alpha，否则按非白）
#   - contour IoU：前景 mask 与期望多边形并集的交并比
#
# 用法（repo 根）：
#   python blender/scripts/texgen/qc.py <image.png> --sidecar <template_xxx.json> [--faces top,wall_4]
#   阈值默认读 blender/textures/gen_config.json 的 "qc" 节；全过 exit 0，判废 exit 1。

import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from texgen import geometry as G

DEFAULT_THRESHOLDS = {
    "edge_dev_mean_max_px": 4.0,
    "edge_dev_max_max_px": 10.0,
    "edge_detect_rate_min": 0.85,
    "coverage_min": 0.97,
    "contour_iou_min": 0.93,
}
GEN_CONFIG_PATH = os.path.join(G.repo_root(), "blender", "textures", "gen_config.json")


def load_thresholds(path: "str | None" = None) -> dict:
    th = dict(DEFAULT_THRESHOLDS)
    p = path or GEN_CONFIG_PATH
    if os.path.isfile(p):
        with open(p, "r", encoding="utf-8") as f:
            th.update(json.load(f).get("qc", {}))
    return th


# ---------------------------------------------------------------- 前景图

def foreground_map(img: Image.Image) -> np.ndarray:
    """float [0,1] 前景强度：alpha 有意义（存在半透明/全透明像素）时用 alpha，
    否则按"非画布白"判定（lum ≥0.96 → 0，≤0.88 → 1，间窄 ramp）。"""
    rgba = np.asarray(img.convert("RGBA"), dtype=np.float32) / 255.0
    alpha = rgba[..., 3]
    if alpha.min() < 0.98:
        return alpha
    lum = rgba[..., :3] @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    return np.clip((0.96 - lum) / 0.08, 0.0, 1.0)


def feature_map(img: Image.Image) -> np.ndarray:
    """边缘检测特征 H×W×4 = [R,G,B,alpha]（float [0,1]）：颜色与透明度变化都算边。"""
    return np.asarray(img.convert("RGBA"), dtype=np.float32) / 255.0


def _bilinear_vec(m: np.ndarray, x: float, y: float) -> np.ndarray:
    h, w = m.shape[:2]
    if x < 0 or y < 0 or x > w - 2 or y > h - 2:
        return np.zeros(m.shape[2], dtype=np.float32)
    x0, y0 = int(x), int(y)
    fx, fy = x - x0, y - y0
    return (
        m[y0, x0] * (1 - fx) * (1 - fy) + m[y0, x0 + 1] * fx * (1 - fy)
        + m[y0 + 1, x0] * (1 - fx) * fy + m[y0 + 1, x0 + 1] * fx * fy
    )


# ---------------------------------------------------------------- 指标

def edge_deviation(feat: np.ndarray, polygon, search_px: float = 12.0, step_px: float = 6.0,
                   grad_min: float = 0.15) -> dict:
    """沿多边形边采样点，法向 ±search_px 扫描 RGBA 联合梯度，取**最近**的合格峰
    （取最大会咬到面内纹理；真边在期望位置附近，近者优先）。返回偏移统计与检出率。"""
    offsets = []
    misses = 0
    n_pts = len(polygon)
    for i in range(n_pts):
        ax, ay = polygon[i]
        bx, by = polygon[(i + 1) % n_pts]
        seg_len = math.hypot(bx - ax, by - ay)
        if seg_len < 1.0:
            continue
        nx, ny = (by - ay) / seg_len, -(bx - ax) / seg_len  # 单位法向（方向无所谓，扫双侧）
        # 避开顶点处的折角干扰：边两端各让 15%
        k = max(2, int(seg_len / step_px))
        for j in range(k + 1):
            t = 0.15 + 0.7 * j / k
            px, py = ax + (bx - ax) * t, ay + (by - ay) * t
            steps = int(search_px * 2)
            samples = [_bilinear_vec(feat, px + nx * (-search_px + s), py + ny * (-search_px + s))
                       for s in range(steps + 1)]
            best_off = None
            # 2px 基线差分：斜边 staircase 会把颜色过渡摊进两个 1px 步，单步差会漏检
            for s in range(1, steps):
                g = float(np.linalg.norm(samples[s + 1] - samples[s - 1]))
                if g >= grad_min:
                    off = -search_px + s
                    if best_off is None or abs(off) < abs(best_off):
                        best_off = off
            if best_off is not None:
                offsets.append(abs(best_off))
            else:
                misses += 1
    total = len(offsets) + misses
    return {
        "samples": total,
        "detect_rate": (len(offsets) / total) if total else 0.0,
        "mean_px": float(np.mean(offsets)) if offsets else None,
        "max_px": float(np.max(offsets)) if offsets else None,
    }


def _poly_mask_bool(shape, polygon) -> np.ndarray:
    from PIL import ImageDraw
    m = Image.new("L", (shape[1], shape[0]), 0)
    ImageDraw.Draw(m).polygon([tuple(p) for p in polygon], fill=255)
    return np.asarray(m) > 127


def coverage_and_iou(fg: np.ndarray, polygons) -> dict:
    expected = np.zeros(fg.shape, dtype=bool)
    for poly in polygons:
        expected |= _poly_mask_bool(fg.shape, poly)
    actual = fg > 0.5
    inter = (expected & actual).sum()
    union = (expected | actual).sum()
    return {
        "coverage": float(inter / max(1, expected.sum())),
        "contour_iou": float(inter / max(1, union)),
    }


# ---------------------------------------------------------------- 评估入口

def _sidecar_polygons(sidecar: dict, faces_filter: "list | None") -> dict:
    """{name: polygon}。design/uv/dual 取 faces；grid 取 cells。"""
    out = {}
    if "faces" in sidecar:
        for name, f in sidecar["faces"].items():
            out[name] = f.get("polygon_px") or f.get("quad_px")
    elif "cells" in sidecar:
        for name, c in sidecar["cells"].items():
            out["cell_" + name] = c["polygon_px"]
    if faces_filter:
        out = {k: v for k, v in out.items() if k in faces_filter}
    return out


def evaluate(image_path: str, sidecar: dict, faces_filter: "list | None" = None,
             thresholds: "dict | None" = None) -> dict:
    th = thresholds or load_thresholds()
    img = Image.open(image_path)
    sw, sh = sidecar["canvas"]
    if img.size != (sw, sh):
        raise ValueError("图尺寸 %s ≠ 模板画布 %s" % (img.size, (sw, sh)))
    fg = foreground_map(img)
    feat = feature_map(img)
    polys = _sidecar_polygons(sidecar, faces_filter)
    if not polys:
        raise ValueError("sidecar 内没有匹配的面/格")

    report = {"image": image_path, "faces": {}, "thresholds": th}
    devs, rates = [], []
    for name, poly in polys.items():
        d = edge_deviation(feat, poly)
        report["faces"][name] = d
        if d["mean_px"] is not None:
            devs.append(d["mean_px"])
        rates.append(d["detect_rate"])
    report.update(coverage_and_iou(fg, list(polys.values())))
    report["edge_dev_mean_px"] = float(np.mean(devs)) if devs else None
    report["edge_dev_max_px"] = max((report["faces"][n]["max_px"] or 0.0) for n in report["faces"]) if devs else None
    report["edge_detect_rate"] = float(np.mean(rates))

    checks = {
        "edge_dev_mean": report["edge_dev_mean_px"] is not None and report["edge_dev_mean_px"] <= th["edge_dev_mean_max_px"],
        "edge_dev_max": report["edge_dev_max_px"] is not None and report["edge_dev_max_px"] <= th["edge_dev_max_max_px"],
        "edge_detect_rate": report["edge_detect_rate"] >= th["edge_detect_rate_min"],
        "coverage": report["coverage"] >= th["coverage_min"],
        "contour_iou": report["contour_iou"] >= th["contour_iou_min"],
    }
    report["checks"] = checks
    report["pass"] = all(checks.values())
    return report


def main():
    ap = argparse.ArgumentParser(description="数据级 QC：边缘偏差 / 覆盖率 / 轮廓匹配")
    ap.add_argument("image")
    ap.add_argument("--sidecar", required=True)
    ap.add_argument("--faces", default=None, help="逗号分隔的面名（默认全部）")
    ap.add_argument("--config", default=None, help="阈值来源（默认 blender/textures/gen_config.json 的 qc 节）")
    args = ap.parse_args()
    with open(args.sidecar, "r", encoding="utf-8") as f:
        sidecar = json.load(f)
    faces = args.faces.split(",") if args.faces else None
    report = evaluate(args.image, sidecar, faces, load_thresholds(args.config))

    print("QC %s" % ("PASS" if report["pass"] else "FAIL"))
    print("  edge_dev mean %.2fpx max %.2fpx detect %.0f%%  (限 %.1f / %.1f / ≥%.0f%%)" % (
        -1.0 if report["edge_dev_mean_px"] is None else report["edge_dev_mean_px"],
        -1.0 if report["edge_dev_max_px"] is None else report["edge_dev_max_px"],
        report["edge_detect_rate"] * 100,
        report["thresholds"]["edge_dev_mean_max_px"], report["thresholds"]["edge_dev_max_max_px"],
        report["thresholds"]["edge_detect_rate_min"] * 100))
    print("  coverage %.3f (≥%.2f)  contour_iou %.3f (≥%.2f)" % (
        report["coverage"], report["thresholds"]["coverage_min"],
        report["contour_iou"], report["thresholds"]["contour_iou_min"]))
    for name, d in report["faces"].items():
        print("  %-12s dev mean %s max %s detect %.0f%%" % (
            name,
            ("%.2f" % d["mean_px"]) if d["mean_px"] is not None else "n/a",
            ("%.2f" % d["max_px"]) if d["max_px"] is not None else "n/a",
            d["detect_rate"] * 100))
    sys.exit(0 if report["pass"] else 1)


if __name__ == "__main__":
    main()
