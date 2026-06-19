from __future__ import annotations

import json
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


RUN_DIR = Path(__file__).resolve().parent
REPO_ROOT = Path(__file__).resolve().parents[4]
GOAL_DIR = REPO_ROOT / ".codex-goal" / "blender-owned-tile-seam"
BLENDER_SCENE_SCRIPT = RUN_DIR / "blender_owned_tile_seam_scene.py"

RAW_DIR = REPO_ROOT / "blender" / "textures" / "_candidates" / "single-stage-tile-6-variants-20260617-01" / "raw"
CONCEPT_REF = REPO_ROOT / "docs" / "concept.jpg"
TILE_PIPELINE_SCENE = REPO_ROOT / "inkmon" / "tools" / "tile_pipeline" / "tile_pipeline_scene.gd"

RAW_TILES = [
    ("grass_meadow", RAW_DIR / "tile_01_grass_meadow.png"),
    ("cracked_dry_earth", RAW_DIR / "tile_02_cracked_dry_earth.png"),
    ("mossy_flagstone", RAW_DIR / "tile_03_mossy_flagstone.png"),
    ("dirt_arena", RAW_DIR / "tile_04_dirt_arena.png"),
    ("pale_limestone", RAW_DIR / "tile_05_pale_limestone.png"),
    ("dark_forest_floor", RAW_DIR / "tile_06_dark_forest_floor.png"),
]

BLENDER_CANDIDATES = [
    Path(r"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe"),
    Path(r"C:\Program Files\Blender Foundation\Blender 4.0\blender.exe"),
    Path(r"C:\Program Files\Blender Foundation\Blender 3.6\blender.exe"),
]


def rel(path: Path) -> str:
    return path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def find_blender() -> Path:
    for path in BLENDER_CANDIDATES:
        if path.exists():
            return path
    raise FileNotFoundError("Blender executable not found in known install paths.")


