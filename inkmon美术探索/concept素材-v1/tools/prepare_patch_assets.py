from __future__ import annotations

import argparse
import json
import math
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


TERRAINS = ("grass", "dirt", "stone", "water")
ELEVATIONS = (0, 1, 2)
DECOR_ASSETS = {
    "decor_pine": {"anchor_px": [256.0, 372.0]},
    "decor_pine_tall": {"anchor_px": [256.0, 404.0]},
    "decor_bush": {"anchor_px": [256.0, 324.0]},
    "decor_rocks": {"anchor_px": [256.0, 322.0]},
}
OUTPUT_SIZE = 512
ANCHOR_PX = (OUTPUT_SIZE * 0.5, OUTPUT_SIZE * 0.5)
PITCH_DEG = 35.26
YAW_DEG = -15.0
PX_PER_HEX_EDGE = 128.0


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root()).as_posix()
    except ValueError:
        return str(path.resolve())


def _face_poly(face: dict) -> list:
    return face.get("polygon_px") or face["quad_px"]


def is_border_background(rgb: np.ndarray) -> np.ndarray:
    values = rgb.astype(np.int16)
    max_channel = values.max(axis=2)
    min_channel = values.min(axis=2)
    luminance = (
        values[:, :, 0] * 0.2126
        + values[:, :, 1] * 0.7152
        + values[:, :, 2] * 0.0722
    )
    saturation = max_channel - min_channel
    return ((values[:, :, 0] > 232) & (values[:, :, 1] > 232) & (values[:, :, 2] > 232) & (saturation < 38)) | (
        (luminance > 244) & (saturation < 50)
    )


def flood_background_mask(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    rgb = np.asarray(rgba)[:, :, :3]
    candidates = is_border_background(rgb)
    height, width = candidates.shape
    visited = np.zeros((height, width), dtype=np.bool_)
    queue: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        if candidates[y, x] and not visited[y, x]:
            visited[y, x] = True
            queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)

    return Image.fromarray((visited.astype(np.uint8) * 255), mode="L")


def projected_hex_width() -> float:
    yaw = math.radians(YAW_DEG)
    xs: list[float] = []
    for index in range(6):
        angle = math.radians(60.0 * index)
        plane_x = math.cos(angle) * PX_PER_HEX_EDGE
        plane_y = math.sin(angle) * PX_PER_HEX_EDGE
        screen_x = math.cos(yaw) * plane_x - math.sin(yaw) * plane_y
        xs.append(screen_x)
    return max(xs) - min(xs)


def load_fit_origin_and_width(fit_path: Path) -> tuple[tuple[float, float], float]:
    if not fit_path.exists():
        raise FileNotFoundError(f"Missing fit sidecar for patch compose: {fit_path}")
    fit = json.loads(fit_path.read_text(encoding="utf-8"))
    origin = fit["origin_px"]
    top = fit["faces"]["top"]["polygon_px"]
    xs = [float(point[0]) for point in top]
    return (float(origin[0]), float(origin[1])), max(xs) - min(xs)


def make_transparent_patch(raw_path: Path, fit_path: Path, target_path: Path) -> dict:
    source = Image.open(raw_path).convert("RGBA")
    background = flood_background_mask(source)
    background = background.filter(ImageFilter.GaussianBlur(0.8))

    alpha = Image.eval(background, lambda value: 255 - value)
    prepared = source.copy()
    prepared.putalpha(alpha)

    origin, source_top_width = load_fit_origin_and_width(fit_path)
    scale = projected_hex_width() / source_top_width
    coeffs = (
        1.0 / scale,
        0.0,
        origin[0] - ANCHOR_PX[0] / scale,
        0.0,
        1.0 / scale,
        origin[1] - ANCHOR_PX[1] / scale,
    )
    result = prepared.transform(
        (OUTPUT_SIZE, OUTPUT_SIZE),
        Image.Transform.AFFINE,
        coeffs,
        resample=Image.Resampling.BICUBIC,
    )
    result = result.filter(ImageFilter.UnsharpMask(radius=0.7, percent=75, threshold=2))
    target_path.parent.mkdir(parents=True, exist_ok=True)
    result.save(target_path)
    return {
        "raw": _rel(raw_path),
        "fit_sidecar": _rel(fit_path),
        "output_patch": _rel(target_path),
        "origin_px": [origin[0], origin[1]],
        "source_top_width": source_top_width,
        "target_top_width": projected_hex_width(),
        "scale": scale,
        "anchor_px": [ANCHOR_PX[0], ANCHOR_PX[1]],
        "output_size_px": [OUTPUT_SIZE, OUTPUT_SIZE],
        "transform_coeffs": list(coeffs),
    }


