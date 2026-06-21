# texgen.route3_bake_matrix — dual_canvas UV cleanup + Blender bake diagnostics
#
# Run this script inside Blender Python:
#   blender --background blender/test.blend --python blender/scripts/texgen/route3_bake_matrix.py -- <args>
#
# It assumes line_clean.py has already written uv_cleaned/{keep_lines,fade_internal_25,remove_internal}.png.

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

try:
    import bpy  # type: ignore
except Exception as exc:  # pragma: no cover - regular Python should fail early.
    raise SystemExit("route3_bake_matrix.py must run inside Blender Python") from exc


ROUND_A = [
    ("v0_keep_lines", "keep_lines", {}),
    ("v1_fade_internal_25", "fade_internal_25", {}),
    ("v2_remove_internal", "remove_internal", {}),
]

ROUND_B = [
    ("v0_production_current", {}),
    ("v1_crisp_edge", {
        "bevel_width": 0.03,
        "bevel_segments": 1,
        "ink_thickness_px": 2.8,
        "ink_wobble_px": 0.6,
    }),
    ("v2_heavy_ink", {
        "bevel_width": 0.04,
        "bevel_segments": 1,
        "ink_thickness_px": 3.6,
        "ink_wobble_px": 0.8,
    }),
]

ROUND_C = [
    ("v0_production_lighting", {}),
    ("v1_ambient_only", {
        "sun_energy": 0.0,
        "ambient_strength": 0.8,
    }),
    ("v2_freestyle_off", {
        "ink_enabled": False,
    }),
]


ROUND_D = [
    ("v0_crisp_edge", {
        "bevel_width": 0.03,
        "bevel_segments": 1,
        "ink_thickness_px": 2.8,
        "ink_wobble_px": 0.6,
    }),
    ("v1_crisp_no_stitch_ink", {
        "bevel_width": 0.03,
        "bevel_segments": 1,
        "ink_thickness_px": 2.8,
        "ink_wobble_px": 0.6,
        "ink_exclude_wall_stitch_edges": True,
    }),
    ("v2_heavy_no_stitch_ink", {
        "bevel_width": 0.04,
        "bevel_segments": 1,
        "ink_thickness_px": 3.6,
        "ink_wobble_px": 0.8,
        "ink_exclude_wall_stitch_edges": True,
    }),
]


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def _load_bake_assets(repo: Path) -> dict:
    script = repo / "blender" / "scripts" / "bake_assets.py"
    ns = {"__file__": str(script)}
    exec(compile(script.read_text(encoding="utf-8"), str(script), "exec"), ns)
    return ns


def _reset_config(ns: dict, base_config: dict, patch: dict):
    ns["CONFIG"].clear()
    ns["CONFIG"].update(base_config)
    ns["CONFIG"].update(patch)


def _bake_one(ns: dict, base_config: dict, uv_path: Path, patch: dict, out_path: Path):
    _reset_config(ns, base_config, patch)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    ns["bake_tile_candidate"](str(uv_path), "grass", 0, str(out_path))


def _bake_matrix(ns: dict, run_dir: Path, winner: str) -> dict:
    base_config = dict(ns["CONFIG"])
    uv_cleaned = run_dir / "uv_cleaned"
    baked_root = run_dir / "baked"
    results = {}

    round_a = []
    for slot_name, uv_name, patch in ROUND_A:
        uv = uv_cleaned / ("%s.png" % uv_name)
        if not uv.is_file():
            raise FileNotFoundError("missing cleaned UV: %s" % uv)
        out = baked_root / "round_a" / ("%s.png" % slot_name)
        _bake_one(ns, base_config, uv, patch, out)
        round_a.append({"slot": slot_name, "uv": uv_name, "baked": str(out), "config_patch": patch})
    results["round_a"] = round_a

    winner_uv = uv_cleaned / ("%s.png" % winner)
    if not winner_uv.is_file():
        raise FileNotFoundError("winner UV not found: %s" % winner_uv)

    round_b = []
    for slot_name, patch in ROUND_B:
        out = baked_root / "round_b" / ("%s.png" % slot_name)
        _bake_one(ns, base_config, winner_uv, patch, out)
        round_b.append({"slot": slot_name, "uv": winner, "baked": str(out), "config_patch": patch})
    results["round_b"] = round_b

    round_c = []
    for slot_name, patch in ROUND_C:
        out = baked_root / "round_c" / ("%s.png" % slot_name)
        _bake_one(ns, base_config, winner_uv, patch, out)
        round_c.append({"slot": slot_name, "uv": winner, "baked": str(out), "config_patch": patch})
    results["round_c"] = round_c

    round_d = []
    for slot_name, patch in ROUND_D:
        out = baked_root / "round_d" / ("%s.png" % slot_name)
        _bake_one(ns, base_config, winner_uv, patch, out)
        round_d.append({"slot": slot_name, "uv": winner, "baked": str(out), "config_patch": patch})
    results["round_d"] = round_d

    _reset_config(ns, base_config, {})
    return results


