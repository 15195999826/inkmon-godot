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


def make_transparent_patch(raw_path: Path, fit_path: Path, target_path: Path) -> None:
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

    for terrain in TERRAINS:
        for elevation in ELEVATIONS:
            raw_path = raw_dir / f"{terrain}_e{elevation}_design_raw.png"
            if not raw_path.exists():
                missing.append(raw_path)
                continue
            fit_path = root / "beveled_uv" / "fit" / f"{terrain}_e{elevation}_beveled_design_fit.json"
            target_path = asset_dir / f"tile_{terrain}_e{elevation}_v0.png"
            make_transparent_patch(raw_path, fit_path, target_path)

    if missing:
        joined = "\n".join(str(path) for path in missing)
        raise FileNotFoundError(f"Missing raw images:\n{joined}")

    manifest_path = asset_dir / "manifest.json"
    manifest_path.write_text(json.dumps(build_manifest(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    make_contact_sheet(asset_dir, root / "assets" / "concept_patch_contact.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    prepare(args.root.resolve())


if __name__ == "__main__":
    main()
