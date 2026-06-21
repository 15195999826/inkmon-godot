from __future__ import annotations

import argparse
import json
import math
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


def _load_modules():
    scripts_dir = repo_root() / "blender" / "scripts"
    if str(scripts_dir) not in sys.path:
        sys.path.insert(0, str(scripts_dir))
    from texgen import beveled_tile_prototype as proto  # noqa: PLC0415
    from texgen import geometry  # noqa: PLC0415
    return proto, geometry


def _face_poly(face: dict) -> list:
    return face.get("polygon_px") or face["quad_px"]


def _draw_label(draw: ImageDraw.ImageDraw, xy: tuple[float, float], text: str) -> None:
    x, y = xy
    draw.rectangle((x - 3, y - 2, x + 8 + len(text) * 6, y + 11), fill=(255, 255, 255, 210))
    draw.text((x, y), text, fill=(32, 28, 22, 255), font=ImageFont.load_default())


def make_fit_overlay(raw_path: Path, fitted_sidecar: dict, target_path: Path) -> dict:
    image = Image.open(raw_path).convert("RGBA")
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    polys: list[list] = []
    for face_name, face in fitted_sidecar["faces"].items():
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
        cx = sum(point[0] for point in poly) / len(poly)
        cy = sum(point[1] for point in poly) / len(poly)
        if face_name == "top" or face_name.startswith("wall_"):
            _draw_label(draw, (cx, cy), face_name)

    all_points = [point for poly in polys for point in poly]
    bbox = [
        min(point[0] for point in all_points),
        min(point[1] for point in all_points),
        max(point[0] for point in all_points),
        max(point[1] for point in all_points),
    ]
    draw.rectangle(tuple(bbox), outline=(255, 215, 0, 255), width=3)
    origin = fitted_sidecar.get("origin_px")
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
        "origin_px": fitted_sidecar.get("origin_px"),
    }


def _bevel_world(manifest: dict, elevation: int, proto, geometry) -> dict:
    edge = float(manifest["hex_edge_world"])
    depth = geometry.tile_depth(manifest, elevation)
    radial_shrink = proto.BEVEL_INSET_WORLD / math.cos(math.radians(30.0))
    inner_edge = max(0.01, edge - radial_shrink)
    inner = [(x, y, 0.0) for x, y in [geometry.hex_corner(i, inner_edge) for i in range(6)]]
    outer = [(x, y, -proto.BEVEL_DROP_WORLD) for x, y in [geometry.hex_corner(i, edge) for i in range(6)]]
    bottom = [(x, y, -depth) for x, y in [geometry.hex_corner(i, edge) for i in range(6)]]
    return {
        "inner": inner,
        "outer": outer,
        "bottom": bottom,
        "inner_edge_world": inner_edge,
        "outer_edge_world": edge,
        "depth_world": depth,
    }


def _visible_wall_order(manifest: dict, geometry) -> list[int]:
    return [int(i) for i in geometry.visible_walls(manifest)]


def _world_faces(manifest: dict, elevation: int, proto, geometry) -> dict:
    w = _bevel_world(manifest, elevation, proto, geometry)
    faces = {"top": w["inner"]}
    for i in range(6):
        faces[f"bevel_{i}"] = [
            w["inner"][i],
            w["inner"][(i + 1) % 6],
            w["outer"][(i + 1) % 6],
            w["outer"][i],
        ]
    for i in _visible_wall_order(manifest, geometry):
        faces[f"wall_{i}"] = [
            w["outer"][i],
            w["outer"][(i + 1) % 6],
            w["bottom"][(i + 1) % 6],
            w["bottom"][i],
        ]
    return faces


