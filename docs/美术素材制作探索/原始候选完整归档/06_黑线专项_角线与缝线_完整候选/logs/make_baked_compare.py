import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

spec = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
try:
    font = ImageFont.truetype("arial.ttf", 22)
except Exception:
    font = ImageFont.load_default()
panels = []
for item in spec["items"]:
    im = Image.open(item["path"]).convert("RGBA")
    bg = Image.new("RGBA", im.size, (245, 244, 239, 255))
    bg.alpha_composite(im)
    scale = 320 / max(bg.size)
    bg = bg.resize((round(bg.width * scale), round(bg.height * scale)), Image.Resampling.LANCZOS).convert("RGB")
    panel = Image.new("RGB", (360, 390), (245, 244, 239))
    panel.paste(bg, ((360 - bg.width) // 2, 52))
    ImageDraw.Draw(panel).text((12, 12), item["label"], fill=(30, 30, 30), font=font)
    panels.append(panel)
out = Image.new("RGB", (360 * len(panels), 390), (245, 244, 239))
for idx, panel in enumerate(panels):
    out.paste(panel, (idx * 360, 0))
Path(spec["out"]).parent.mkdir(parents=True, exist_ok=True)
out.save(spec["out"])