"""Bake Godot art exploration assets without changing production defaults.

Examples from repo root:
  blender --background blender/test.blend --python blender/scripts/bake_art_exploration_assets.py -- --pipeline hard --out-rel //../inkmon美术探索/codex-硬边-v1/assets/baked
"""

import argparse
import json
import os
import sys
import traceback


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import bake_assets  # noqa: E402


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Bake asset sets for inkmon美术探索 scenes.")
    parser.add_argument("--pipeline", required=True, help="tile pipeline alias: 圆边/硬边/倒角/mode1/mode2/mode3")
    parser.add_argument("--out-rel", required=True, help="Blender // relative output directory")
    parser.add_argument("--samples", type=int, default=32)
    parser.add_argument("--subset", default="", help="Optional comma-separated asset names")
    args = parser.parse_args(argv)

    try:
        spec = bake_assets.apply_tile_pipeline_mode(args.pipeline)
        bake_assets.CONFIG["output_rel"] = args.out_rel
        bake_assets.CONFIG["samples"] = args.samples
        subset = set(args.subset.split(",")) if args.subset else None
        manifest_path = bake_assets.bake_all(subset=subset)
        print(json.dumps({
            "ok": True,
            "pipeline": spec["id"],
            "pipeline_name": spec["zh_name"],
            "manifest_path": manifest_path,
            "output_rel": args.out_rel,
            "samples": args.samples,
        }, ensure_ascii=False, indent=2))
        return 0
    except Exception as exc:
        print(json.dumps({
            "ok": False,
            "error": repr(exc),
            "traceback": traceback.format_exc(),
        }, ensure_ascii=False, indent=2))
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []))
