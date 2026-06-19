# Generate a single 3D design template with an explicit outline width.
#
# Candidate helper for template-line-width experiments. The sidecar geometry is
# unchanged; only the raster/SVG line width changes.

import argparse
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from texgen import geometry as G
from texgen import make_templates


def generate(out_dir: str, elevation: int, line_width: int, stem: str) -> dict:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    manifest = G.load_manifest()
    layout = G.design_layout(manifest, elevation)

    old_line_w = make_templates.LINE_W
    try:
        make_templates.LINE_W = int(line_width)
        sheet = make_templates.draw_design(layout)
        paths = sheet.save(str(out / stem))
    finally:
        make_templates.LINE_W = old_line_w

    sidecar = out / ("%s.json" % stem)
    sidecar.write_text(json.dumps(layout, ensure_ascii=False, indent=2), encoding="utf-8")
    return {
        "template": "design",
        "elevation": elevation,
        "line_width": line_width,
        "stem": stem,
        "paths": paths + [str(sidecar)],
        "note": "Geometry sidecar is the standard design layout; only line width differs.",
    }


def main():
    ap = argparse.ArgumentParser(description="Generate one design template with explicit line width")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("-e", "--elevation", type=int, choices=[0, 1, 2], default=0)
    ap.add_argument("--line-width", type=int, required=True)
    ap.add_argument("--stem", default=None)
    args = ap.parse_args()
    stem = args.stem or "template_design_e%d_line%d" % (args.elevation, args.line_width)
    report = generate(args.out, args.elevation, args.line_width, stem)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