def _draw_label(draw: ImageDraw.ImageDraw, xy: tuple[float, float], text: str) -> None:
    x, y = xy
    draw.rectangle((x - 3, y - 2, x + 8 + len(text) * 6, y + 11), fill=(255, 255, 255, 210))
    draw.text((x, y), text, fill=(32, 28, 22, 255), font=ImageFont.load_default())


def make_patch_fit_overlay(raw_path: Path, fit_path: Path, patch_path: Path, target_path: Path) -> dict:
    fit = json.loads(fit_path.read_text(encoding="utf-8"))
    raw = Image.open(raw_path).convert("RGBA")
    overlay = Image.new("RGBA", raw.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    polys: list[list] = []
    for face_name, face in fit["faces"].items():
        poly = _face_poly(face)
        polys.append(poly)
        if face_name == "top":
            color = (232, 45, 45, 255)
            width = 4
        elif face_name.startswith("bevel_"):
            color = (255, 160, 35, 235)
            width = 3
        else:
            color = (45, 111, 242, 235)
            width = 3
        draw.line([tuple(point) for point in poly + [poly[0]]], fill=color, width=width)

    all_points = [point for poly in polys for point in poly]
    bbox = [
        min(point[0] for point in all_points),
        min(point[1] for point in all_points),
        max(point[0] for point in all_points),
        max(point[1] for point in all_points),
    ]
    draw.rectangle(tuple(bbox), outline=(255, 215, 0, 255), width=3)
    origin = fit.get("origin_px")
    if origin:
        draw.ellipse((origin[0] - 8, origin[1] - 8, origin[0] + 8, origin[1] + 8), fill=(255, 215, 0, 255), outline=(45, 35, 0, 255), width=2)
        _draw_label(draw, (origin[0] + 12, origin[1] + 8), "origin")

    raw_overlay = Image.alpha_composite(raw, overlay)
    patch = Image.open(patch_path).convert("RGBA")
    patch_bg = Image.new("RGBA", patch.size, (236, 233, 224, 255))
    patch_bg.alpha_composite(patch)
    patch_draw = ImageDraw.Draw(patch_bg)
    patch_draw.rectangle((0, 0, OUTPUT_SIZE - 1, OUTPUT_SIZE - 1), outline=(45, 111, 242, 255), width=3)
    patch_draw.line((ANCHOR_PX[0] - 12, ANCHOR_PX[1], ANCHOR_PX[0] + 12, ANCHOR_PX[1]), fill=(232, 45, 45, 255), width=3)
    patch_draw.line((ANCHOR_PX[0], ANCHOR_PX[1] - 12, ANCHOR_PX[0], ANCHOR_PX[1] + 12), fill=(232, 45, 45, 255), width=3)
    _draw_label(patch_draw, (ANCHOR_PX[0] + 14, ANCHOR_PX[1] + 8), "anchor")

    canvas = Image.new("RGBA", (raw_overlay.width + patch_bg.width + 24, max(raw_overlay.height, patch_bg.height)), (246, 243, 235, 255))
    canvas.alpha_composite(raw_overlay, (0, 0))
    canvas.alpha_composite(patch_bg, (raw_overlay.width + 24, 0))
    target_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(target_path)
    return {
        "overlay": _rel(target_path),
        "bbox_px": [round(value, 3) for value in bbox],
        "origin_px": origin,
    }


def build_manifest() -> dict:
    assets: dict[str, dict] = {}
    for terrain in TERRAINS:
        for elevation in ELEVATIONS:
            key = f"tile_{terrain}_e{elevation}"
            filename = f"{key}_v0.png"
            assets[key] = {
                "file": filename,
                "variants": [filename],
                "kind": "tile",
                "terrain": terrain,
                "elevation": elevation,
                "anchor_px": [256.0, 256.0],
                "size_px": [OUTPUT_SIZE, OUTPUT_SIZE],
            }

    for key, meta in DECOR_ASSETS.items():
        filename = f"{key}.png"
        assets[key] = {
            "file": filename,
            "variants": [filename],
            "kind": "decor",
            "anchor_px": meta["anchor_px"],
            "size_px": [OUTPUT_SIZE, OUTPUT_SIZE],
        }

    return {
        "comment": "Concept patch assets generated from full 3D tile raw images and fitted to the fable patch anchor/scale contract. No fable textures or decor are referenced.",
        "pitch_deg": PITCH_DEG,
        "yaw_deg": YAW_DEG,
        "hex_orientation": "flat_top",
        "sun_elevation_deg": 50.0,
        "sun_azimuth_deg": -45.0,
        "px_per_unit": 128,
        "hex_edge_world": 1.0,
        "px_per_hex_edge": PX_PER_HEX_EDGE,
        "thickness_world": 0.55,
        "elevation_step_world": 0.5,
        "water_recess_world": 0.12,
        "assets": assets,
    }


def make_contact_sheet(asset_dir: Path, target_path: Path) -> None:
    cell = 300
    sheet = Image.new("RGBA", (cell * 4, cell * 3), (238, 235, 226, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()

    names = [f"{terrain}_e{elevation}" for terrain in TERRAINS for elevation in ELEVATIONS]
    for index, name in enumerate(names):
        x = (index % 4) * cell
        y = (index // 4) * cell
        path = asset_dir / f"tile_{name}_v0.png"
        tile = Image.open(path).convert("RGBA")
        tile.thumbnail((cell - 22, cell - 42), Image.Resampling.LANCZOS)
        sheet.alpha_composite(tile, (x + (cell - tile.width) // 2, y + 30 + (cell - 42 - tile.height) // 2))
        draw.text((x + 10, y + 8), name, fill=(20, 18, 14, 255), font=font)

    target_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(target_path)


def prepare(root: Path) -> None:
    raw_dir = root / "raw"
    asset_dir = root / "assets" / "baked"
    missing: list[Path] = []
    report: dict[str, dict] = {}

    for terrain in TERRAINS:
        for elevation in ELEVATIONS:
            key = f"{terrain}_e{elevation}"
            raw_path = raw_dir / f"{terrain}_e{elevation}_design_raw.png"
            if not raw_path.exists():
                missing.append(raw_path)
                continue
            fit_path = root / "beveled_uv" / "fit" / f"{terrain}_e{elevation}_beveled_design_fit.json"
            target_path = asset_dir / f"tile_{terrain}_e{elevation}_v0.png"
            tile_report = make_transparent_patch(raw_path, fit_path, target_path)
            overlay_path = root / "patch_fit_overlay" / f"{key}_patch_fit_overlay.png"
            tile_report.update(make_patch_fit_overlay(raw_path, fit_path, target_path, overlay_path))
            tile_report["source_script"] = _rel(Path(__file__))
            report[key] = tile_report

    if missing:
        joined = "\n".join(str(path) for path in missing)
        raise FileNotFoundError(f"Missing raw images:\n{joined}")

    manifest_path = asset_dir / "manifest.json"
    manifest_path.write_text(json.dumps(build_manifest(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (asset_dir / "patch_assets_report.json").write_text(
        json.dumps({
            "source_script": _rel(Path(__file__)),
            "output_dir": _rel(asset_dir),
            "manifest": _rel(manifest_path),
            "tiles": report,
        }, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    make_contact_sheet(asset_dir, root / "assets" / "concept_patch_contact.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    prepare(args.root.resolve())


if __name__ == "__main__":
    main()
