from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path
from shutil import copy2

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


DECORS = {
    "decor_pine": {"target_height": 300, "anchor_px": [256.0, 372.0]},
    "decor_pine_tall": {"target_height": 360, "anchor_px": [256.0, 404.0]},
    "decor_bush": {"target_height": 170, "anchor_px": [256.0, 324.0]},
    "decor_rocks": {"target_height": 150, "anchor_px": [256.0, 322.0]},
}
CANVAS = 512


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def is_border_background(rgb: np.ndarray) -> np.ndarray:
    values = rgb.astype(np.int16)
    max_channel = values.max(axis=2)
    min_channel = values.min(axis=2)
    saturation = max_channel - min_channel
    luminance = (
        values[:, :, 0] * 0.2126
        + values[:, :, 1] * 0.7152
        + values[:, :, 2] * 0.0722
    )
    return ((values[:, :, 0] > 232) & (values[:, :, 1] > 232) & (values[:, :, 2] > 232) & (saturation < 44)) | (
        (luminance > 246) & (saturation < 55)
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


def prepare_one(raw_path: Path, out_path: Path, target_height: int, anchor_px: list[float]) -> None:
    source = Image.open(raw_path).convert("RGBA")
    background = flood_background_mask(source).filter(ImageFilter.GaussianBlur(0.8))
    alpha = Image.eval(background, lambda value: 255 - value)
    source.putalpha(alpha)
    bbox = source.getbbox()
    if bbox is None:
        raise ValueError(f"empty decor after alpha cleanup: {raw_path}")
    cropped = source.crop(bbox)
    scale = target_height / max(cropped.height, 1)
    resized = cropped.resize((max(1, round(cropped.width * scale)), target_height), Image.Resampling.LANCZOS)
    resized = resized.filter(ImageFilter.UnsharpMask(radius=0.65, percent=70, threshold=2))

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    left = round(anchor_px[0] - resized.width * 0.5)
    top = round(anchor_px[1] - resized.height)
    canvas.alpha_composite(resized, (left, top))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path)


def baked_dirs(root: Path) -> list[Path]:
    art_root = root.parent
    return [
        root / "assets" / "baked",
        art_root / "codex-硬边-v1" / "assets" / "concept-baked",
        art_root / "codex-硬边-v1" / "assets" / "concept-baked-ink",
        art_root / "codex-倒角-v1" / "assets" / "concept-baked",
        art_root / "codex-倒角-v1" / "assets" / "concept-baked-ink",
        art_root / "codex-倒角-v1" / "assets" / "concept-baked-wide-rim",
    ]


def inject_manifest(manifest_path: Path) -> None:
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    assets = data.setdefault("assets", {})
    for name, meta in DECORS.items():
        filename = f"{name}.png"
        assets[name] = {
            "file": filename,
            "variants": [filename],
            "kind": "decor",
            "anchor_px": meta["anchor_px"],
            "size_px": [CANVAS, CANVAS],
        }
    manifest_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def make_contact(processed_dir: Path, out_path: Path) -> None:
    cell = 250
    sheet = Image.new("RGBA", (cell * 4, cell), (238, 235, 226, 255))
    draw = ImageDraw.Draw(sheet)
    for index, name in enumerate(DECORS):
        image = Image.open(processed_dir / f"{name}.png").convert("RGBA")
        image.thumbnail((cell - 20, cell - 38), Image.Resampling.LANCZOS)
        x = index * cell + (cell - image.width) // 2
        y = 30 + (cell - 38 - image.height) // 2
        sheet.alpha_composite(image, (x, y))
        draw.text((index * cell + 10, 8), name, fill=(20, 18, 14, 255))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(out_path)


def prepare(root: Path) -> None:
    raw_dir = root / "decor_raw"
    processed_dir = root / "decor_processed"
    processed_dir.mkdir(parents=True, exist_ok=True)
    for name, meta in DECORS.items():
        raw_path = raw_dir / f"{name}_raw.png"
        if not raw_path.exists():
            raise FileNotFoundError(raw_path)
        prepare_one(raw_path, processed_dir / f"{name}.png", meta["target_height"], meta["anchor_px"])

    make_contact(processed_dir, root / "decor_processed_contact.png")

    for target_dir in baked_dirs(root):
        manifest_path = target_dir / "manifest.json"
        if not manifest_path.exists():
            continue
        for name in DECORS:
            copy2(processed_dir / f"{name}.png", target_dir / f"{name}.png")
        inject_manifest(manifest_path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    prepare(args.root.resolve())


if __name__ == "__main__":
    main()