def _slots(repo: Path) -> list:
    baked = repo / "inkmon美术探索" / "fable-圆角-v1" / "assets" / "baked"
    return [baked / ("tile_grass_e0_v%d.png" % idx) for idx in range(3)]


def _backup_slots(repo: Path, run_dir: Path) -> Path:
    backup_dir = run_dir / "backups" / "before_route3_bake_matrix"
    backup_dir.mkdir(parents=True, exist_ok=True)
    for slot in _slots(repo):
        if not slot.is_file():
            raise FileNotFoundError("missing baked slot: %s" % slot)
        shutil.copy2(slot, backup_dir / slot.name)
    return backup_dir


def _apply_round(repo: Path, round_items: list) -> list:
    slots = _slots(repo)
    if len(round_items) != len(slots):
        raise ValueError("round has %d items; expected %d" % (len(round_items), len(slots)))
    mapping = []
    for slot, item in zip(slots, round_items):
        src = Path(item["baked"])
        if not src.is_file():
            raise FileNotFoundError("missing baked candidate: %s" % src)
        shutil.copy2(src, slot)
        mapping.append({"slot": str(slot), "candidate": str(src), "label": item["slot"]})
    return mapping


def _restore_slots(repo: Path, backup_dir: Path):
    for slot in _slots(repo):
        src = backup_dir / slot.name
        if src.is_file():
            shutil.copy2(src, slot)


def _run_godot_import(repo: Path, godot: str, log_path: Path):
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("wb") as f:
        proc = subprocess.run(
            [godot, "--headless", "--path", str(repo), "--import"],
            stdout=f,
            stderr=subprocess.STDOUT,
            cwd=str(repo),
        )
    if proc.returncode != 0:
        raise RuntimeError("godot import failed: %s" % log_path)


