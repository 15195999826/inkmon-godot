# texgen.atlas_bleed — fill white/transparent guide gaps inside atlas masks
#
# Candidate-only postprocess. It does not change geometry QC; it prevents
# Blender from sampling white template background where the AI did not paint to
# the atlas guide boundary.

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


def _face_poly(face: dict) -> list:
    return face.get("polygon_px") or face["quad_px"]


def _poly_mask(size: tuple, poly: list) -> np.ndarray:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon([tuple(p) for p in poly], fill=255)
    return np.array(mask, dtype=np.uint8) > 0


def _neighbor_sum(arr: np.ndarray, valid: np.ndarray):
    total = np.zeros_like(arr, dtype=np.float32)
    count = np.zeros(valid.shape, dtype=np.float32)
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
        shifted_arr = np.roll(arr, (dy, dx), axis=(0, 1))
        shifted_valid = np.roll(valid, (dy, dx), axis=(0, 1))
        if dy < 0:
            shifted_valid[dy:, :] = False
        elif dy > 0:
            shifted_valid[:dy, :] = False
        if dx < 0:
            shifted_valid[:, dx:] = False
        elif dx > 0:
            shifted_valid[:, :dx] = False
        total += shifted_arr * shifted_valid[..., None]
        count += shifted_valid.astype(np.float32)
    return total, count


def _erode(mask: np.ndarray, steps: int) -> np.ndarray:
    out = mask.copy()
    for _ in range(max(0, steps)):
        up = np.roll(out, -1, axis=0)
        down = np.roll(out, 1, axis=0)
        left = np.roll(out, -1, axis=1)
        right = np.roll(out, 1, axis=1)
        up[-1, :] = False
        down[0, :] = False
        left[:, -1] = False
        right[:, 0] = False
        out = out & up & down & left & right
    return out


def bleed_atlas(
    image_path: str,
    sidecar_path: str,
    out_path: str,
    max_iters: int = 260,
    boundary_width: int = 18,
) -> dict:
    sidecar = json.loads(Path(sidecar_path).read_text(encoding="utf-8"))
    image = Image.open(image_path).convert("RGBA")
    if tuple(image.size) != tuple(sidecar["canvas"]):
        raise ValueError("image size %s != sidecar canvas %s" % (image.size, sidecar["canvas"]))

    arr = np.array(image).astype(np.float32)
    rgb = arr[..., :3]
    alpha = arr[..., 3]
    brightness = rgb.mean(axis=2)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    whiteish = (rgb[..., 0] > 224) & (rgb[..., 1] > 224) & (rgb[..., 2] > 210)
    guideish = (brightness > 175) & (chroma < 55)
    invalid_base = (alpha < 8) | whiteish
    total_filled = 0
    per_face = {}

    for name, face in sidecar["faces"].items():
        mask = _poly_mask(image.size, _face_poly(face))
        boundary = mask & ~_erode(mask, boundary_width)
        boundary_guide = boundary & guideish
        invalid = invalid_base | guideish
        valid = mask & ~invalid
        missing = mask & ~valid
        filled = 0
        for _ in range(max_iters):
            targets = missing & ~valid
            if not targets.any():
                break
            total, count = _neighbor_sum(arr, valid)
            can_fill = targets & (count > 0)
            if not can_fill.any():
                break
            arr[can_fill] = total[can_fill] / count[can_fill][..., None]
            arr[can_fill, 3] = 255
            valid |= can_fill
            missing &= ~can_fill
            filled += int(can_fill.sum())
        total_filled += filled
        per_face[name] = {
            "filled_pixels": filled,
            "remaining_pixels": int((mask & ~valid).sum()),
            "boundary_pixels": int(boundary.sum()),
            "boundary_guide_pixels": int(boundary_guide.sum()),
            "guide_pixels": int((mask & guideish).sum()),
        }

    # Keep only declared atlas masks opaque; outside is transparent.
    all_masks = np.zeros(alpha.shape, dtype=bool)
    for face in sidecar["faces"].values():
        all_masks |= _poly_mask(image.size, _face_poly(face))
    arr[~all_masks, 3] = 0
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA").save(out_path)
    return {
        "filled_pixels": total_filled,
        "boundary_width": boundary_width,
        "faces": per_face,
        "out": str(Path(out_path).resolve()),
    }


def main():
    ap = argparse.ArgumentParser(description="Bleed atlas materials into white/transparent guide gaps")
    ap.add_argument("image")
    ap.add_argument("--sidecar", required=True)
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--report", default=None)
    ap.add_argument("--boundary-width", type=int, default=18)
    args = ap.parse_args()
    report = bleed_atlas(args.image, args.sidecar, args.out, boundary_width=args.boundary_width)
    if args.report:
        Path(args.report).parent.mkdir(parents=True, exist_ok=True)
        Path(args.report).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