def design_layout(manifest: dict, elevation: int, proto, geometry) -> dict:
    world_faces = _world_faces(manifest, elevation, proto, geometry)
    project = geometry.projector(manifest)
    cw, ch = geometry.DESIGN_CANVAS

    all_pts = []
    for poly in world_faces.values():
        all_pts.extend(project(*point) for point in poly)
    xs = [point[0] for point in all_pts]
    ys = [point[1] for point in all_pts]
    scale = min(
        (cw - 2 * geometry.DESIGN_MARGIN) / (max(xs) - min(xs)),
        (ch - 2 * geometry.DESIGN_MARGIN) / (max(ys) - min(ys)),
    )
    ox = cw * 0.5 - (min(xs) + max(xs)) * 0.5 * scale
    oy = ch * 0.5 - (min(ys) + max(ys)) * 0.5 * scale

    def to_px(point):
        sx, sy = project(*point)
        return [sx * scale + ox, sy * scale + oy]

    faces = {}
    for name, poly in world_faces.items():
        key = "polygon_px" if name == "top" else "quad_px"
        faces[name] = {key: [to_px(point) for point in poly]}
    w = _bevel_world(manifest, elevation, proto, geometry)
    return {
        "template": "concept_beveled_design",
        "elevation": elevation,
        "canvas": [cw, ch],
        "scale_px_per_unit": scale,
        "origin_px": [ox, oy],
        "bevel_inset_world": proto.BEVEL_INSET_WORLD,
        "bevel_drop_world": proto.BEVEL_DROP_WORLD,
        "inner_edge_world": w["inner_edge_world"],
        "faces": faces,
        "wall_order": _visible_wall_order(manifest, geometry),
        "manifest": geometry._manifest_excerpt(manifest),
    }


def uv_layout(manifest: dict, elevation: int, proto, geometry) -> dict:
    cw, ch = geometry.UV_CANVAS
    s = geometry.UV_PX_PER_UNIT
    w = _bevel_world(manifest, elevation, proto, geometry)
    order = _visible_wall_order(manifest, geometry)

    def img(x, y):
        return (x * s, -y * s)

    inner2 = [img(point[0], point[1]) for point in w["inner"]]
    outer2 = [img(point[0], point[1]) for point in w["outer"]]
    faces = {"top": {"polygon_px": inner2}}

    for i in range(6):
        faces[f"bevel_{i}"] = {
            "quad_px": [inner2[i], inner2[(i + 1) % 6], outer2[(i + 1) % 6], outer2[i]]
        }

    wall_depth = w["depth_world"] - proto.BEVEL_DROP_WORLD
    for i in order:
        a = (w["outer"][i][0], w["outer"][i][1])
        b = (w["outer"][(i + 1) % 6][0], w["outer"][(i + 1) % 6][1])
        normal_angle = math.radians(60.0 * i + 30.0)
        nx = math.cos(normal_angle) * wall_depth
        ny = math.sin(normal_angle) * wall_depth
        faces[f"wall_{i}"] = {
            "quad_px": [img(*a), img(*b), img(b[0] + nx, b[1] + ny), img(a[0] + nx, a[1] + ny)]
        }

    all_pts = []
    for face in faces.values():
        all_pts.extend(_face_poly(face))
    min_x = min(point[0] for point in all_pts)
    max_x = max(point[0] for point in all_pts)
    min_y = min(point[1] for point in all_pts)
    max_y = max(point[1] for point in all_pts)
    ox = cw * 0.5 - (min_x + max_x) * 0.5
    oy = ch * 0.5 - (min_y + max_y) * 0.5

    def shift(poly):
        return [[point[0] + ox, point[1] + oy] for point in poly]

    out_faces = {}
    for name, face in faces.items():
        key = "polygon_px" if name == "top" else "quad_px"
        out_faces[name] = {key: shift(_face_poly(face))}
    out_faces["top"]["center_px"] = [ox, oy]
    out_faces["top"]["px_per_unit"] = s

    return {
        "template": "concept_beveled_uv",
        "layout": "beveled_net_v1",
        "elevation": elevation,
        "canvas": [cw, ch],
        "px_per_unit": s,
        "bevel_inset_world": proto.BEVEL_INSET_WORLD,
        "bevel_drop_world": proto.BEVEL_DROP_WORLD,
        "faces": out_faces,
        "bevel_order": list(range(6)),
        "wall_order": order,
        "manifest": geometry._manifest_excerpt(manifest),
    }