def load_font(size: int = 18) -> ImageFont.ImageFont:
    for name in ("arial.ttf", "segoeui.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def run_blender_render() -> Path:
    blender = find_blender()
    cmd = [
        str(blender),
        "--background",
        "--python",
        str(BLENDER_SCENE_SCRIPT),
    ]
    result = subprocess.run(cmd, cwd=str(REPO_ROOT), text=True, capture_output=True, check=False)
    (RUN_DIR / "logs").mkdir(parents=True, exist_ok=True)
    (RUN_DIR / "logs" / "blender_stdout.txt").write_text(result.stdout, encoding="utf-8", errors="replace")
    (RUN_DIR / "logs" / "blender_stderr.txt").write_text(result.stderr, encoding="utf-8", errors="replace")
    if result.returncode != 0:
        raise RuntimeError(f"Blender render failed with exit code {result.returncode}. See logs/blender_stdout.txt and logs/blender_stderr.txt")
    return blender


def make_contact_sheet(out_path: Path) -> str:
    font = load_font(18)
    panel_w, panel_h = 420, 360
    sheet = Image.new("RGB", (panel_w * 3, panel_h * 2), (232, 229, 218))
    for i, (label, path) in enumerate(RAW_TILES):
        img = Image.open(path).convert("RGB")
        img.thumbnail((panel_w - 40, panel_h - 70), Image.Resampling.LANCZOS)
        panel = Image.new("RGB", (panel_w, panel_h), (241, 238, 228))
        panel.paste(img, ((panel_w - img.width) // 2, 48 + (panel_h - 70 - img.height) // 2))
        draw = ImageDraw.Draw(panel)
        draw.text((16, 16), f"tile_{i + 1:02d} {label}", fill=(32, 31, 27), font=font)
        sheet.paste(panel, ((i % 3) * panel_w, (i // 3) * panel_h))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path)
    return rel(out_path)


def make_zoom_compare(baseline_path: Path, seam_path: Path, out_path: Path) -> str:
    base = Image.open(baseline_path).convert("RGB")
    seam = Image.open(seam_path).convert("RGB")
    crop_w, crop_h = 760, 460
    left = max(0, (base.width - crop_w) // 2)
    top = max(0, (base.height - crop_h) // 2)
    box = (left, top, left + crop_w, top + crop_h)
    base_crop = base.crop(box).resize((840, 508), Image.Resampling.LANCZOS)
    seam_crop = seam.crop(box).resize((840, 508), Image.Resampling.LANCZOS)

    out = Image.new("RGB", (1680, 572), (34, 34, 31))
    out.paste(base_crop, (0, 64))
    out.paste(seam_crop, (840, 64))
    draw = ImageDraw.Draw(out)
    font = load_font(24)
    draw.text((24, 20), "Blender render baseline", fill=(235, 231, 210), font=font)
    draw.text((864, 20), "Blender render with deterministic seam", fill=(235, 231, 210), font=font)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out.save(out_path)
    return rel(out_path)


def image_size(path: Path) -> list[int]:
    img = Image.open(path)
    return [img.width, img.height]


def write_reports(outputs: dict, metadata: dict) -> None:
    iteration_log = [
        {
            "round": 1,
            "name": "pil-sprite-compositor-rejected",
            "observation": "The first candidate used raw tile images as 2D compositing inputs, so it could not validate Blender geometry, occlusion, or seam ownership.",
            "optimization": "Rejected as a diagnostic only; not used as final preview.",
            "changed_params": {"draw_mode": "rejected_pil_compositor"},
            "output": "superseded",
            "closer_than_previous": False,
        },
        {
            "round": 2,
            "name": "blender-mesh-render",
            "observation": "Final candidate must render from Blender-owned geometry; raw images are only per-face texture sources.",
            "optimization": "Build hex prism meshes in Blender, omit side walls on same-height shared edges, add deterministic seam strips as Blender mesh geometry, and render baseline/seam with Blender.",
            "changed_params": metadata["params"],
            "output": outputs["seam_preview"],
            "closer_than_previous": True,
        },
    ]
    write_json(RUN_DIR / "logs" / "iteration_log.json", iteration_log)

    report = (
        "# Blender-Owned Tile Seam Prototype\n\n"
        "## Result\n\n"
        "Best preview is a Blender render, not a PIL/raw sprite map. The six raw tile images are used only as per-face texture sources on Blender hex mesh geometry. Shared same-height edges do not get side walls; they get a deterministic narrow seam strip and a subtle highlight strip rendered by Blender.\n\n"
        "## Outputs\n\n"
        f"- no seam baseline: `{outputs['baseline']}`\n"
        f"- seam preview: `{outputs['seam_preview']}`\n"
        f"- zoom compare: `{outputs['zoom_compare']}`\n"
        f"- contact sheet: `{outputs['contact_sheet']}`\n"
        f"- seam geometry / render metadata: `{outputs['seam_geometry']}`\n"
        f"- Blender stdout: `{outputs['blender_stdout']}`\n"
        f"- Blender stderr: `{outputs['blender_stderr']}`\n\n"
        "## Blender Ownership\n\n"
        f"- Renderer: `{metadata['renderer']}`\n"
        f"- Draw mode: `{metadata['draw_mode']}`\n"
        f"- Raw usage: `{metadata['raw_usage']}`\n"
        f"- Side wall policy: `{metadata['side_wall_policy']}`\n"
        f"- Project reference checked: `{rel(TILE_PIPELINE_SCENE)}` uses projected-center painter sorting for `Sprite2D`; this candidate moves the approved ordering/seam concern into Blender mesh geometry instead of PIL compositing.\n\n"
        "## Best Parameters\n\n"
        "```json\n"
        + json.dumps(metadata["params"], ensure_ascii=False, indent=2)
        + "\n```\n\n"
        "## Validation\n\n"
        f"- `map_no_seam_baseline.png` size: `{outputs['baseline_size']}`.\n"
        f"- `map_blender_seam_preview.png` size: `{outputs['seam_size']}`.\n"
        f"- Shared edges: `{metadata['shared_edge_count']}` Blender seam edges.\n"
        f"- Map cells: `{metadata['cell_count']}` cells using all six raw tile textures.\n"
        "- Production `tile_pipeline_scene.tscn`, `tile_pipeline_scene.gd`, baked manifest, and ADR files were not modified.\n\n"
        "## Failed / Rejected Direction\n\n"
        "- Rejected direct raw/PIL map compositing: it can inspect texture fit, but it cannot validate Blender camera, mesh occlusion, or deterministic seam ownership.\n\n"
        "## Formal Integration Next Steps\n\n"
        "- Move the accepted Blender mesh seam generation into the real Blender asset/map bake pipeline.\n"
        "- Decide whether production keeps exterior-only side walls for same-height maps or continues Sprite2D painter assembly for runtime.\n"
        "- Add manifest fields only after the Blender-rendered seam behavior is approved.\n"
    )
    (RUN_DIR / "REPORT.md").write_text(report, encoding="utf-8")

    GOAL_DIR.mkdir(parents=True, exist_ok=True)
    (GOAL_DIR / "Progress.md").write_text(
        "# Progress\n\n"
        "Completed final correction pass after rejecting raw/PIL map compositing.\n\n"
        "- Round 1: rejected PIL sprite compositor because it did not validate Blender-owned geometry.\n"
        "- Round 2: generated Blender mesh render with raw images used only as face textures, shared edges as deterministic Blender seam geometry.\n",
        encoding="utf-8",
    )
    (GOAL_DIR / "Closeout.md").write_text(
        "# Closeout\n\n"
        "## Status\n\n"
        "Candidate prototype is now Blender-rendered.\n\n"
        "## Best Preview\n\n"
        f"- `{outputs['seam_preview']}`\n"
        f"- `{outputs['zoom_compare']}`\n\n"
        "## Stop Reason\n\n"
        "The output now satisfies the corrected interpretation of Blender-owned: final map images come from Blender render, while raw tile images are only texture inputs.\n",
        encoding="utf-8",
    )


def main() -> None:
    RUN_DIR.mkdir(parents=True, exist_ok=True)
    for _label, path in RAW_TILES:
        if not path.exists():
            raise FileNotFoundError(path)
    blender = run_blender_render()

    metadata = read_json(RUN_DIR / "seam_geometry.json")
    baseline = RUN_DIR / "map_no_seam_baseline.png"
    seam = RUN_DIR / "map_blender_seam_preview.png"
    outputs = {
        "blender": str(blender),
        "baseline": rel(baseline),
        "seam_preview": rel(seam),
        "zoom_compare": make_zoom_compare(baseline, seam, RUN_DIR / "map_seam_zoom_compare.png"),
        "contact_sheet": make_contact_sheet(RUN_DIR / "tile_contact_sheet.png"),
        "seam_geometry": rel(RUN_DIR / "seam_geometry.json"),
        "iteration_log": rel(RUN_DIR / "logs" / "iteration_log.json"),
        "blender_stdout": rel(RUN_DIR / "logs" / "blender_stdout.txt"),
        "blender_stderr": rel(RUN_DIR / "logs" / "blender_stderr.txt"),
        "baseline_size": image_size(baseline),
        "seam_size": image_size(seam),
        "draw_mode": metadata["draw_mode"],
    }
    write_reports(outputs, metadata)
    write_json(RUN_DIR / "logs" / "outputs.json", outputs)
    print(json.dumps(outputs, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
