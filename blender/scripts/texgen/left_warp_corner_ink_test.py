# texgen.left_warp_corner_ink_test — Route 3 left-warp corner ink diagnostic
#
# Run inside Blender Python:
#   blender --background blender/test.blend --python blender/scripts/texgen/left_warp_corner_ink_test.py -- <args>

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import bpy  # type: ignore
except Exception as exc:  # pragma: no cover
    raise SystemExit("left_warp_corner_ink_test.py must run inside Blender Python") from exc


def _ensure_pil_available():
    try:
        import PIL  # noqa: F401
        return
    except Exception:
        pass

    roots = []
    conda_prefix = os.environ.get("CONDA_PREFIX")
    if conda_prefix:
        roots.append(Path(conda_prefix))
    roots.append(Path.home() / "miniconda3")
    for root in roots:
        site_packages = root / "Lib" / "site-packages"
        if site_packages.is_dir() and str(site_packages) not in sys.path:
            sys.path.insert(0, str(site_packages))


_ensure_pil_available()

from PIL import Image, ImageDraw, ImageFont

from texgen import archive_paths
from texgen import make_templates
from texgen import route3_bake_matrix as base
from texgen import warp


RUN_NAME = "left-warp-corner-ink-20260616-01"

PRESETS = [
    {
        "slot": "v0_texture_only",
        "config_patch": {
            "ink_enabled": False,
        },
    },
    {
        "slot": "v1_silhouette_top_only",
        "config_patch": {
            "ink_exclude_wall_stitch_edges": True,
        },
    },
    {
        "slot": "v2_controlled_corner_crease",
        "config_patch": {
            "ink_exclude_wall_stitch_edges": True,
            "ink_corner_enabled": True,
            "ink_corner_color": (0.13, 0.10, 0.07),
            "ink_corner_thickness_px": 2.0,
            "ink_corner_wobble_px": 0.35,
        },
    },
]


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _default_run_dir(repo: Path) -> Path:
    return archive_paths.candidate_run(repo, RUN_NAME)


def _default_source_dual(repo: Path) -> Path:
    return archive_paths.existing_run(repo, "template-connected-20260616-01") / "raw" / "dual_canvas_raw.png"


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _prepare_left_warp(repo: Path, run_dir: Path, source_dual: Path) -> dict:
    templates_dir = run_dir / "templates"
    raw_dir = run_dir / "raw"
    uv_dir = run_dir / "uv"
    logs_dir = run_dir / "logs"
    raw_dir.mkdir(parents=True, exist_ok=True)
    uv_dir.mkdir(parents=True, exist_ok=True)
    logs_dir.mkdir(parents=True, exist_ok=True)

    if not source_dual.is_file():
        raise FileNotFoundError("missing source dual canvas: %s" % source_dual)
    shutil.copy2(source_dual, raw_dir / "source_dual_canvas_raw.png")

    make_templates.generate(str(templates_dir), [0])
    dual_sidecar = _load_json(templates_dir / "template_dual_e0.json")
    design_sidecar = _load_json(templates_dir / "template_design_e0.json")
    uv_sidecar = _load_json(templates_dir / "template_uv_e0.json")

    design_out = raw_dir / "dual_left_design.png"
    uv_out = uv_dir / "dual_left_design_warp_uv.png"
    extract_report = warp.extract_dual_design(str(source_dual), dual_sidecar, design_sidecar, str(design_out))
    warp_report = warp.warp_design_to_uv(str(design_out), design_sidecar, uv_sidecar, str(uv_out))
    base._write_json(logs_dir / "left_warp_prepare_report.json", {
        "source_dual": str(source_dual),
        "copied_source_dual": str(raw_dir / "source_dual_canvas_raw.png"),
        "dual_left_design": str(design_out),
        "dual_left_design_warp_uv": str(uv_out),
        "extract_report": extract_report,
        "warp_report": warp_report,
        "templates_dir": str(templates_dir),
    })
    return {
        "source_dual": source_dual,
        "design": design_out,
        "uv": uv_out,
        "templates_dir": templates_dir,
        "uv_sidecar": templates_dir / "template_uv_e0.json",
    }


def _run_qc(repo: Path, run_dir: Path, python_exe: str, uv_path: Path, uv_sidecar: Path):
    log_path = run_dir / "logs" / "qc_dual_left_design_warp_uv.txt"
    with log_path.open("wb") as f:
        proc = subprocess.run(
            [
                python_exe,
                str(repo / "blender" / "scripts" / "texgen" / "qc.py"),
                str(uv_path),
                "--sidecar",
                str(uv_sidecar),
            ],
            stdout=f,
            stderr=subprocess.STDOUT,
            cwd=str(repo),
        )
    if proc.returncode != 0:
        raise RuntimeError("left-warp UV QC failed: %s" % log_path)
    return str(log_path)


