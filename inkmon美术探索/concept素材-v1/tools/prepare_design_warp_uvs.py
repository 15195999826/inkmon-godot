from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


TERRAINS = ("grass", "dirt", "stone", "water")
ELEVATIONS = (0, 1, 2)


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root()).as_posix()
    except ValueError:
        return str(path.resolve())


def _face_poly(face: dict) -> list:
    return face.get("polygon_px") or face["quad_px"]


def _draw_label(draw: ImageDraw.ImageDraw, xy: tuple[float, float], text: str) -> None:
    x, y = xy
    draw.rectangle((x - 3, y - 2, x + 8 + len(text) * 6, y + 11), fill=(255, 255, 255, 210))
    draw.text((x, y), text, fill=(32, 28, 22, 255), font=ImageFont.load_default())


def make_fit_overlay(raw_path: Path, design_sidecar: dict, target_path: Path) -> dict:
    image = Image.open(raw_path).convert("RGBA")
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    polys: list[list] = []
    for face_name, face in design_sidecar["faces"].items():
        poly = _face_poly(face)
        polys.append(poly)
        color = (232, 45, 45, 255) if face_name == "top" else (45, 111, 242, 235)
        width = 4 if face_name == "top" else 3
        draw.line([tuple(point) for point in poly + [poly[0]]], fill=color, width=width)
        cx = sum(point[0] for point in poly) / len(poly)
        cy = sum(point[1] for point in poly) / len(poly)
        _draw_label(draw, (cx, cy), face_name)

    all_points = [point for poly in polys for point in poly]
    bbox = [
        min(point[0] for point in all_points),
        min(point[1] for point in all_points),
        max(point[0] for point in all_points),
        max(point[1] for point in all_points),
    ]
    draw.rectangle(tuple(bbox), outline=(255, 180, 30, 255), width=3)
    origin = design_sidecar.get("origin_px")
    if origin:
        x, y = origin
        draw.ellipse((x - 7, y - 7, x + 7, y + 7), fill=(255, 215, 0, 255), outline=(45, 35, 0, 255), width=2)
        _draw_label(draw, (x + 10, y + 8), "origin")

    composed = Image.alpha_composite(image, overlay)
    target_path.parent.mkdir(parents=True, exist_ok=True)
    composed.convert("RGB").save(target_path)
    return {
        "overlay": _rel(target_path),
        "bbox_px": [round(value, 3) for value in bbox],
        "origin_px": design_sidecar.get("origin_px"),
    }


def prepare(root: Path, out_dir: Path) -> None:
    scripts_dir = repo_root() / "blender" / "scripts"
    if str(scripts_dir) not in sys.path:
        sys.path.insert(0, str(scripts_dir))

    from texgen import warp  # noqa: PLC0415

    raw_dir = root / "raw"
    out_dir.mkdir(parents=True, exist_ok=True)
    report: dict[str, dict] = {}
    missing: list[Path] = []
    overlay_dir = root / "fit_overlay"

    for terrain in TERRAINS:
        for elevation in ELEVATIONS:
            key = f"{terrain}_e{elevation}"
            raw_path = raw_dir / f"{key}_design_raw.png"
            if not raw_path.exists():
                missing.append(raw_path)
                continue
            design_sidecar = warp.load_sidecar(warp.default_sidecar("design", elevation))
            uv_sidecar = warp.load_sidecar(warp.default_sidecar("uv", elevation))
            out_path = out_dir / f"{key}_warp_uv.png"
            overlay_path = overlay_dir / f"{key}_fit_overlay.png"
            overlay_report = make_fit_overlay(raw_path, design_sidecar, overlay_path)
            report[key] = {
                "source_script": _rel(Path(__file__)),
                "raw": _rel(raw_path),
                "uv": _rel(out_path),
                "design_sidecar": _rel(Path(warp.default_sidecar("design", elevation))),
                "uv_sidecar": _rel(Path(warp.default_sidecar("uv", elevation))),
                "overlay": overlay_report["overlay"],
                "bbox_px": overlay_report["bbox_px"],
                "origin_px": overlay_report["origin_px"],
                "warp": warp.warp_design_to_uv(str(raw_path), design_sidecar, uv_sidecar, str(out_path)),
            }

    if missing:
        joined = "\n".join(str(path) for path in missing)
        raise FileNotFoundError(f"Missing raw images:\n{joined}")

    (out_dir / "design_warp_uv_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--out-dir", type=Path, default=None)
    args = parser.parse_args()
    root = args.root.resolve()
    prepare(root, (args.out_dir or root / "uv").resolve())


if __name__ == "__main__":
    main()
