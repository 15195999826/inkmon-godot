# texgen.line_clean — remove/fade UV seam guide lines before Blender bake
#
# Geometry QC still runs on the raw generated/extracted UV. This tool is a
# bake-only cleanup step: keep the generated material, but stop template hinge
# lines from becoming albedo seams on the 3D tile.

import argparse
import json
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


DEFAULT_LINE_WIDTH = 10
DEFAULT_SAMPLE_OFFSET = 8


def _face_poly(face: dict) -> list:
    return face.get("polygon_px") or face["quad_px"]


def _edge_key(a, b):
    pa = (round(a[0], 1), round(a[1], 1))
    pb = (round(b[0], 1), round(b[1], 1))
    return (pa, pb) if pa <= pb else (pb, pa)


def _polygon_centroid(poly: list) -> tuple:
    return (
        sum(p[0] for p in poly) / max(1, len(poly)),
        sum(p[1] for p in poly) / max(1, len(poly)),
    )


def _line_mask(size: tuple, a, b, width: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).line([tuple(a), tuple(b)], fill=255, width=width)
    return mask


def _poly_mask(size: tuple, poly: list) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon([tuple(p) for p in poly], fill=255)
    return mask


def _face_polygons(sidecar: dict) -> dict:
    if "faces" not in sidecar:
        raise ValueError("line_clean requires a UV sidecar with faces")
    return {name: _face_poly(face) for name, face in sidecar["faces"].items()}


def _internal_edges(polygons: dict) -> list:
    seen = {}
    for name, poly in polygons.items():
        for idx, a in enumerate(poly):
            b = poly[(idx + 1) % len(poly)]
            key = _edge_key(a, b)
            seen.setdefault(key, []).append({"face": name, "a": a, "b": b})
    return [items for items in seen.values() if len(items) >= 2]


def _outer_edges(polygons: dict) -> list:
    seen = {}
    for name, poly in polygons.items():
        for idx, a in enumerate(poly):
            b = poly[(idx + 1) % len(poly)]
            key = _edge_key(a, b)
            seen.setdefault(key, []).append({"face": name, "a": a, "b": b})
    return [items for items in seen.values() if len(items) == 1]


def _wall_index(name: str) -> int:
    if not name.startswith("wall_"):
        raise ValueError("not a wall face: %s" % name)
    return int(name.removeprefix("wall_"))


def _wall_stitch_edges(polygons: dict, wall_order: list) -> list:
    """Return UV side edges that are separate in the net but stitched in 3D.

    For consecutive visible walls, the shared 3D vertical edge appears as two
    UV side edges: previous wall right side and next wall left side. These are
    not outer outline strokes and should not become double-black baked seams.
    """
    out = []
    ordered_names = ["wall_%d" % int(i) for i in wall_order]
    for left_name, right_name in zip(ordered_names, ordered_names[1:]):
        if left_name not in polygons or right_name not in polygons:
            continue
        if (_wall_index(left_name) + 1) % 6 != _wall_index(right_name):
            continue
        left_poly = polygons[left_name]
        right_poly = polygons[right_name]
        out.append([
            {"face": left_name, "a": left_poly[1], "b": left_poly[2], "kind": "wall_stitch_right"},
            {"face": right_name, "a": right_poly[0], "b": right_poly[3], "kind": "wall_stitch_left"},
        ])
    return out


def _sample_face_pixel(
    src: np.ndarray,
    face_mask: np.ndarray,
    line_mask: np.ndarray,
    x: int,
    y: int,
    nx: float,
    ny: float,
    sample_offset: int,
):
    h, w = face_mask.shape
    for dist in range(sample_offset, sample_offset + 28):
        sx = int(round(x + nx * dist))
        sy = int(round(y + ny * dist))
        if sx < 0 or sy < 0 or sx >= w or sy >= h:
            continue
        if face_mask[sy, sx] and not line_mask[sy, sx]:
            return src[sy, sx]
    return None


