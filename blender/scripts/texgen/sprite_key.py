# texgen.sprite_key — 图片装饰 sprite 假透明键控：棋盘格/白底 → 真 alpha
#
# gpt-image-2 无 transparent background 参数时会把"透明棋盘格"画进像素（lab MCP 契约
# 只传 prompt/底图/参考图/n/size/quality）。本工具做确定性后处理：
#   1. 背景候选 = 低饱和 + 高明度像素（覆盖白底与浅灰棋盘两种方格）
#   2. 从画布四边 flood-fill，只有连通到边界的背景候选才判透明——主体内部的浅色高光不受伤
#   3. 边界 1-2px 抗锯齿带按"背景相似度"给部分 alpha，墨线轮廓外缘不带白边
#
# 用法（repo 根）：
#   python blender/scripts/texgen/sprite_key.py <sprite.png> -o <out.png>
#   输出打印 透明占比 / 不透明 bbox / 底中锚点（与 bake_assets 锚点自动计算同口径），
#   透明占比 < --min-transparent（默认 0.2）时判废 exit 1（背景没键掉 = 假成功）。

import argparse
import sys

import numpy as np
from PIL import Image


def _hsv_sv(rgb: np.ndarray):
    """rgb float [0,1] H×W×3 → (saturation, value)。"""
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    s = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    return s, mx


def key_sprite(in_png: str, out_png: str, sat_max: float = 0.16, val_min: float = 0.72) -> dict:
    img = Image.open(in_png).convert("RGBA")
    rgba = np.asarray(img, dtype=np.float32) / 255.0
    rgb = rgba[..., :3]
    s, v = _hsv_sv(rgb)
    # 背景相似度 [0,1]：低饱和且高明度（白 / 浅灰棋盘格都落在这）
    bgness = np.clip((sat_max - s) / sat_max, 0.0, 1.0) * np.clip((v - val_min) / (1.0 - val_min), 0.0, 1.0)
    candidate = bgness > 0.15

    # 从四边 flood-fill：只判连通边界的背景（迭代膨胀到不动点）
    bg = np.zeros_like(candidate)
    bg[0, :] = candidate[0, :]
    bg[-1, :] = candidate[-1, :]
    bg[:, 0] = candidate[:, 0]
    bg[:, -1] = candidate[:, -1]
    while True:
        grown = bg | (np.roll(bg, 1, 0) & candidate) | (np.roll(bg, -1, 0) & candidate) \
                   | (np.roll(bg, 1, 1) & candidate) | (np.roll(bg, -1, 1) & candidate)
        # roll 的环绕污染：四边由初始化钉死，无需修正（首末行列恒以 candidate 为上限）
        if (grown == bg).all():
            break
        bg = grown

    alpha = np.where(bg, 0.0, rgba[..., 3])
    # 边界抗锯齿带：紧邻背景的前景像素按背景相似度褪 alpha（棋盘格 AA 残渣不带白边）
    near_bg = (~bg) & (np.roll(bg, 1, 0) | np.roll(bg, -1, 0) | np.roll(bg, 1, 1) | np.roll(bg, -1, 1))
    band = near_bg | ((~bg) & (np.roll(near_bg, 1, 0) | np.roll(near_bg, -1, 0)
                               | np.roll(near_bg, 1, 1) | np.roll(near_bg, -1, 1)))
    alpha = np.where(band, alpha * (1.0 - bgness), alpha)

    out = np.dstack([rgb, alpha])
    Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGBA").save(out_png)

    op = alpha > 0.5
    ys, xs = np.where(op)
    h = alpha.shape[0]
    info = {"transparent_ratio": float((alpha < 0.04).mean())}
    if len(xs):
        bottom = int(ys.max())
        row = xs[ys > bottom - 8]
        info.update({
            "bbox": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
            "anchor_px": [float((row.min() + row.max()) / 2.0), bottom],
            "bottom_margin_px": int(h - 1 - bottom),
        })
    return info


def main():
    ap = argparse.ArgumentParser(description="sprite 假透明键控（棋盘格/白底 → 真 alpha）")
    ap.add_argument("image")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--sat-max", type=float, default=0.16)
    ap.add_argument("--val-min", type=float, default=0.72)
    ap.add_argument("--min-transparent", type=float, default=0.2,
                    help="键控后透明占比低于此值判废（背景根本没被键掉）")
    args = ap.parse_args()
    info = key_sprite(args.image, args.out, args.sat_max, args.val_min)
    ok = info["transparent_ratio"] >= args.min_transparent and "bbox" in info
    print("KEY %s -> %s" % ("OK" if ok else "FAIL", args.out))
    print("  透明占比 %.3f  bbox %s  锚点 %s  底边距 %s" % (
        info["transparent_ratio"], info.get("bbox"), info.get("anchor_px"), info.get("bottom_margin_px")))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