def prepare(root: Path, out_dir: Path, bevel_inset_world: float | None = None, bevel_drop_world: float | None = None) -> None:
    proto, geometry = _load_modules()
    if bevel_inset_world is not None:
        proto.BEVEL_INSET_WORLD = bevel_inset_world
    if bevel_drop_world is not None:
        proto.BEVEL_DROP_WORLD = bevel_drop_world
    manifest = geometry.load_manifest()
    raw_dir = root / "raw"
    out_dir.mkdir(parents=True, exist_ok=True)
    report: dict[str, dict] = {}
    missing: list[Path] = []
    overlay_dir = out_dir / "fit_overlay"

    sidecar_dir = out_dir / "sidecars"
    sidecar_dir.mkdir(parents=True, exist_ok=True)
    for elevation in ELEVATIONS:
        design = design_layout(manifest, elevation, proto, geometry)
        uv = uv_layout(manifest, elevation, proto, geometry)
        (sidecar_dir / f"beveled_design_e{elevation}.json").write_text(
            json.dumps(design, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        (sidecar_dir / f"beveled_uv_e{elevation}.json").write_text(
            json.dumps(uv, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    for terrain in TERRAINS:
        for elevation in ELEVATIONS:
            key = f"{terrain}_e{elevation}"
            raw_path = raw_dir / f"{key}_design_raw.png"
            if not raw_path.exists():
                missing.append(raw_path)
                continue
            design = json.loads((sidecar_dir / f"beveled_design_e{elevation}.json").read_text(encoding="utf-8"))
            uv = json.loads((sidecar_dir / f"beveled_uv_e{elevation}.json").read_text(encoding="utf-8"))
            fitted = proto._fit_layout_to_image(design, raw_path)
            fit_path = out_dir / "fit" / f"{key}_beveled_design_fit.json"
            fit_path.parent.mkdir(parents=True, exist_ok=True)
            fit_path.write_text(json.dumps(fitted, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            uv_path = out_dir / f"{key}_beveled_uv.png"
            overlay_path = overlay_dir / f"{key}_beveled_fit_overlay.png"
            overlay_report = make_fit_overlay(raw_path, fitted, overlay_path)
            warp_report = proto._warp_design_to_uv(raw_path, fitted, uv, uv_path)
            report[key] = {
                "source_script": _rel(Path(__file__)),
                "design": _rel(raw_path),
                "uv": _rel(uv_path),
                "design_sidecar": _rel(sidecar_dir / f"beveled_design_e{elevation}.json"),
                "uv_sidecar": _rel(sidecar_dir / f"beveled_uv_e{elevation}.json"),
                "fit_sidecar": _rel(fit_path),
                "overlay": overlay_report["overlay"],
                "bbox_px": overlay_report["bbox_px"],
                "origin_px": overlay_report["origin_px"],
                "bevel_inset_world": proto.BEVEL_INSET_WORLD,
                "bevel_drop_world": proto.BEVEL_DROP_WORLD,
                "faces": warp_report.get("faces", {}),
                "fit": warp_report.get("fit", {}),
            }

    if missing:
        joined = "\n".join(str(path) for path in missing)
        raise FileNotFoundError(f"Missing raw images:\n{joined}")

    (out_dir / "beveled_uv_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--out-dir", type=Path, default=None)
    parser.add_argument("--bevel-inset-world", type=float, default=None)
    parser.add_argument("--bevel-drop-world", type=float, default=None)
    args = parser.parse_args()
    root = args.root.resolve()
    prepare(
        root,
        (args.out_dir or root / "beveled_uv").resolve(),
        bevel_inset_world=args.bevel_inset_world,
        bevel_drop_world=args.bevel_drop_world,
    )


if __name__ == "__main__":
    main()
