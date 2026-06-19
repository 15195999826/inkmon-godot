# texgen.route3_first_round — run Route 3 Group A/B/D candidate matrix
#
# Run inside Blender Python after preparing:
#   uv_cleaned/{keep_lines,remove_internal,fade_all_guides_25}.png
#   atlas/dual_atlas_atlas.png

import argparse
import json
import sys
from pathlib import Path

try:
    import bpy  # type: ignore
except Exception as exc:  # pragma: no cover
    raise SystemExit("route3_first_round.py must run inside Blender Python") from exc

from texgen import route3_bake_matrix as base


CRISP = {
    "bevel_width": 0.03,
    "bevel_segments": 1,
    "ink_thickness_px": 2.8,
    "ink_wobble_px": 0.6,
}

CRISP_NO_STITCH = {
    **CRISP,
    "ink_exclude_wall_stitch_edges": True,
}

HEAVY_NO_STITCH = {
    "bevel_width": 0.04,
    "bevel_segments": 1,
    "ink_thickness_px": 3.6,
    "ink_wobble_px": 0.8,
    "ink_exclude_wall_stitch_edges": True,
}

SHARP_NO_STITCH = {
    "bevel_width": 0.02,
    "bevel_segments": 1,
    "ink_thickness_px": 2.6,
    "ink_wobble_px": 0.45,
    "ink_exclude_wall_stitch_edges": True,
}


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _bake_one(ns: dict, base_config: dict, source_path: Path, source_type: str, patch: dict, out_path: Path):
    base._reset_config(ns, base_config, patch)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if source_type == "atlas":
        ns["bake_tile_atlas_candidate"](str(source_path), "grass", 0, str(out_path))
    elif source_type == "uv":
        ns["bake_tile_candidate"](str(source_path), "grass", 0, str(out_path))
    else:
        raise ValueError("unknown source_type: %s" % source_type)


def _group_specs(run_dir: Path) -> dict:
    uv = run_dir / "uv_cleaned"
    atlas = run_dir / "atlas" / "dual_atlas_atlas.png"
    return {
        "group_a": [
            {
                "slot": "v0_paper_crisp",
                "source_type": "uv",
                "source": uv / "keep_lines.png",
                "config_patch": CRISP,
            },
            {
                "slot": "v1_clean_no_stitch",
                "source_type": "uv",
                "source": uv / "remove_internal.png",
                "config_patch": CRISP_NO_STITCH,
            },
            {
                "slot": "v2_outer_fade_no_stitch",
                "source_type": "uv",
                "source": uv / "fade_all_guides_25.png",
                "config_patch": CRISP_NO_STITCH,
            },
        ],
        "group_b": [
            {
                "slot": "v0_strip_production",
                "source_type": "atlas",
                "source": atlas,
                "config_patch": {},
            },
            {
                "slot": "v1_strip_crisp_no_stitch",
                "source_type": "atlas",
                "source": atlas,
                "config_patch": CRISP_NO_STITCH,
            },
            {
                "slot": "v2_strip_heavy_no_stitch",
                "source_type": "atlas",
                "source": atlas,
                "config_patch": HEAVY_NO_STITCH,
            },
        ],
        "group_d": [
            {
                "slot": "v0_atlas_production",
                "source_type": "atlas",
                "source": atlas,
                "config_patch": {},
            },
            {
                "slot": "v1_atlas_crisp_no_stitch",
                "source_type": "atlas",
                "source": atlas,
                "config_patch": CRISP_NO_STITCH,
            },
            {
                "slot": "v2_atlas_sharp_no_stitch",
                "source_type": "atlas",
                "source": atlas,
                "config_patch": SHARP_NO_STITCH,
            },
        ],
    }


def _bake_groups(ns: dict, run_dir: Path) -> dict:
    base_config = dict(ns["CONFIG"])
    baked_results = {}
    for group_name, specs in _group_specs(run_dir).items():
        out_items = []
        for spec in specs:
            src = Path(spec["source"])
            if not src.is_file():
                raise FileNotFoundError("missing %s source: %s" % (group_name, src))
            out = run_dir / "baked" / group_name / ("%s.png" % spec["slot"])
            _bake_one(ns, base_config, src, spec["source_type"], spec["config_patch"], out)
            out_items.append({
                "slot": spec["slot"],
                "source_type": spec["source_type"],
                "source": str(src),
                "baked": str(out),
                "config_patch": spec["config_patch"],
            })
        baked_results[group_name] = out_items
    base._reset_config(ns, base_config, {})
    return baked_results


def main(argv=None):
    ap = argparse.ArgumentParser(description="Run Route 3 first-round Group A/B/D bake and scene matrix")
    ap.add_argument("--run-dir", required=True)
    ap.add_argument("--repo-root", default=str(_repo_root()))
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--python-exe", default="python")
    ap.add_argument("--session-prefix", default="tile-pipeline-route3-first-round")
    ap.add_argument("--skip-scene", action="store_true")
    ap.add_argument("--leave-group", choices=["restore", "group_a", "group_b", "group_d"], default="restore")
    args = ap.parse_args(argv)

    repo = Path(args.repo_root).resolve()
    run_dir = Path(args.run_dir).resolve()
    logs_dir = run_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    ns = base._load_bake_assets(repo)
    baked_results = _bake_groups(ns, run_dir)
    base._write_json(logs_dir / "first_round_bake_presets.json", {
        "groups": baked_results,
        "notes": {
            "group_a": "Paper-net salvage: seam clean plus no stitch Freestyle / outer guide fade",
            "group_b": "Continuous wall strip atlas mapping with production/crisp/heavy edge presets",
            "group_d": "Mesh and edge calibration using the Group B atlas material source",
        },
    })

    scene_results = {}
    backup_dir = base._backup_slots(repo, run_dir)
    try:
        if not args.skip_scene:
            scene_results = base._run_scene_rounds(
                repo, run_dir, args.godot, baked_results, args.python_exe, args.session_prefix
            )
        if args.leave_group == "restore":
            base._restore_slots(repo, backup_dir)
            if not args.skip_scene:
                base._run_godot_import(repo, args.godot, logs_dir / "restore_godot_import.log")
        else:
            base._apply_round(repo, baked_results[args.leave_group])
            if not args.skip_scene:
                base._run_godot_import(repo, args.godot, logs_dir / ("%s_left_applied_import.log" % args.leave_group))
    except Exception:
        base._restore_slots(repo, backup_dir)
        if not args.skip_scene:
            try:
                base._run_godot_import(repo, args.godot, logs_dir / "restore_after_error_godot_import.log")
            except Exception:
                pass
        raise

    summary = {
        "run_dir": str(run_dir),
        "baked_results": baked_results,
        "scene_results": scene_results,
        "backup_dir": str(backup_dir),
        "leave_group": args.leave_group,
    }
    base._write_json(logs_dir / "route3_first_round_summary.json", summary)
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
