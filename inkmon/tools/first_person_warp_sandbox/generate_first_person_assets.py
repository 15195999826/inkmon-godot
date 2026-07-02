from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent
ASSET_DIR = ROOT / "assets"
OUTPUT_DIR = ROOT / "output"


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def mix_color(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(lerp(a[0], b[0], t)),
        int(lerp(a[1], b[1], t)),
        int(lerp(a[2], b[2], t)),
    )


def draw_wrapped_line(draw: ImageDraw.ImageDraw, xy: tuple[float, float, float, float], height: int, fill: tuple[int, ...], width: int = 1) -> None:
    x0, y0, x1, y1 = xy
    for offset in (-height, 0, height):
        draw.line((x0, y0 + offset, x1, y1 + offset), fill=fill, width=width)


def create_road_strip() -> None:
    width, height = 1024, 2048
    image = Image.new("RGB", (width, height))
    pixels = image.load()

    for y in range(height):
        v = y / float(height)
        edge_wave = math.sin(v * math.tau * 2.0) * 0.020 + math.sin(v * math.tau * 5.0 + 1.2) * 0.010
        road_half = 0.135 + edge_wave
        left_edge = 0.5 - road_half
        right_edge = 0.5 + road_half

        for x in range(width):
            u = x / float(width)
            grain = math.sin((u * 34.0 + v * 59.0) * math.tau) * 0.5 + 0.5
            grass_wave = math.sin((u * 9.0 - v * 4.0) * math.tau) * 0.5 + 0.5
            if left_edge <= u <= right_edge:
                center_dist = abs(u - 0.5)
                water = 1.0 - clamp(center_dist / 0.075, 0.0, 1.0)
                mud = (grain * 0.20) + (math.sin(v * math.tau * 12.0 + u * 8.0) * 0.08)
                base = mix_color((34, 30, 28), (37, 100, 105), water * 0.82)
                color = mix_color(base, (84, 62, 48), clamp(mud, 0.0, 1.0))
            else:
                ditch_left = 1.0 - clamp(abs(u - left_edge) / 0.035, 0.0, 1.0)
                ditch_right = 1.0 - clamp(abs(u - right_edge) / 0.035, 0.0, 1.0)
                ditch = max(ditch_left, ditch_right)
                grass = mix_color((18, 63, 56), (39, 94, 75), grass_wave)
                color = mix_color(grass, (35, 105, 112), ditch * 0.75)
                if abs(u - left_edge) < 0.008 or abs(u - right_edge) < 0.008:
                    color = mix_color(color, (185, 210, 190), 0.45)
            pixels[x, y] = color

    draw = ImageDraw.Draw(image, "RGBA")
    rng = random.Random(1042)

    for _ in range(900):
        x = rng.randint(0, width - 1)
        y = rng.randint(0, height - 1)
        u = x / float(width)
        v = y / float(height)
        road_half = 0.135 + math.sin(v * math.tau * 2.0) * 0.020 + math.sin(v * math.tau * 5.0 + 1.2) * 0.010
        if abs(u - 0.5) < road_half:
            stroke = (rng.randint(30, 70), rng.randint(42, 88), rng.randint(70, 98), 90)
            length = rng.randint(8, 34)
            draw_wrapped_line(draw, (x, y, x + rng.randint(-10, 10), y + length), height, stroke, rng.randint(1, 3))
        else:
            stroke = (rng.randint(55, 115), rng.randint(105, 155), rng.randint(95, 130), 110)
            length = rng.randint(10, 42)
            draw_wrapped_line(draw, (x, y, x + rng.randint(-8, 8), y + length), height, stroke, rng.randint(1, 2))

    for _ in range(150):
        x = rng.randint(int(width * 0.36), int(width * 0.64))
        y = rng.randint(0, height - 1)
        radius = rng.randint(2, 8)
        color = (12, 18, 20, rng.randint(75, 145))
        for offset in (-height, 0, height):
            draw.ellipse((x - radius, y + offset - radius, x + radius, y + offset + radius), fill=color)

    image = image.filter(ImageFilter.UnsharpMask(radius=1.4, percent=80, threshold=2))
    image.save(ASSET_DIR / "road_strip.png")


