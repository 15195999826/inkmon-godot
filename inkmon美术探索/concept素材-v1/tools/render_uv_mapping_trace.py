from __future__ import annotations

import argparse
import json
import math
import shutil
import sys
import time
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


TERRAINS = ("grass", "dirt", "stone", "water")
ELEVATIONS = (0, 1, 2)
TRACE_STEPS = (
    ("mapping", "source template -> UV islands"),
    ("source_cuts", "source face cuts"),
    ("normalized", "normalized face cuts"),
    ("uv_compose", "composed UV"),
)
NORMALIZE_ROUTE = "render_uv_mapping_trace._normalize_face -> texgen.warp.warp_polygon_piecewise -> texgen.warp._bleed_source_polygon -> texgen.geometry.polygon_triangle_correspondences -> texgen.warp.affine_coeffs -> texgen.warp._clean_output_polygon_edge"


FACE_COLORS = {
    "top": (228, 54, 54, 255),
    "wall_3": (40, 105, 235, 255),
    "wall_4": (25, 157, 178, 255),
    "wall_5": (124, 73, 206, 255),
}
BEVEL_COLORS = (
    (229, 132, 37, 255),
    (213, 105, 48, 255),
    (190, 82, 70, 255),
    (170, 114, 44, 255),
    (206, 150, 45, 255),
    (224, 96, 39, 255),
)
BG = (245, 241, 233, 255)
PANEL_BG = (238, 232, 220, 255)
TEXT = (52, 45, 37, 255)
MUTED = (112, 99, 82, 255)
VERTEX_RED = (255, 70, 45, 240)
INTERNAL_VERTEX = (19, 204, 220, 245)
VERTEX_TEXT = (38, 30, 24, 255)
AUTO_FIT_POINT_ORDER = {
    "1": "top[2]",
    "2": "top[1]",
    "3": "top[0]",
    "4": "wall_5[2]",
    "5": "wall_5[3]",
    "6": "wall_4[3]",
    "7": "wall_3[3]",
    "8": "top[3]",
    "9": "top[4] predicted internal",
    "10": "top[5] predicted internal",
}


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def concept_root(repo: Path) -> Path:
    return repo / "inkmon美术探索" / "concept素材-v1"