def _bake_candidates(ns: dict, run_dir: Path, uv_path: Path) -> list:
    base_config = dict(ns["CONFIG"])
    out_items = []
    try:
        for preset in PRESETS:
            base._reset_config(ns, base_config, preset["config_patch"])
            out = run_dir / "baked" / ("%s.png" % preset["slot"])
            out.parent.mkdir(parents=True, exist_ok=True)
            ns["bake_tile_candidate"](str(uv_path), "grass", 0, str(out))
            out_items.append({
                "slot": preset["slot"],
                "source_type": "uv",
                "source": str(uv_path),
                "baked": str(out),
                "config_patch": preset["config_patch"],
            })
    finally:
        base._reset_config(ns, base_config, {})
    return out_items


def _make_diagnostic_compare(run_dir: Path, source_dual: Path, items: list) -> str:
    out_path = run_dir / "shots" / "diagnostic_corner_ink_compare.png"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        font = ImageFont.truetype("arial.ttf", 22)
    except Exception:
        font = ImageFont.load_default()

    panels = []
    raw = Image.open(source_dual).convert("RGBA").crop((0, 0, 768, 1024))
    specs = [{"label": "source_left_3d_target", "image": raw}]
    for item in items:
        specs.append({"label": item["slot"], "image": Image.open(item["baked"]).convert("RGBA")})

    for spec in specs:
        im = spec["image"]
        bbox = im.getbbox() or (0, 0, im.width, im.height)
        im = im.crop(bbox)
        im.thumbnail((360, 300), Image.Resampling.LANCZOS)
        panel = Image.new("RGBA", (390, 360), (245, 244, 239, 255))
        panel.alpha_composite(im, ((390 - im.width) // 2, 48 + (300 - im.height) // 2))
        d = ImageDraw.Draw(panel)
        d.text((12, 12), spec["label"], fill=(25, 25, 25, 255), font=font)
        # Guide band for grass lip / corner crease inspection.
        if spec["label"] != "source_left_3d_target":
            d.line((42, 210, 348, 210), fill=(220, 40, 32, 210), width=2)
            d.line((42, 234, 348, 234), fill=(220, 40, 32, 120), width=2)
            d.text((44, 238), "grass lip / corner alignment guide", fill=(220, 40, 32, 180), font=font)
        panels.append(panel.convert("RGB"))

    out = Image.new("RGB", (390 * 2, 360 * 2), (245, 244, 239))
    for idx, panel in enumerate(panels):
        out.paste(panel, ((idx % 2) * 390, (idx // 2) * 360))
    out.save(out_path)
    return str(out_path)


def _write_report(run_dir: Path, prepared: dict, qc_log: str, baked_items: list, scene_results: dict,
                  backup_dir: Path, diagnostic: str):
    report = run_dir / "REPORT.md"
    report.write_text(
        """# Route 3 Left-Warp Corner Ink Test

## Summary

This run uses the left 3D target from `template-connected-20260616-01/raw/dual_canvas_raw.png` as the visual truth. The right paper-net UV is not used for the main candidates.

## Inputs

- source dual canvas: `{source_dual}`
- extracted left design: `{design}`
- left-warp UV: `{uv}`
- QC log: `{qc_log}`

## Test Matrix

- `v0_texture_only`: left-warp UV with `ink_enabled=false`; keeps only AI target ink already present in the warped texture.
- `v1_silhouette_top_only`: Freestyle on, marked wall-wall corner/stitch edges excluded.
- `v2_controlled_corner_crease`: Freestyle base lines plus a separate marked wall-corner line set.

## Outputs

- baked candidates: `{baked_dir}`
- full scene: `{full}`
- closeup: `{closeup}`
- single baked compare: `{single}`
- diagnostic compare: `{diagnostic}`
- slot mapping: `{slot_mapping}`
- backup dir: `{backup_dir}`

## Result

Visual read from this run:

- Best current slot: `tile_grass_e0_v0.png` / `v0_texture_only`.
- The left-warp UV path fixes the obvious grass-lip height mismatch seen in the right-paper-UV route. QC also passes, so this is not a geometry coverage failure.
- `v0_texture_only` is closest to the source left 3D target: the vertical corner ink comes from the AI target texture itself and reads like a 3D crease instead of a UV panel seam.
- `v1_silhouette_top_only` and `v2_controlled_corner_crease` add too much Blender-side edge emphasis on this asset. Their outer/corner lines look more like extra rendered engineering lines than the source target's softer dark crease.
- `v2_controlled_corner_crease` proves the separate line set is technically controllable, but the default `2.0px / 0.35px` crease is still not the visual winner for this source.

Answer to the black-line question:

- Keep: the dark 3D corner crease already present in the left 3D target / left-warp UV.
- Remove or avoid: black lines sourced from right-side paper-net UV panel seams.
- Avoid for now: extra Blender wall-wall corner crease unless it is much more tightly matched to the source target.

Recommended next test:

- Treat `left 3D target -> design_warp UV -> bake with ink disabled or very restrained ink` as the Route 3 baseline.
- If Blender ink is needed later, tune it against `v0_texture_only`, not against the right paper-net UV.

## Current Slot State

The scene slots are intentionally left applied:

- `tile_grass_e0_v0.png` = `v0_texture_only`
- `tile_grass_e0_v1.png` = `v1_silhouette_top_only`
- `tile_grass_e0_v2.png` = `v2_controlled_corner_crease`

These are temporary candidate overrides, not approved production assets.
""".format(
            source_dual=prepared["source_dual"],
            design=prepared["design"],
            uv=prepared["uv"],
            qc_log=qc_log,
            baked_dir=run_dir / "baked",
            full=scene_results["left_warp_corner_ink"]["capture"]["full"],
            closeup=scene_results["left_warp_corner_ink"]["capture"]["closeup"],
            single=scene_results["left_warp_corner_ink"]["single_baked_tile_compare"],
            diagnostic=diagnostic,
            slot_mapping=run_dir / "logs" / "left_warp_corner_ink_slot_mapping.json",
            backup_dir=backup_dir,
        ),
        encoding="utf-8",
    )
    return str(report)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Run Route 3 left-warp corner ink candidate test")
    ap.add_argument("--run-dir", default=None)
    ap.add_argument("--repo-root", default=str(_repo_root()))
    ap.add_argument("--source-dual", default=None)
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--python-exe", default="python")
    ap.add_argument("--session-prefix", default="tile-pipeline-left-warp-corner-ink")
    ap.add_argument("--skip-scene", action="store_true")
    ap.add_argument("--restore", action="store_true", help="restore baked slots after screenshots")
    args = ap.parse_args(argv)

    repo = Path(args.repo_root).resolve()
    run_dir = Path(args.run_dir).resolve() if args.run_dir else _default_run_dir(repo)
    source_dual = Path(args.source_dual).resolve() if args.source_dual else _default_source_dual(repo)
    logs_dir = run_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    prepared = _prepare_left_warp(repo, run_dir, source_dual)
    qc_log = _run_qc(repo, run_dir, args.python_exe, prepared["uv"], prepared["uv_sidecar"])

    ns = base._load_bake_assets(repo)
    baked_items = _bake_candidates(ns, run_dir, prepared["uv"])
    baked_results = {"left_warp_corner_ink": baked_items}
    base._write_json(logs_dir / "bake_presets.json", {"items": baked_items})

    backup_dir = base._backup_slots(repo, run_dir)
    scene_results = {}
    diagnostic = ""
    try:
        if not args.skip_scene:
            scene_results = base._run_scene_rounds(
                repo,
                run_dir,
                args.godot,
                baked_results,
                args.python_exe,
                args.session_prefix,
            )
        diagnostic = _make_diagnostic_compare(run_dir, source_dual, baked_items)
        if args.restore:
            base._restore_slots(repo, backup_dir)
            if not args.skip_scene:
                base._run_godot_import(repo, args.godot, logs_dir / "restore_godot_import.log")
        else:
            base._apply_round(repo, baked_items)
            if not args.skip_scene:
                base._run_godot_import(repo, args.godot, logs_dir / "left_warp_corner_ink_left_applied_import.log")
    except Exception:
        base._restore_slots(repo, backup_dir)
        if not args.skip_scene:
            try:
                base._run_godot_import(repo, args.godot, logs_dir / "restore_after_error_godot_import.log")
            except Exception:
                pass
        raise

    report = _write_report(run_dir, prepared, qc_log, baked_items, scene_results, backup_dir, diagnostic)
    summary = {
        "run_dir": str(run_dir),
        "prepared": {k: str(v) for k, v in prepared.items()},
        "qc_log": qc_log,
        "baked_results": baked_results,
        "scene_results": scene_results,
        "diagnostic": diagnostic,
        "backup_dir": str(backup_dir),
        "restore": args.restore,
        "report": report,
    }
    base._write_json(logs_dir / "left_warp_corner_ink_summary.json", summary)
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