def repair_internal_lines(
    image: Image.Image,
    sidecar: dict,
    line_width: int = DEFAULT_LINE_WIDTH,
    sample_offset: int = DEFAULT_SAMPLE_OFFSET,
    include_outer: bool = False,
) -> tuple:
    rgba = image.convert("RGBA")
    src = np.array(rgba)
    repaired = src.copy()
    h, w = src.shape[:2]
    size = (w, h)

    polygons = _face_polygons(sidecar)
    face_masks = {
        name: np.array(_poly_mask(size, poly), dtype=np.uint8) > 0
        for name, poly in polygons.items()
    }
    shared_edges = _internal_edges(polygons)
    stitch_edges = _wall_stitch_edges(polygons, sidecar.get("wall_order", []))
    outer_edges = _outer_edges(polygons) if include_outer else []
    edges = shared_edges + stitch_edges + outer_edges
    global_mask = np.zeros((h, w), dtype=bool)
    touched_pixels = 0
    missed_pixels = 0

    for edge_faces in edges:
        a = edge_faces[0]["a"]
        b = edge_faces[0]["b"]
        base_line = np.array(_line_mask(size, a, b, line_width), dtype=np.uint8) > 0
        global_mask |= base_line
        mid = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)

        for item in edge_faces:
            face = item["face"]
            poly = polygons[face]
            cx, cy = _polygon_centroid(poly)
            vx, vy = cx - mid[0], cy - mid[1]
            mag = max((vx * vx + vy * vy) ** 0.5, 0.0001)
            nx, ny = vx / mag, vy / mag
            write_mask = base_line & face_masks[face]
            ys, xs = np.where(write_mask)
            for x, y in zip(xs, ys):
                sample = _sample_face_pixel(
                    src, face_masks[face], base_line, int(x), int(y), nx, ny, sample_offset
                )
                if sample is None:
                    missed_pixels += 1
                    continue
                repaired[y, x] = sample
                touched_pixels += 1

    return Image.fromarray(repaired, "RGBA"), global_mask, {
        "internal_edge_count": len(shared_edges),
        "wall_stitch_seam_count": len(stitch_edges),
        "outer_edge_count": len(outer_edges),
        "cleaned_line_count": len(edges),
        "line_width": line_width,
        "sample_offset": sample_offset,
        "line_mask_pixels": int(global_mask.sum()),
        "touched_pixels": touched_pixels,
        "missed_pixels": missed_pixels,
    }


def fade_lines(original: Image.Image, repaired: Image.Image, mask: np.ndarray, original_weight: float) -> Image.Image:
    src = np.array(original.convert("RGBA")).astype(np.float32)
    rep = np.array(repaired.convert("RGBA")).astype(np.float32)
    out = src.copy()
    out[mask] = rep[mask] * (1.0 - original_weight) + src[mask] * original_weight
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def clean_variants(image_path: str, sidecar_path: str, out_dir: str, line_width: int, sample_offset: int) -> dict:
    with open(sidecar_path, "r", encoding="utf-8") as f:
        sidecar = json.load(f)
    image = Image.open(image_path)
    if tuple(image.size) != tuple(sidecar["canvas"]):
        raise ValueError("image size %s != sidecar canvas %s" % (image.size, sidecar["canvas"]))

    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    repaired, mask, report = repair_internal_lines(image, sidecar, line_width, sample_offset)
    repaired_all, mask_all, report_all = repair_internal_lines(
        image, sidecar, line_width, sample_offset, include_outer=True
    )

    paths = {
        "keep_lines": out / "keep_lines.png",
        "fade_internal_25": out / "fade_internal_25.png",
        "remove_internal": out / "remove_internal.png",
        "fade_all_guides_25": out / "fade_all_guides_25.png",
        "remove_all_guides": out / "remove_all_guides.png",
    }
    image.save(paths["keep_lines"])
    fade_lines(image, repaired, mask, 0.25).save(paths["fade_internal_25"])
    repaired.save(paths["remove_internal"])
    fade_lines(image, repaired_all, mask_all, 0.25).save(paths["fade_all_guides_25"])
    repaired_all.save(paths["remove_all_guides"])

    report.update({
        "all_guides": report_all,
        "image": os.path.abspath(image_path),
        "sidecar": os.path.abspath(sidecar_path),
        "outputs": {k: str(v) for k, v in paths.items()},
        "note": "cleaned UVs are bake inputs only; run geometry QC on the raw generated/extracted UV",
    })
    return report


def main():
    ap = argparse.ArgumentParser(description="Create bake-only UV variants with internal hinge guide lines faded/removed")
    ap.add_argument("image", help="standard UV image, usually warp.py dual output")
    ap.add_argument("--sidecar", required=True, help="template_uv_e<N>.json")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--line-width", type=int, default=DEFAULT_LINE_WIDTH)
    ap.add_argument("--sample-offset", type=int, default=DEFAULT_SAMPLE_OFFSET)
    ap.add_argument("--report", default=None, help="optional JSON report path")
    args = ap.parse_args()

    report = clean_variants(args.image, args.sidecar, args.out_dir, args.line_width, args.sample_offset)
    if args.report:
        Path(args.report).parent.mkdir(parents=True, exist_ok=True)
        with open(args.report, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