def _rel(repo: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(repo.resolve()).as_posix()
    except ValueError:
        return str(path.resolve())


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _face_poly(face: dict) -> list[list[float]]:
    return face.get("polygon_px") or face["quad_px"]


def _color(face: str) -> tuple[int, int, int, int]:
    if face.startswith("bevel_"):
        try:
            return BEVEL_COLORS[int(face.rsplit("_", 1)[1]) % len(BEVEL_COLORS)]
        except ValueError:
            return (218, 130, 35, 255)
    return FACE_COLORS.get(face, (58, 125, 188, 255))


def _centroid(poly: list[list[float]]) -> tuple[float, float]:
    return (
        sum(point[0] for point in poly) / len(poly),
        sum(point[1] for point in poly) / len(poly),
    )


def _poly_mask(size: tuple[int, int], polygon: list[list[float]], supersample: int = 4) -> Image.Image:
    w, h = size
    big = Image.new("L", (w * supersample, h * supersample), 0)
    draw = ImageDraw.Draw(big)
    draw.polygon([(x * supersample, y * supersample) for x, y in polygon], fill=255)
    return big.resize((w, h), Image.Resampling.LANCZOS)


def _bbox(poly: list[list[float]], size: tuple[int, int], pad: int = 18) -> tuple[int, int, int, int]:
    w, h = size
    x0 = max(0, int(min(point[0] for point in poly)) - pad)
    y0 = max(0, int(min(point[1] for point in poly)) - pad)
    x1 = min(w, int(max(point[0] for point in poly)) + pad + 1)
    y1 = min(h, int(max(point[1] for point in poly)) + pad + 1)
    return (x0, y0, x1, y1)


def _draw_label(draw: ImageDraw.ImageDraw, xy: tuple[float, float], text: str) -> None:
    font = ImageFont.load_default()
    x, y = xy
    box = draw.textbbox((x, y), text, font=font)
    draw.rounded_rectangle(
        (box[0] - 4, box[1] - 3, box[2] + 4, box[3] + 3),
        radius=3,
        fill=(255, 252, 245, 225),
        outline=(197, 183, 160, 220),
    )
    draw.text((x, y), text, fill=TEXT, font=font)


def _foreground_mask(image: Image.Image) -> np.ndarray:
    arr = np.asarray(image.convert("RGBA")).astype(np.int16)
    h, w = arr.shape[:2]
    border = max(6, min(w, h) // 100)
    border_pixels = np.concatenate(
        [
            arr[:border, :, :3].reshape(-1, 3),
            arr[-border:, :, :3].reshape(-1, 3),
            arr[:, :border, :3].reshape(-1, 3),
            arr[:, -border:, :3].reshape(-1, 3),
        ],
        axis=0,
    )
    bg = np.median(border_pixels, axis=0)
    color_delta = np.sqrt(((arr[:, :, :3] - bg) ** 2).sum(axis=2))
    mask = (color_delta > 26) & (arr[:, :, 3] > 8)
    cleaned = (
        Image.fromarray((mask * 255).astype("uint8"), "L")
        .filter(ImageFilter.MaxFilter(5))
        .filter(ImageFilter.MinFilter(5))
    )
    return np.asarray(cleaned) > 0


def _largest_component(mask: np.ndarray) -> np.ndarray:
    h, w = mask.shape
    seen = np.zeros(mask.shape, dtype=bool)
    best: list[tuple[int, int]] = []
    for y, x in np.argwhere(mask):
        y = int(y)
        x = int(x)
        if seen[y, x]:
            continue
        queue: deque[tuple[int, int]] = deque([(y, x)])
        seen[y, x] = True
        component: list[tuple[int, int]] = []
        while queue:
            cy, cx = queue.popleft()
            component.append((cy, cx))
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    queue.append((ny, nx))
        if len(component) > len(best):
            best = component
    out = np.zeros(mask.shape, dtype=bool)
    for y, x in best:
        out[y, x] = True
    return out


def _boundary_points(mask: np.ndarray) -> list[tuple[int, int]]:
    padded = np.pad(mask, 1, mode="constant")
    inner = (
        padded[1:-1, 1:-1]
        & padded[:-2, 1:-1]
        & padded[2:, 1:-1]
        & padded[1:-1, :-2]
        & padded[1:-1, 2:]
    )
    boundary = mask & ~inner
    ys, xs = np.where(boundary)
    return list(zip(xs.tolist(), ys.tolist()))


def _cross(o: tuple[int, int], a: tuple[int, int], b: tuple[int, int]) -> int:
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def _convex_hull(points: list[tuple[int, int]]) -> list[tuple[int, int]]:
    unique = sorted(set(points))
    if len(unique) <= 1:
        return unique
    lower: list[tuple[int, int]] = []
    for point in unique:
        while len(lower) >= 2 and _cross(lower[-2], lower[-1], point) <= 0:
            lower.pop()
        lower.append(point)
    upper: list[tuple[int, int]] = []
    for point in reversed(unique):
        while len(upper) >= 2 and _cross(upper[-2], upper[-1], point) <= 0:
            upper.pop()
        upper.append(point)
    return lower[:-1] + upper[:-1]


def _point_line_distance(point: tuple[int, int], start: tuple[int, int], end: tuple[int, int]) -> float:
    ax, ay = start
    bx, by = end
    px, py = point
    dx = bx - ax
    dy = by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay)
    return abs(dy * px - dx * py + bx * ay - by * ax) / math.hypot(dx, dy)


def _rdp_open(points: list[tuple[int, int]], epsilon: float) -> list[tuple[int, int]]:
    if len(points) < 3:
        return points
    start = points[0]
    end = points[-1]
    best_idx = 0
    best_distance = -1.0
    for idx, point in enumerate(points[1:-1], 1):
        distance = _point_line_distance(point, start, end)
        if distance > best_distance:
            best_idx = idx
            best_distance = distance
    if best_distance > epsilon:
        return _rdp_open(points[: best_idx + 1], epsilon)[:-1] + _rdp_open(points[best_idx:], epsilon)
    return [start, end]


def _rdp_closed(points: list[tuple[int, int]], epsilon: float) -> list[tuple[int, int]]:
    if len(points) < 4:
        return points
    count = len(points)
    candidates = [
        min(range(count), key=lambda idx: points[idx][0]),
        max(range(count), key=lambda idx: points[idx][0]),
        min(range(count), key=lambda idx: points[idx][1]),
        max(range(count), key=lambda idx: points[idx][1]),
    ]
    best_pair = (0, count // 2)
    best_distance = -1
    for a in candidates:
        for b in candidates:
            distance = (points[a][0] - points[b][0]) ** 2 + (points[a][1] - points[b][1]) ** 2
            if distance > best_distance:
                best_pair = (a, b)
                best_distance = distance
    a, b = sorted(best_pair)
    seq_a = points[a : b + 1]
    seq_b = points[b:] + points[: a + 1]
    simplified = _rdp_open(seq_a, epsilon)[:-1] + _rdp_open(seq_b, epsilon)[:-1]
    clean: list[tuple[int, int]] = []
    for point in simplified:
        if not clean or math.hypot(point[0] - clean[-1][0], point[1] - clean[-1][1]) > 12:
            clean.append(point)
    if len(clean) > 1 and math.hypot(clean[0][0] - clean[-1][0], clean[0][1] - clean[-1][1]) < 12:
        clean.pop()
    return clean


def _reduce_vertices(vertices: list[tuple[int, int]], target_count: int) -> list[tuple[int, int]]:
    out = vertices[:]
    while len(out) > target_count:
        scored = []
        for idx, point in enumerate(out):
            prev_point = out[idx - 1]
            next_point = out[(idx + 1) % len(out)]
            scored.append((_point_line_distance(point, prev_point, next_point), idx))
        _score, remove_idx = min(scored, key=lambda item: item[0])
        out.pop(remove_idx)
    return out


def _detected_vertices(image: Image.Image) -> list[tuple[int, int]]:
    mask = _largest_component(_foreground_mask(image))
    hull = _convex_hull(_boundary_points(mask))
    if not hull:
        return []
    w, h = image.size
    diag = math.hypot(w, h)
    vertices: list[tuple[int, int]] = []
    fallback: list[tuple[int, int]] = []
    for ratio in (0.012, 0.016, 0.02, 0.026, 0.034, 0.045):
        candidate = _rdp_closed(hull, diag * ratio)
        if len(candidate) >= 8:
            vertices = candidate
            break
        if not fallback and 6 <= len(candidate) <= 14:
            fallback = candidate
    if not vertices:
        vertices = fallback or _rdp_closed(hull, diag * 0.026)
    if len(vertices) > 8:
        vertices = _reduce_vertices(vertices, 8)
    start = min(range(len(vertices)), key=lambda idx: (vertices[idx][1] + vertices[idx][0] * 0.18, vertices[idx][0]))
    return vertices[start:] + vertices[:start]


def _draw_vertex_marker(
    draw: ImageDraw.ImageDraw,
    font: ImageFont.ImageFont,
    x: float,
    y: float,
    text: str,
    label_xy: tuple[float, float],
    color: tuple[int, int, int, int],
) -> None:
    radius = 8
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color, outline=(255, 255, 255, 255), width=2)
    box = draw.textbbox(label_xy, text, font=font)
    pad = 5
    draw.rounded_rectangle(
        (box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad),
        radius=5,
        fill=(255, 252, 245, 235),
        outline=color,
        width=2,
    )
    draw.text(label_xy, text, fill=VERTEX_TEXT, font=font)


def _draw_detected_vertices(
    raw: Image.Image,
    out_path: Path,
    vertices: list[tuple[float, float]] | None = None,
    internal_points: list[dict] | None = None,
) -> list[dict]:
    if vertices is None:
        vertices = _detected_vertices(raw)
    image = raw.convert("RGBA")
    draw = ImageDraw.Draw(image, "RGBA")
    if vertices:
        draw.line(vertices + [vertices[0]], fill=VERTEX_RED, width=5)
    font = ImageFont.load_default()
    if vertices:
        cx = sum(point[0] for point in vertices) / len(vertices)
        cy = sum(point[1] for point in vertices) / len(vertices)
    else:
        cx = raw.width * 0.5
        cy = raw.height * 0.5
    for idx, (x, y) in enumerate(vertices, 1):
        vx = x - cx
        vy = y - cy
        length = math.hypot(vx, vy) or 1
        label_x = x + vx / length * 22
        label_y = y + vy / length * 22
        _draw_vertex_marker(draw, font, x, y, str(idx), (label_x, label_y), VERTEX_RED)
    if internal_points:
        if len(internal_points) >= 2:
            draw.line(
                [(point["x"], point["y"]) for point in internal_points],
                fill=INTERNAL_VERTEX,
                width=4,
            )
        for point in internal_points:
            x = point["x"]
            y = point["y"]
            label_x = x + point.get("label_dx", 14)
            label_y = y + point.get("label_dy", -28)
            _draw_vertex_marker(draw, font, x, y, str(point["id"]), (label_x, label_y), INTERNAL_VERTEX)
    _save_rgb(image, out_path)
    return [{"id": idx, "name": AUTO_FIT_POINT_ORDER.get(str(idx), ""), "x": x, "y": y} for idx, (x, y) in enumerate(vertices, 1)]


def _homography(src: list[list[float]], dst: list[list[float]]) -> np.ndarray:
    if len(src) != len(dst) or len(src) < 4:
        raise ValueError("homography needs at least 4 paired points")
    rows = []
    for (x, y), (u, v) in zip(src, dst):
        rows.append([-x, -y, -1, 0, 0, 0, u * x, u * y, u])
        rows.append([0, 0, 0, -x, -y, -1, v * x, v * y, v])
    _u, _s, vt = np.linalg.svd(np.asarray(rows, dtype=np.float64))
    h = vt[-1].reshape(3, 3)
    return h / h[2, 2]


def _project_point(h: np.ndarray, point: list[float]) -> list[float]:
    x, y = point
    result = h @ np.asarray([x, y, 1.0], dtype=np.float64)
    if abs(result[2]) < 1e-9:
        return [float(result[0]), float(result[1])]
    return [float(result[0] / result[2]), float(result[1] / result[2])]


def _project_poly(h: np.ndarray, poly: list[list[float]]) -> list[list[float]]:
    return [_project_point(h, point) for point in poly]


def _line_from_points(a: list[float], b: list[float]) -> tuple[float, float, float] | None:
    x1, y1 = a
    x2, y2 = b
    if math.hypot(x2 - x1, y2 - y1) < 1e-6:
        return None
    return (y1 - y2, x2 - x1, x1 * y2 - x2 * y1)


def _line_intersection(
    first: tuple[float, float, float] | None,
    second: tuple[float, float, float] | None,
) -> list[float] | None:
    if first is None or second is None:
        return None
    a, b, c = first
    d, e, f = second
    den = a * e - b * d
    if abs(den) < 1e-7:
        return None
    return [(b * f - c * e) / den, (c * d - a * f) / den]


def _point_distance(a: list[float], b: list[float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def _normalize_vector(vector: list[float]) -> list[float] | None:
    length = math.hypot(vector[0], vector[1])
    if length < 1e-7:
        return None
    return [vector[0] / length, vector[1] / length]


def _angle_between(a: list[float], b: list[float]) -> float:
    a_unit = _normalize_vector(a)
    b_unit = _normalize_vector(b)
    if not a_unit or not b_unit:
        return 180.0
    dot = max(-1.0, min(1.0, a_unit[0] * b_unit[0] + a_unit[1] * b_unit[1]))
    return math.degrees(math.acos(dot))


def _line_from_point_dir(point: list[float], direction: list[float]) -> tuple[float, float, float] | None:
    return _line_from_points(point, [point[0] + direction[0], point[1] + direction[1]])


def _height_transfer_estimate(
    bottom: list[float],
    left_bottom: list[float],
    right_bottom: list[float],
    left_height: float,
    right_height: float,
    vertical_dir: list[float],
) -> list[float]:
    denominator = right_bottom[0] - left_bottom[0]
    if abs(denominator) < 1e-6:
        ratio = 0.5
    else:
        ratio = (bottom[0] - left_bottom[0]) / denominator
    height = left_height + (right_height - left_height) * ratio
    return [bottom[0] + vertical_dir[0] * height, bottom[1] + vertical_dir[1] * height]


def _median(values: list[float]) -> float:
    ordered = sorted(values)
    mid = len(ordered) // 2
    if len(ordered) % 2:
        return ordered[mid]
    return (ordered[mid - 1] + ordered[mid]) * 0.5


def _median_point(points: list[list[float]]) -> list[float] | None:
    if not points:
        return None
    return [_median([point[0] for point in points]), _median([point[1] for point in points])]


def _point_spread(points: list[list[float]], center: list[float]) -> float:
    if not points:
        return 0.0
    return max(_point_distance(point, center) for point in points)


def _projective_internal_points(
    detected: list[list[float]],
    predicted_top_4: list[float],
    predicted_top_5: list[float],
) -> tuple[list[float], list[float], dict]:
    t2, t1, t0, b0, b5, b4, b3, t3 = detected
    right_vertical = [t0[0] - b0[0], t0[1] - b0[1]]
    left_vertical = [t3[0] - b3[0], t3[1] - b3[1]]
    vertical_angle = _angle_between(right_vertical, left_vertical)
    right_unit = _normalize_vector(right_vertical)
    left_unit = _normalize_vector(left_vertical)
    vertical_vp = _line_intersection(_line_from_points(t0, b0), _line_from_points(t3, b3))
    side_vp_34 = _line_intersection(_line_from_points(t0, t1), _line_from_points(b4, b3))
    side_vp_50 = _line_intersection(_line_from_points(t2, t3), _line_from_points(b0, b5))
    front_vp = _line_intersection(_line_from_points(t1, t2), _line_from_points(b4, b5))
    fallback_meta = {
        "method": "top-plane homography fallback",
        "status": "fallback",
        "reason": "missing internal point constraint",
    }

    if vertical_angle < 2.0 and right_unit and left_unit:
        vertical_dir = _normalize_vector([right_unit[0] + left_unit[0], right_unit[1] + left_unit[1]])
        if vertical_dir:
            center = [(t0[0] + t3[0]) * 0.5, (t0[1] + t3[1]) * 0.5]
            vertical_4 = _line_from_point_dir(b4, vertical_dir)
            vertical_5 = _line_from_point_dir(b5, vertical_dir)
            side_4 = _line_intersection(_line_from_points(t3, side_vp_34), vertical_4) if side_vp_34 else None
            side_5 = _line_intersection(_line_from_points(t0, side_vp_50), vertical_5) if side_vp_50 else None
            symmetry_4 = [center[0] * 2.0 - t1[0], center[1] * 2.0 - t1[1]]
            symmetry_5 = [center[0] * 2.0 - t2[0], center[1] * 2.0 - t2[1]]
            symmetry_ray_4 = _line_intersection(vertical_4, _line_from_points(t1, center))
            symmetry_ray_5 = _line_intersection(vertical_5, _line_from_points(t2, center))
            left_height = _point_distance(t3, b3)
            right_height = _point_distance(t0, b0)
            height_4 = _height_transfer_estimate(b4, b3, b0, left_height, right_height, vertical_dir)
            height_5 = _height_transfer_estimate(b5, b3, b0, left_height, right_height, vertical_dir)
            candidates_4 = [height_4, symmetry_4, predicted_top_4]
            candidates_5 = [height_5, symmetry_5, predicted_top_5]
            if side_4:
                candidates_4.append(side_4)
            if side_5:
                candidates_5.append(side_5)
            top_4 = _median_point(candidates_4)
            top_5 = _median_point(candidates_5)
            if top_4 and top_5:
                front_angle = _angle_between([top_5[0] - top_4[0], top_5[1] - top_4[1]], [t2[0] - t1[0], t2[1] - t1[1]])
                front_angle = min(front_angle, 180.0 - front_angle)
                delta_4 = _point_distance(top_4, predicted_top_4)
                delta_5 = _point_distance(top_5, predicted_top_5)
                return top_4, top_5, {
                    "method": "orthographic four-constraint median: vertical-height transfer, central symmetry, side VP seed, top-plane prior",
                    "status": "orthographic_symmetry",
                    "vertical_angle_deg": vertical_angle,
                    "vertical_direction": {"x": vertical_dir[0], "y": vertical_dir[1]},
                    "center": {"x": center[0], "y": center[1]},
                    "visible_vertical_heights_px": {"left_8_7": left_height, "right_3_4": right_height},
                    "constraint_estimates": {
                        "height_transfer": {
                            "top_4": {"x": height_4[0], "y": height_4[1]},
                            "top_5": {"x": height_5[0], "y": height_5[1]},
                        },
                        "central_symmetry": {
                            "top_4": {"x": symmetry_4[0], "y": symmetry_4[1]},
                            "top_5": {"x": symmetry_5[0], "y": symmetry_5[1]},
                        },
                        "symmetry_ray_vertical_intersection": {
                            **({"top_4": {"x": symmetry_ray_4[0], "y": symmetry_ray_4[1]}} if symmetry_ray_4 else {}),
                            **({"top_5": {"x": symmetry_ray_5[0], "y": symmetry_ray_5[1]}} if symmetry_ray_5 else {}),
                        },
                        "side_vp_seed": {
                            **({"top_4": {"x": side_4[0], "y": side_4[1]}} if side_4 else {}),
                            **({"top_5": {"x": side_5[0], "y": side_5[1]}} if side_5 else {}),
                        },
                        "top_plane_prior": {
                            "top_4": {"x": predicted_top_4[0], "y": predicted_top_4[1]},
                            "top_5": {"x": predicted_top_5[0], "y": predicted_top_5[1]},
                        },
                    },
                    "height_transfer_estimates": {
                        "top_4": {"x": height_4[0], "y": height_4[1]},
                        "top_5": {"x": height_5[0], "y": height_5[1]},
                    },
                    "validation": {
                        "front_edge_angle_delta_deg": front_angle,
                        "height_transfer_delta_px": {
                            "top_4": _point_distance(top_4, height_4),
                            "top_5": _point_distance(top_5, height_5),
                        },
                        "constraint_spread_px": {
                            "top_4": _point_spread(candidates_4, top_4),
                            "top_5": _point_spread(candidates_5, top_5),
                        },
                    },
                    "delta_from_top_plane_px": {"top_4": delta_4, "top_5": delta_5},
                }

    if not vertical_vp or not side_vp_34 or not side_vp_50:
        fallback_meta["reason"] = "missing perspective vanishing point"
        return predicted_top_4, predicted_top_5, fallback_meta

    vertical_4 = _line_from_points(b4, vertical_vp)
    vertical_5 = _line_from_points(b5, vertical_vp)
    top_4 = _line_intersection(_line_from_points(t3, side_vp_34), vertical_4)
    top_5 = _line_intersection(_line_from_points(t0, side_vp_50), vertical_5)
    if not top_4 or not top_5:
        fallback_meta["reason"] = "missing perspective side intersection"
        return predicted_top_4, predicted_top_5, fallback_meta

    xs = [point[0] for point in detected]
    ys = [point[1] for point in detected]
    bbox_diag = math.hypot(max(xs) - min(xs), max(ys) - min(ys))
    max_delta = max(55.0, bbox_diag * 0.06)
    delta_4 = _point_distance(top_4, predicted_top_4)
    delta_5 = _point_distance(top_5, predicted_top_5)
    if delta_4 > max_delta or delta_5 > max_delta:
        fallback_meta["reason"] = "projective point too far from top-plane prediction"
        fallback_meta["max_delta_px"] = max_delta
        fallback_meta["delta_px"] = {"top_4": delta_4, "top_5": delta_5}
        return predicted_top_4, predicted_top_5, fallback_meta

    return top_4, top_5, {
        "method": "perspective vertical vanishing point + side vanishing points",
        "status": "perspective_side_vp",
        "vertical_angle_deg": vertical_angle,
        "vanishing_points": {
            "vertical": {"x": vertical_vp[0], "y": vertical_vp[1]},
            "side_34": {"x": side_vp_34[0], "y": side_vp_34[1]},
            **({"front": {"x": front_vp[0], "y": front_vp[1]}} if front_vp else {}),
            "side_50": {"x": side_vp_50[0], "y": side_vp_50[1]},
        },
        "delta_from_top_plane_px": {"top_4": delta_4, "top_5": delta_5},
    }


def _valid_internal_points(detected: list[list[float]], top_4: list[float], top_5: list[float]) -> bool:
    _t2, _t1, _t0, _b0, b5, b4, _b3, _t3 = detected
    xs = [point[0] for point in detected]
    ys = [point[1] for point in detected]
    margin = max(48.0, math.hypot(max(xs) - min(xs), max(ys) - min(ys)) * 0.06)
    if not (min(xs) - margin <= top_4[0] <= max(xs) + margin):
        return False
    if not (min(xs) - margin <= top_5[0] <= max(xs) + margin):
        return False
    if not (min(ys) - margin <= top_4[1] <= max(ys) + margin):
        return False
    if not (min(ys) - margin <= top_5[1] <= max(ys) + margin):
        return False
    if top_4[0] >= top_5[0]:
        return False
    if top_4[1] >= b4[1] - 8 or top_5[1] >= b5[1] - 8:
        return False
    if _point_distance(top_4, top_5) < 120:
        return False
    return True


def _auto_fit_source_faces(source_faces: list[dict], vertex_points: list[dict]) -> tuple[list[dict], dict | None]:
    if len(vertex_points) != 8:
        return [], None
    by_name = {face["name"]: face["poly"] for face in source_faces}
    if any(name.startswith("bevel_") for name in by_name):
        return [], None
    top = by_name.get("top")
    wall_3 = by_name.get("wall_3")
    wall_4 = by_name.get("wall_4")
    wall_5 = by_name.get("wall_5")
    if not top or len(top) < 6 or not wall_3 or not wall_4 or not wall_5:
        return [], None

    detected = [[point["x"], point["y"]] for point in vertex_points]
    # Detected silhouette order:
    # 1=top[2], 2=top[1], 3=top[0], 4=wall_5[2], 5=wall_5[3],
    # 6=wall_4[3], 7=wall_3[3], 8=top[3].
    top_h = _homography([top[2], top[1], top[0], top[3]], [detected[0], detected[1], detected[2], detected[7]])
    predicted_top_4 = _project_point(top_h, top[4])
    predicted_top_5 = _project_point(top_h, top[5])
    top_4, top_5, internal_meta = _projective_internal_points(detected, predicted_top_4, predicted_top_5)
    if not _valid_internal_points(detected, top_4, top_5):
        return [], None
    dst_by_face = {
        "top": [detected[2], detected[1], detected[0], detected[7], top_4, top_5],
        "wall_3": [detected[7], top_4, detected[5], detected[6]],
        "wall_4": [top_4, top_5, detected[4], detected[5]],
        "wall_5": [top_5, detected[2], detected[3], detected[4]],
    }
    transforms: dict[str, list[list[float]]] = {"top_outer": top_h.tolist()}
    fitted = []
    for face in source_faces:
        name = face["name"]
        if name in dst_by_face:
            if name != "top":
                h = _homography(face["poly"], dst_by_face[name])
                transforms[name] = h.tolist()
            fitted.append({"name": name, "poly": dst_by_face[name]})
        else:
            continue
    meta = {
        "method": "per-face source fit: outer 8-point silhouette plus orthographic/perspective internal-point solver, then each visible face uses its constrained polygon",
        "transforms": transforms,
        "initial_top_plane_points": {
            "top_4": {"x": predicted_top_4[0], "y": predicted_top_4[1]},
            "top_5": {"x": predicted_top_5[0], "y": predicted_top_5[1]},
        },
        "internal_point_fit": internal_meta,
        "derived_points": {
            "top_4": {"x": top_4[0], "y": top_4[1]},
            "top_5": {"x": top_5[0], "y": top_5[1]},
        },
        "point_order": AUTO_FIT_POINT_ORDER,
    }
    return fitted, meta


def _draw_polys(image: Image.Image, faces: list[dict], *, scale: float = 1.0, offset: tuple[float, float] = (0, 0)) -> None:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")
    ox, oy = offset
    for face in faces:
        poly = [[point[0] * scale + ox, point[1] * scale + oy] for point in face["poly"]]
        color = _color(face["name"])
        fill = (color[0], color[1], color[2], 34)
        draw.polygon([tuple(point) for point in poly], fill=fill)
        draw.line([tuple(point) for point in poly + [poly[0]]], fill=color, width=max(2, int(4 * scale)))
    image.alpha_composite(overlay)
    draw = ImageDraw.Draw(image, "RGBA")
    for face in faces:
        poly = [[point[0] * scale + ox, point[1] * scale + oy] for point in face["poly"]]
        cx, cy = _centroid(poly)
        _draw_label(draw, (cx - 16, cy - 6), face["name"])


def _fit_box(size: tuple[int, int], box: tuple[int, int, int, int]) -> tuple[float, float, float]:
    w, h = size
    x0, y0, x1, y1 = box
    scale = min((x1 - x0) / w, (y1 - y0) / h)
    ox = x0 + ((x1 - x0) - w * scale) * 0.5
    oy = y0 + ((y1 - y0) - h * scale) * 0.5
    return scale, ox, oy


def _thumb(image: Image.Image, max_size: tuple[int, int]) -> Image.Image:
    copy = image.convert("RGBA")
    copy.thumbnail(max_size, Image.Resampling.LANCZOS)
    return copy


def _save_rgb(image: Image.Image, out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    last_error: OSError | None = None
    for attempt in range(5):
        tmp_path = out_path.with_name(f".{out_path.stem}.{attempt}.tmp{out_path.suffix}")
        try:
            rgb = image.convert("RGB")
            try:
                rgb.save(tmp_path)
            finally:
                rgb.close()
            tmp_path.replace(out_path)
            return
        except OSError as exc:
            last_error = exc
            try:
                tmp_path.unlink()
            except OSError:
                pass
            time.sleep(0.2 * (attempt + 1))
    if last_error is not None:
        raise last_error


def _crop_source(raw: Image.Image, source_poly: list[list[float]]) -> Image.Image:
    mask = _poly_mask(raw.size, source_poly)
    layer = Image.new("RGBA", raw.size, (0, 0, 0, 0))
    layer.paste(raw, (0, 0), mask)
    return layer.crop(_bbox(source_poly, raw.size, 20))


def _local_dst_poly(dst_poly: list[list[float]], pad: int) -> tuple[list[list[float]], tuple[int, int]]:
    min_x = min(point[0] for point in dst_poly)
    max_x = max(point[0] for point in dst_poly)
    min_y = min(point[1] for point in dst_poly)
    max_y = max(point[1] for point in dst_poly)
    width = int(max_x - min_x) + pad * 2 + 2
    height = int(max_y - min_y) + pad * 2 + 2
    local = [[point[0] - min_x + pad, point[1] - min_y + pad] for point in dst_poly]
    return local, (width, height)


def _normalize_face(raw: Image.Image, source_poly: list[list[float]], dst_poly: list[list[float]], warp_module) -> Image.Image:
    local_dst, size = _local_dst_poly(dst_poly, 18)
    normalized, _stats = warp_module.warp_polygon_piecewise(raw, size, source_poly, local_dst)
    return normalized


def _contact_sheet(items: list[dict], title: str, out_path: Path) -> None:
    if not items:
        return
    cols = min(4, len(items))
    rows = (len(items) + cols - 1) // cols
    cell_w, cell_h = 280, 235
    title_h = 42
    canvas = Image.new("RGBA", (cols * cell_w, title_h + rows * cell_h), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((14, 14), title, fill=TEXT, font=ImageFont.load_default())
    for idx, item in enumerate(items):
        col = idx % cols
        row = idx // cols
        x = col * cell_w
        y = title_h + row * cell_h
        draw.rounded_rectangle((x + 10, y + 8, x + cell_w - 10, y + cell_h - 10), radius=8, fill=PANEL_BG, outline=(212, 200, 180, 255))
        face = item["name"]
        draw.rectangle((x + 14, y + 12, x + 28, y + 26), fill=_color(face))
        draw.text((x + 34, y + 13), face, fill=TEXT, font=ImageFont.load_default())
        thumb = _thumb(item["image"], (cell_w - 34, cell_h - 58))
        px = x + (cell_w - thumb.width) // 2
        py = y + 40 + (cell_h - 58 - thumb.height) // 2
        canvas.alpha_composite(thumb, (px, py))
    _save_rgb(canvas, out_path)


def _overlay_uv(uv_image: Image.Image, dst_faces: list[dict], out_path: Path) -> None:
    image = Image.new("RGBA", uv_image.size, BG)
    image.alpha_composite(uv_image.convert("RGBA"))
    _draw_polys(image, dst_faces)
    _save_rgb(image, out_path)


def _save_face_image(image: Image.Image, out_path: Path) -> None:
    canvas = Image.new("RGBA", image.size, BG)
    canvas.alpha_composite(image.convert("RGBA"))
    _save_rgb(canvas, out_path)


def _remove_stale(paths: list[Path]) -> None:
    for path in paths:
        if path.is_dir():
            shutil.rmtree(path)
        elif path.exists():
            path.unlink()


def _mapping_pair(
    raw: Image.Image,
    uv_image: Image.Image,
    source_faces: list[dict],
    dst_faces: list[dict],
    out_path: Path,
    *,
    source_title: str = "source template faces",
) -> None:
    canvas = Image.new("RGBA", (1600, 760), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((24, 18), source_title, fill=TEXT, font=ImageFont.load_default())
    draw.text((824, 18), "UV islands", fill=TEXT, font=ImageFont.load_default())
    draw.line((792, 60, 808, 60), fill=MUTED, width=2)
    draw.polygon([(808, 60), (798, 54), (798, 66)], fill=MUTED)

    left = (24, 48, 780, 732)
    right = (820, 48, 1576, 732)
    raw_scale, raw_ox, raw_oy = _fit_box(raw.size, left)
    uv_scale, uv_ox, uv_oy = _fit_box(uv_image.size, right)
    raw_thumb = raw.resize((int(raw.width * raw_scale), int(raw.height * raw_scale)), Image.Resampling.LANCZOS)
    uv_thumb = uv_image.resize((int(uv_image.width * uv_scale), int(uv_image.height * uv_scale)), Image.Resampling.LANCZOS)
    canvas.alpha_composite(raw_thumb, (int(raw_ox), int(raw_oy)))
    canvas.alpha_composite(uv_thumb, (int(uv_ox), int(uv_oy)))
    _draw_polys(canvas, source_faces, scale=raw_scale, offset=(raw_ox, raw_oy))
    _draw_polys(canvas, dst_faces, scale=uv_scale, offset=(uv_ox, uv_oy))
    _save_rgb(canvas, out_path)


def _mapping_panel(image: Image.Image, faces: list[dict], title: str, out_path: Path) -> None:
    canvas = Image.new("RGBA", (880, 620), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((20, 18), title, fill=TEXT, font=ImageFont.load_default())
    box = (20, 48, 860, 596)
    scale, ox, oy = _fit_box(image.size, box)
    thumb = image.resize((int(image.width * scale), int(image.height * scale)), Image.Resampling.LANCZOS)
    canvas.alpha_composite(thumb, (int(ox), int(oy)))
    _draw_polys(canvas, faces, scale=scale, offset=(ox, oy))
    _save_rgb(canvas, out_path)


def _hard_faces(repo: Path, tile_id: str, info: dict) -> list[dict]:
    scripts_dir = repo / "blender" / "scripts"
    if str(scripts_dir) not in sys.path:
        sys.path.insert(0, str(scripts_dir))
    from texgen import geometry  # noqa: PLC0415

    design = _read_json(repo / info["design_sidecar"])
    uv = _read_json(repo / info["uv_sidecar"])
    faces = []
    for name, _source_poly, dst_poly in geometry.face_polygon_pairs(design, uv):
        faces.append({
            "name": name,
            "source_poly": _face_poly(design["faces"][name]),
            "dst_poly": dst_poly,
        })
    return faces


def _bevel_faces(info: dict) -> list[dict]:
    return [
        {"name": name, "source_poly": data["source_poly"], "dst_poly": data["dst_poly"]}
        for name, data in info.get("faces", {}).items()
    ]


def _render_one(repo: Path, out_root: Path, pipeline: str, tile_id: str, info: dict, faces: list[dict]) -> dict:
    scripts_dir = repo / "blender" / "scripts"
    if str(scripts_dir) not in sys.path:
        sys.path.insert(0, str(scripts_dir))
    from texgen import warp  # noqa: PLC0415

    raw_key = "raw" if info.get("raw") else "design"
    raw_path = repo / info[raw_key]
    uv_path = repo / info["uv"]
    raw = Image.open(raw_path).convert("RGBA")
    uv = Image.open(uv_path).convert("RGBA")
    out_dir = out_root / pipeline / tile_id

    source_faces = [{"name": f["name"], "poly": f["source_poly"]} for f in faces]
    dst_faces = [{"name": f["name"], "poly": f["dst_poly"]} for f in faces]
    mapping = out_dir / "mapping_pair.png"
    auto_mapping = out_dir / "auto_fit_mapping_pair.png"
    source_mapping = out_dir / "source_template_faces.png"
    auto_source_mapping = out_dir / "source_auto_fit_faces.png"
    detected_vertices = out_dir / "ai_detected_vertices.png"
    uv_mapping = out_dir / "uv_islands.png"
    source_cuts = out_dir / "source_cuts.png"
    auto_source_cuts = out_dir / "auto_source_cuts.png"
    normalized = out_dir / "normalized_cuts.png"
    auto_normalized = out_dir / "auto_normalized_cuts.png"
    uv_compose = out_dir / "uv_compose_overlay.png"
    face_dir = out_dir / "faces"
    auto_face_dir = out_dir / "faces_auto"
    primary_auto_fit = info.get("fit_mode") == "auto_fit_source_faces"

    _mapping_pair(
        raw,
        uv,
        source_faces,
        dst_faces,
        mapping,
        source_title="auto-fit source faces" if primary_auto_fit else "source template faces",
    )
    vertex_points = _draw_detected_vertices(raw, detected_vertices)
    auto_source_faces, auto_meta = ([], None) if primary_auto_fit else _auto_fit_source_faces(source_faces, vertex_points)
    internal_vertex_points: list[dict] = []
    primary_auto_meta = info.get("auto_fit") if primary_auto_fit else auto_meta
    if primary_auto_meta:
        derived = primary_auto_meta.get("derived_points", {})
        top_4 = derived.get("top_4")
        top_5 = derived.get("top_5")
        if top_4 and top_5:
            internal_vertex_points = [
                {"id": 9, "name": "top[4]", "x": top_4["x"], "y": top_4["y"], "label_dx": -30, "label_dy": -34},
                {"id": 10, "name": "top[5]", "x": top_5["x"], "y": top_5["y"], "label_dx": 16, "label_dy": -34},
            ]
            _draw_detected_vertices(
                raw,
                detected_vertices,
                vertices=[(point["x"], point["y"]) for point in vertex_points],
                internal_points=internal_vertex_points,
            )
    blank_uv = Image.new("RGBA", uv.size, BG)
    _mapping_panel(raw, source_faces, "auto-fit source faces" if primary_auto_fit else "source template faces", source_mapping)
    auto_branches = []
    if auto_source_faces:
        _mapping_pair(raw, uv, auto_source_faces, dst_faces, auto_mapping, source_title="auto-fit source faces")
        _mapping_panel(raw, auto_source_faces, "auto-fit source faces", auto_source_mapping)
    elif primary_auto_fit:
        _remove_stale([auto_mapping, auto_source_mapping, auto_source_cuts, auto_normalized, auto_face_dir])
    _mapping_panel(blank_uv, dst_faces, "UV target islands", uv_mapping)
    source_items = []
    auto_source_items = []
    normalized_items = []
    auto_normalized_items = []
    branches = []
    for face in faces:
        name = face["name"]
        source_img = _crop_source(raw, face["source_poly"])
        normalized_img = _normalize_face(raw, face["source_poly"], face["dst_poly"], warp)
        source_path = face_dir / ("%s_source.png" % name)
        normalized_path = face_dir / ("%s_normalized.png" % name)
        _save_face_image(source_img, source_path)
        _save_face_image(normalized_img, normalized_path)
        source_items.append({"name": name, "image": source_img})
        normalized_items.append({"name": name, "image": normalized_img})
        branches.append({
            "face": name,
            "source_cut": _rel(repo, source_path),
            "normalized_cut": _rel(repo, normalized_path),
            "normalize_route": NORMALIZE_ROUTE,
            "uv": name,
        })

    for face in auto_source_faces:
        name = face["name"]
        source_img = _crop_source(raw, face["poly"])
        normalized_img = _normalize_face(raw, face["poly"], next(f["dst_poly"] for f in faces if f["name"] == name), warp)
        source_path = auto_face_dir / ("%s_auto_source.png" % name)
        normalized_path = auto_face_dir / ("%s_auto_normalized.png" % name)
        _save_face_image(source_img, source_path)
        _save_face_image(normalized_img, normalized_path)
        auto_source_items.append({"name": name, "image": source_img})
        auto_normalized_items.append({"name": name, "image": normalized_img})
        auto_branches.append({
            "face": name,
            "source_cut": _rel(repo, source_path),
            "normalized_cut": _rel(repo, normalized_path),
            "normalize_route": NORMALIZE_ROUTE,
            "uv": name,
        })

    _contact_sheet(source_items, "source face cuts", source_cuts)
    _contact_sheet(auto_source_items, "auto-fit source face cuts", auto_source_cuts)
    _contact_sheet(normalized_items, "normalized face cuts", normalized)
    _contact_sheet(auto_normalized_items, "auto-fit normalized face cuts", auto_normalized)
    _overlay_uv(uv, dst_faces, uv_compose)

    auto_fit = None
    if auto_source_faces:
        auto_fit = {
            **(auto_meta or {}),
            "mapping": {"id": "auto_fit_mapping", "label": "自动套版映射", "path": _rel(repo, auto_mapping)},
            "source_template": {"id": "source_auto_fit", "label": "自动套版 source faces", "path": _rel(repo, auto_source_mapping)},
            "source_cuts": {"id": "auto_source_cuts", "label": "自动部分切图", "path": _rel(repo, auto_source_cuts)},
            "normalized": {"id": "auto_normalized", "label": "自动标准化", "path": _rel(repo, auto_normalized)},
            "branches": auto_branches,
        }
    else:
        _remove_stale([auto_mapping, auto_source_mapping, auto_source_cuts, auto_normalized, auto_face_dir])

    return {
        "fit_mode": info.get("fit_mode") or "template_source_faces",
        "root": {"id": "mapping", "label": "自动套版映射" if primary_auto_fit else "套版映射", "path": _rel(repo, mapping)},
        "roots": [
            {
                "id": "ai_detected_vertices",
                "label": "AI 轮廓顶点编号",
                "path": _rel(repo, detected_vertices),
                "points": vertex_points,
                "internal_points": internal_vertex_points,
                "method": "foreground silhouette -> convex hull -> RDP simplify",
            },
            {
                "id": "source_template",
                "label": "自动套版 source faces" if primary_auto_fit else "套版 source faces",
                "path": _rel(repo, source_mapping),
            },
            *([auto_fit["source_template"]] if auto_fit else []),
            {"id": "uv_islands", "label": "目标 UV 槽位", "path": _rel(repo, uv_mapping)},
        ],
        "detected_vertices": {
            "id": "ai_detected_vertices",
            "label": "AI 轮廓顶点编号",
            "path": _rel(repo, detected_vertices),
            "points": vertex_points,
            "internal_points": internal_vertex_points,
            "method": "foreground silhouette -> convex hull -> RDP simplify",
        },
        "auto_fit": auto_fit,
        "branches": branches,
        "final": {"id": "uv_compose", "label": "组合 UV", "path": _rel(repo, uv_compose)},
        "steps": [
            {"id": "mapping", "label": "自动套版映射" if primary_auto_fit else "套版映射", "path": _rel(repo, mapping)},
            {"id": "source_cuts", "label": "自动部分切图" if primary_auto_fit else "部分切图", "path": _rel(repo, source_cuts)},
            {"id": "normalized", "label": "自动标准化" if primary_auto_fit else "标准化", "path": _rel(repo, normalized), "route": NORMALIZE_ROUTE},
            {"id": "uv_compose", "label": "组合 UV", "path": _rel(repo, uv_compose)},
        ],
        "faces": [{"source": f["name"], "uv": f["name"]} for f in faces],
    }


def prepare(root: Path, out_root: Path) -> dict:
    repo = repo_root()
    hard_report = _read_json(root / "uv" / "design_warp_uv_report.json")
    bevel_report = _read_json(root / "beveled_uv_wide_rim" / "beveled_uv_report.json")
    out: dict[str, dict] = {"hard": {}, "bevel": {}}

    for terrain in TERRAINS:
        for elevation in ELEVATIONS:
            tile_id = f"{terrain}_e{elevation}"
            hard_info = hard_report[tile_id]
            bevel_info = bevel_report[tile_id]
            out["hard"][tile_id] = _render_one(repo, out_root, "hard", tile_id, hard_info, _hard_faces(repo, tile_id, hard_info))
            out["bevel"][tile_id] = _render_one(repo, out_root, "bevel", tile_id, bevel_info, _bevel_faces(bevel_info))

    out_root.mkdir(parents=True, exist_ok=True)
    report = out_root / "uv_mapping_trace_report.json"
    report.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=concept_root(repo_root()))
    parser.add_argument("--out-dir", type=Path, default=None)
    args = parser.parse_args()
    root = args.root.resolve()
    out_dir = (args.out_dir or root / "trace").resolve()
    result = prepare(root, out_dir)
    print(json.dumps({"ok": True, "pipelines": list(result.keys()), "out_dir": str(out_dir)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