def create_horizon_plate() -> None:
    width, height = 1280, 720
    image = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(image, "RGBA")
    pixels = image.load()

    for y in range(height):
        t = y / float(height - 1)
        top = (8, 46, 64)
        glow = (93, 202, 190)
        dusk = (248, 165, 109)
        if t < 0.62:
            color = mix_color(top, glow, t / 0.62)
        else:
            color = mix_color(glow, dusk, (t - 0.62) / 0.38)
        for x in range(width):
            pixels[x, y] = color

    rng = random.Random(2048)
    for _ in range(360):
        x = rng.randint(0, width - 1)
        y = rng.randint(10, int(height * 0.48))
        alpha = rng.randint(55, 135)
        radius = rng.choice([1, 1, 2])
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(205, 235, 225, alpha))

    for _ in range(45):
        cx = rng.randint(0, width)
        cy = rng.randint(int(height * 0.12), int(height * 0.42))
        rx = rng.randint(80, 180)
        ry = rng.randint(18, 46)
        draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(85, 160, 155, 28))

    horizon_y = int(height * 0.61)
    draw.rectangle((0, horizon_y, width, height), fill=(12, 63, 58, 255))
    for i in range(12):
        y = horizon_y + i * 9
        draw.line((0, y, width, y + rng.randint(-3, 3)), fill=(24, 91, 83, 70), width=2)

    castle_x = width // 2
    castle_base = horizon_y + 4
    castle_color = (14, 42, 53, 245)
    draw.rectangle((castle_x - 155, castle_base - 38, castle_x + 155, castle_base), fill=castle_color)
    draw.polygon(
        (
            castle_x - 210,
            castle_base,
            castle_x - 130,
            castle_base - 62,
            castle_x - 80,
            castle_base - 48,
            castle_x,
            castle_base - 120,
            castle_x + 82,
            castle_base - 46,
            castle_x + 130,
            castle_base - 62,
            castle_x + 210,
            castle_base,
        ),
        fill=castle_color,
    )
    for tower_x, tower_h, tower_w in [
        (-110, 86, 28),
        (-52, 102, 24),
        (0, 160, 34),
        (54, 106, 24),
        (114, 82, 28),
    ]:
        x0 = castle_x + tower_x - tower_w // 2
        x1 = castle_x + tower_x + tower_w // 2
        draw.rectangle((x0, castle_base - tower_h, x1, castle_base), fill=castle_color)
        draw.polygon((x0 - 8, castle_base - tower_h, (x0 + x1) // 2, castle_base - tower_h - 28, x1 + 8, castle_base - tower_h), fill=castle_color)

    for side_x in (170, width - 170):
        draw.rectangle((side_x - 7, horizon_y - 60, side_x + 8, horizon_y + 10), fill=(19, 53, 41, 230))
        for radius in (44, 58, 72):
            draw.ellipse((side_x - radius, horizon_y - 105, side_x + radius, horizon_y - 28), fill=(29, 83, 71, 150))

    image = image.filter(ImageFilter.GaussianBlur(radius=0.35))
    image.save(ASSET_DIR / "horizon_plate.png")


def create_hand_overlay() -> None:
    width, height = 1280, 720
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")

    staff = [(930, 748), (970, 750), (1108, 140), (1068, 132)]
    draw.polygon(staff, fill=(58, 37, 30, 255))
    draw.line((1088, 142, 1108, 92, 1138, 76, 1112, 142), fill=(73, 94, 88, 230), width=32)
    draw.line((940, 720, 1088, 135), fill=(107, 74, 55, 135), width=7)

    palm = [(780, 640), (815, 560), (898, 548), (956, 596), (930, 700), (832, 722)]
    draw.polygon(palm, fill=(129, 84, 68, 242))
    draw.polygon(((787, 645), (824, 580), (910, 570), (940, 610), (910, 682), (825, 704)), fill=(167, 115, 92, 210))

    for idx, (x, y, angle) in enumerate([(825, 548, -14), (866, 535, -8), (908, 548, 8), (943, 584, 28)]):
        length = 82 - idx * 8
        end_x = x + math.cos(math.radians(angle)) * length
        end_y = y + math.sin(math.radians(angle)) * length
        draw.line((x, y, end_x, end_y), fill=(164, 108, 86, 242), width=26)
        draw.line((x + 2, y + 3, end_x, end_y), fill=(93, 58, 50, 130), width=4)

    draw.line((805, 660, 780, 710, 836, 712), fill=(82, 49, 44, 165), width=18)
    for _ in range(55):
        x = random.randint(780, 952)
        y = random.randint(545, 705)
        draw.line((x, y, x + random.randint(-8, 8), y + random.randint(-4, 8)), fill=(61, 34, 31, 70), width=1)

    image = image.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
    image.save(ASSET_DIR / "hand_overlay.png")


def create_roadside_tree() -> None:
    width, height = 256, 512
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    rng = random.Random(4096)

    draw.polygon(((118, 510), (146, 510), (139, 220), (120, 220)), fill=(58, 40, 32, 235))
    draw.line((128, 500, 128, 210), fill=(112, 78, 55, 130), width=6)
    for _ in range(46):
        cx = rng.randint(50, 205)
        cy = rng.randint(72, 230)
        radius = rng.randint(28, 58)
        color = (
            rng.randint(19, 45),
            rng.randint(70, 105),
            rng.randint(63, 92),
            rng.randint(130, 210),
        )
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color)

    image = image.filter(ImageFilter.GaussianBlur(radius=0.25))
    image.save(ASSET_DIR / "roadside_tree.png")


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    create_road_strip()
    create_horizon_plate()
    create_hand_overlay()
    create_roadside_tree()
    print(f"generated assets in {ASSET_DIR}")


if __name__ == "__main__":
    main()