def _append_jsonl(path: Path, obj: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n")


def _wait_for_file(path: Path, timeout: float):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if path.exists():
            return
        time.sleep(0.25)
    raise TimeoutError("timed out waiting for %s" % path)


def _wait_for_response(outbox: Path, op_id: str, timeout: float) -> dict:
    deadline = time.time() + timeout
    seen = 0
    while time.time() < deadline:
        if outbox.exists():
            lines = outbox.read_text(encoding="utf-8", errors="ignore").splitlines()
            for line in lines[seen:]:
                if not line.strip():
                    continue
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                if obj.get("id") == op_id:
                    return obj
            seen = len(lines)
        time.sleep(0.25)
    raise TimeoutError("timed out waiting for DevAgent id=%s" % op_id)


def _capture_round(repo: Path, run_dir: Path, godot: str, round_name: str, session_prefix: str) -> dict:
    sessions_root = Path(os.environ["APPDATA"]) / "Godot" / "app_userdata" / "Inkmon" / "dev-agent" / "sessions"
    session = "%s-%s" % (session_prefix, round_name)
    session_dir = sessions_root / session
    if session_dir.exists():
        shutil.rmtree(session_dir)
    session_dir.mkdir(parents=True, exist_ok=True)

    stdout = session_dir / "godot.stdout.log"
    stderr = session_dir / "godot.stderr.log"
    flags = 0
    if hasattr(subprocess, "CREATE_NO_WINDOW"):
        flags = subprocess.CREATE_NO_WINDOW
    proc = subprocess.Popen(
        [
            godot,
            "--path",
            str(repo),
            "res://inkmon美术探索/fable-圆角-v1/tile_pipeline_scene.tscn",
            "--",
            "--dev-agent",
            "--dev-agent-session=%s" % session,
        ],
        stdout=stdout.open("wb"),
        stderr=stderr.open("wb"),
        cwd=str(repo),
        creationflags=flags,
    )
    try:
        inbox = session_dir / "inbox.jsonl"
        outbox = session_dir / "outbox.jsonl"
        _wait_for_file(outbox, 45)

        full_id = "%s_full" % round_name
        _append_jsonl(inbox, {"id": full_id, "op": "capture", "label": "%s-full" % round_name, "format": "png", "width": 1600})
        full = _wait_for_response(outbox, full_id, 45)

        view_id = "%s_view" % round_name
        _append_jsonl(inbox, {"id": view_id, "op": "scene", "name": "set_view", "args": {"zoom": 1.0, "x": -60, "y": 40}})
        _wait_for_response(outbox, view_id, 30)

        close_id = "%s_closeup" % round_name
        _append_jsonl(inbox, {"id": close_id, "op": "capture", "label": "%s-closeup" % round_name, "format": "png", "width": 1600})
        close = _wait_for_response(outbox, close_id, 45)

        shots_dir = run_dir / "shots" / round_name
        shots_dir.mkdir(parents=True, exist_ok=True)
        full_dst = shots_dir / "full.png"
        close_dst = shots_dir / "closeup.png"
        shutil.copy2(full["artifacts"][0]["global_path"], full_dst)
        shutil.copy2(close["artifacts"][0]["global_path"], close_dst)
        return {"session": session, "full": str(full_dst), "closeup": str(close_dst)}
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()


def _make_baked_compare(run_dir: Path, round_name: str, items: list, python_exe: str) -> str:
    shots_dir = run_dir / "shots" / round_name
    shots_dir.mkdir(parents=True, exist_ok=True)
    spec = {
        "out": str(shots_dir / "single_baked_tile_compare.png"),
        "items": [{"label": item["slot"], "path": item["baked"]} for item in items],
    }
    spec_path = run_dir / "logs" / ("%s_compare_spec.json" % round_name)
    helper_path = run_dir / "logs" / "make_baked_compare.py"
    _write_json(spec_path, spec)
    helper_path.write_text(
        r'''
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
'''.strip(),
        encoding="utf-8",
    )
    proc = subprocess.run([python_exe, str(helper_path), str(spec_path)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise RuntimeError("baked compare failed: %s" % proc.stderr.decode("utf-8", errors="ignore"))
    return spec["out"]


def _run_scene_rounds(repo: Path, run_dir: Path, godot: str, baked_results: dict, python_exe: str, session_prefix: str) -> dict:
    scene_results = {}
    for round_name, items in baked_results.items():
        mapping = _apply_round(repo, items)
        _write_json(run_dir / "logs" / ("%s_slot_mapping.json" % round_name), mapping)
        _run_godot_import(repo, godot, run_dir / "logs" / ("%s_godot_import.log" % round_name))
        capture = _capture_round(repo, run_dir, godot, round_name, session_prefix)
        compare = _make_baked_compare(run_dir, round_name, items, python_exe)
        scene_results[round_name] = {"mapping": mapping, "capture": capture, "single_baked_tile_compare": compare}
    return scene_results


def main(argv=None):
    ap = argparse.ArgumentParser(description="Bake and screenshot route-3 dual_canvas diagnostics")
    ap.add_argument("--run-dir", required=True)
    ap.add_argument("--repo-root", default=str(_repo_root()))
    ap.add_argument("--winner", choices=["keep_lines", "fade_internal_25", "remove_internal"], default="remove_internal")
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--python-exe", default="python")
    ap.add_argument("--session-prefix", default="tile-pipeline-route3")
    ap.add_argument("--skip-scene", action="store_true")
    ap.add_argument("--leave-round", choices=["restore", "round_a", "round_b", "round_c", "round_d"], default="restore")
    args = ap.parse_args(argv)

    repo = Path(args.repo_root).resolve()
    run_dir = Path(args.run_dir).resolve()
    logs_dir = run_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    ns = _load_bake_assets(repo)
    baked_results = _bake_matrix(ns, run_dir, args.winner)
    _write_json(logs_dir / "bake_presets.json", {
        "winner": args.winner,
        "rounds": baked_results,
        "notes": {
            "round_a": "UV internal line treatment, production bake config",
            "round_b": "Blender bevel/Freestyle config presets using winner UV",
            "round_c": "Lighting/Freestyle diagnostics, not final candidates",
            "round_d": "Wall stitch Freestyle exclusion diagnostics using winner UV",
        },
    })

    scene_results = {}
    backup_dir = _backup_slots(repo, run_dir)
    try:
        if not args.skip_scene:
            scene_results = _run_scene_rounds(repo, run_dir, args.godot, baked_results, args.python_exe, args.session_prefix)
        if args.leave_round == "restore":
            _restore_slots(repo, backup_dir)
            if not args.skip_scene:
                _run_godot_import(repo, args.godot, logs_dir / "restore_godot_import.log")
        else:
            _apply_round(repo, baked_results[args.leave_round])
            if not args.skip_scene:
                _run_godot_import(repo, args.godot, logs_dir / ("%s_left_applied_import.log" % args.leave_round))
    except Exception:
        _restore_slots(repo, backup_dir)
        if not args.skip_scene:
            try:
                _run_godot_import(repo, args.godot, logs_dir / "restore_after_error_godot_import.log")
            except Exception:
                pass
        raise

    summary = {
        "run_dir": str(run_dir),
        "winner": args.winner,
        "baked_results": baked_results,
        "scene_results": scene_results,
        "backup_dir": str(backup_dir),
        "leave_round": args.leave_round,
    }
    _write_json(logs_dir / "route3_bake_matrix_summary.json", summary)
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
