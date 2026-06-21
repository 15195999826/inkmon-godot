from __future__ import annotations

import argparse
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from PIL import Image


TERRAINS = ("grass", "dirt", "stone", "water")
ELEVATIONS = (0, 1, 2)
DECORS = ("decor_pine", "decor_pine_tall", "decor_bush", "decor_rocks")
TILE_IDS = [f"{terrain}_e{elevation}" for terrain in TERRAINS for elevation in ELEVATIONS]
TILE_ASSET_IDS = [f"tile_{tile_id}" for tile_id in TILE_IDS]


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def docs_dir(repo: Path) -> Path:
    return repo / "docs" / "美术素材制作探索"


def concept_root(repo: Path) -> Path:
    return repo / "inkmon美术探索" / "concept素材-v1"


def texture_calls_root() -> Path:
    return Path(os.environ.get("APPDATA", "")) / "InkMon" / "Lab" / "texture-gen" / "calls"


def rel(repo: Path, path: Path | None) -> str | None:
    if path is None:
        return None
    resolved = path.resolve()
    try:
        return resolved.relative_to(repo.resolve()).as_posix()
    except ValueError:
        return str(resolved)


def repo_path(repo: Path, value: str | Path | None) -> Path | None:
    if value is None:
        return None
    path = Path(value)
    return path if path.is_absolute() else repo / path


def portable_ref(repo: Path, path: Path | str | None) -> str | None:
    if path is None:
        return None
    resolved = Path(path).resolve()
    try:
        return resolved.relative_to(repo.resolve()).as_posix()
    except ValueError:
        pass
    root = texture_calls_root().resolve()
    try:
        return "%APPDATA%/InkMon/Lab/texture-gen/calls/" + resolved.relative_to(root).as_posix()
    except ValueError:
        return f"<external>/{resolved.name}"


def portable_inputs(repo: Path, inputs: list[dict]) -> list[dict]:
    portable: list[dict] = []
    for item in inputs:
        copy = dict(item)
        if copy.get("sourcePath"):
            copy["sourcePath"] = portable_ref(repo, copy["sourcePath"])
        return_value = copy.get("resolvedPath")
        if return_value:
            copy["resolvedPath"] = portable_ref(repo, return_value)
        portable.append(copy)
    return portable


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def image_size(path: Path) -> list[int] | None:
    if not path.exists() or path.suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp"}:
        return None
    with Image.open(path) as image:
        return [image.width, image.height]


def scan_texture_calls() -> dict[str, dict]:
    root = texture_calls_root()
    by_hash: dict[str, dict] = {}
    if not root.exists():
        return by_hash
    for call_json in root.glob("call_*/call.json"):
        try:
            call = read_json(call_json)
        except Exception:
            continue
        outputs_dir = call_json.parent / "outputs"
        for output_name in call.get("outputs", []):
            output_path = outputs_dir / output_name
            if not output_path.exists():
                continue
            digest = file_sha256(output_path)
            by_hash[digest] = {
                "call_id": call.get("callId") or call_json.parent.name,
                "call_json": call_json,
                "output_path": output_path,
                "status": call.get("status"),
                "purpose": call.get("purpose"),
                "created_at": call.get("createdAt"),
                "finished_at": call.get("finishedAt"),
                "duration_ms": call.get("durationMs"),
                "prompt": call.get("prompt"),
                "final_prompt": call.get("finalPrompt"),
                "provider": call.get("provider", {}),
                "inputs": call.get("inputs", []),
            }
    return by_hash


def artifact(
    repo: Path,
    *,
    pipeline: str,
    variant: str,
    tile_id: str,
    stage: str,
    kind: str,
    path: Path | None = None,
    status: str | None = None,
    title: str | None = None,
    notes: str | None = None,
    source_script: str | None = None,
    source_report: Path | None = None,
    data: dict | None = None,
    images: list[dict] | None = None,
) -> dict:
    exists = path.exists() if path is not None else False
    out = {
        "id": f"{pipeline}:{variant}:{tile_id}:{stage}",
        "pipeline": pipeline,
        "variant": variant,
        "tile_id": tile_id,
        "stage": stage,
        "kind": kind,
        "status": status or ("ok" if exists or kind in {"metadata", "note"} else "missing"),
    }
    if title:
        out["title"] = title
    if path is not None:
        out["path"] = rel(repo, path)
        if exists:
            out["size_bytes"] = path.stat().st_size
            size = image_size(path)
            if size:
                out["image_size_px"] = size
    if notes:
        out["notes"] = notes
    if source_script:
        out["source_script"] = source_script
    if source_report:
        out["source_report"] = rel(repo, source_report)
    if data:
        out["data"] = data
    if images:
        out["images"] = images
    return out


def manifest_entry(manifest_path: Path, asset_id: str) -> dict | None:
    if not manifest_path.exists():
        return None
    data = read_json(manifest_path)
    entry = data.get("assets", {}).get(asset_id)
    if entry is None:
        return None
    return {
        "manifest": data,
        "entry": entry,
    }


def load_report(path: Path) -> dict:
    return read_json(path) if path.exists() else {}


def build(repo: Path) -> dict:
    concept = concept_root(repo)
    docs = docs_dir(repo)
    art_root = repo / "inkmon美术探索"
    texture_calls = scan_texture_calls()

    design_report_path = concept / "uv" / "design_warp_uv_report.json"
    beveled_report_path = concept / "beveled_uv_wide_rim" / "beveled_uv_report.json"
    patch_report_path = concept / "assets" / "baked" / "patch_assets_report.json"
    model_report_path = concept / "model_preview_report.json"
    design_report = load_report(design_report_path)
    beveled_report = load_report(beveled_report_path)
    patch_report = load_report(patch_report_path).get("tiles", {})
    model_report = load_report(model_report_path)

    pipeline_defs = [
        {
            "id": "hard",
            "label": "管线 A：硬边",
            "default_variant": "current",
            "variants": {
                "current": {
                    "label": "current",
                    "asset_dir": art_root / "codex-硬边-v1" / "assets" / "concept-baked",
                    "scene": art_root / "codex-硬边-v1" / "asset_scene.tscn",
                    "shot": art_root / "codex-硬边-v1" / "shots" / "concept_asset_decor.png",
                    "bake_report": art_root / "codex-硬边-v1" / "assets" / "concept-baked" / "bake_report.json",
                },
                "ink": {
                    "label": "ink",
                    "asset_dir": art_root / "codex-硬边-v1" / "assets" / "concept-baked-ink",
                    "scene": art_root / "codex-硬边-v1" / "asset_ink_scene.tscn",
                    "shot": art_root / "codex-硬边-v1" / "shots" / "concept_asset_ink.png",
                    "bake_report": art_root / "codex-硬边-v1" / "assets" / "concept-baked-ink" / "bake_report.json",
                },
            },
            "stages": ["ai_call", "raw", "fit", "uv", "mesh", "baked", "manifest", "godot_scene"],
        },
        {
            "id": "bevel",
            "label": "管线 B：顶面倒角",
            "default_variant": "wide_rim",
            "variants": {
                "regular": {
                    "label": "regular",
                    "asset_dir": art_root / "codex-倒角-v1" / "assets" / "concept-baked",
                    "scene": art_root / "codex-倒角-v1" / "asset_scene.tscn",
                    "shot": art_root / "codex-倒角-v1" / "shots" / "concept_asset.png",
                    "bake_report": art_root / "codex-倒角-v1" / "assets" / "concept-baked" / "bake_report.json",
                },
                "wide_rim": {
                    "label": "wide_rim",
                    "asset_dir": art_root / "codex-倒角-v1" / "assets" / "concept-baked-wide-rim",
                    "scene": art_root / "codex-倒角-v1" / "asset_wide_rim_scene.tscn",
                    "shot": art_root / "codex-倒角-v1" / "shots" / "concept_asset_wide_rim_decor.png",
                    "bake_report": art_root / "codex-倒角-v1" / "assets" / "concept-baked-wide-rim" / "bake_report.json",
                },
                "ink": {
                    "label": "ink",
                    "asset_dir": art_root / "codex-倒角-v1" / "assets" / "concept-baked-ink",
                    "scene": art_root / "codex-倒角-v1" / "asset_ink_scene.tscn",
                    "shot": art_root / "codex-倒角-v1" / "shots" / "concept_asset_ink.png",
                    "bake_report": art_root / "codex-倒角-v1" / "assets" / "concept-baked-ink" / "bake_report.json",
                },
            },
            "stages": ["ai_call", "raw", "fit", "uv", "mesh", "baked", "manifest", "godot_scene"],
        },
        {
            "id": "patch",
            "label": "管线 C：面片",
            "default_variant": "fit",
            "variants": {
                "fit": {
                    "label": "fit",
                    "asset_dir": concept / "assets" / "baked",
                    "scene": art_root / "codex-面片-v1" / "asset_scene.tscn",
                    "shot": art_root / "codex-面片-v1" / "shots" / "concept_asset_decor_fit.png",
                    "bake_report": patch_report_path,
                },
            },
            "stages": ["ai_call", "raw", "fit", "mesh", "baked", "manifest", "godot_scene"],
        },
    ]

    artifacts: list[dict] = []
    warnings: list[dict] = []

    def raw_ai_artifacts(pipeline: str, variant: str, tile_id: str) -> None:
        raw_path = concept / "raw" / f"{tile_id}_design_raw.png"
        call_match = None
        if raw_path.exists():
            call_match = texture_calls.get(file_sha256(raw_path))
        if call_match:
            artifacts.append(artifact(
                repo,
                pipeline=pipeline,
                variant=variant,
                tile_id=tile_id,
                stage="ai_call",
                kind="metadata",
                status="ok",
                title=f"{call_match['call_id']} / {call_match.get('purpose')}",
                notes="Matched by SHA256 against texture-gen local cache output.",
                data={
                    "call_id": call_match["call_id"],
                    "call_cache_path": portable_ref(repo, call_match["call_json"]),
                    "output_cache_path": portable_ref(repo, call_match["output_path"]),
                    "status": call_match.get("status"),
                    "duration_ms": call_match.get("duration_ms"),
                    "quality": call_match.get("provider", {}).get("quality"),
                    "size": call_match.get("provider", {}).get("size"),
                    "prompt": call_match.get("prompt"),
                    "final_prompt": call_match.get("final_prompt"),
                    "inputs": portable_inputs(repo, call_match.get("inputs", [])),
                },
            ))
        else:
            warnings.append({"tile_id": tile_id, "stage": "ai_call", "message": "call.json missing or raw/output hash mismatch"})
            artifacts.append(artifact(
                repo,
                pipeline=pipeline,
                variant=variant,
                tile_id=tile_id,
                stage="ai_call",
                kind="metadata",
                status="missing",
                title="call.json missing",
                notes="No texture-gen call.json output matched this raw PNG by SHA256.",
            ))
        artifacts.append(artifact(
            repo,
            pipeline=pipeline,
            variant=variant,
            tile_id=tile_id,
            stage="raw",
            kind="image",
            path=raw_path,
            source_script="texture-gen MCP export",
            title=f"{tile_id} raw 3D tile",
        ))

    for pipeline_def in pipeline_defs:
        pipeline = pipeline_def["id"]
        for variant, variant_def in pipeline_def["variants"].items():
            asset_dir: Path = variant_def["asset_dir"]
            manifest_path = asset_dir / "manifest.json"
            for tile_id, asset_id in zip(TILE_IDS, TILE_ASSET_IDS):
                raw_ai_artifacts(pipeline, variant, tile_id)

                if pipeline == "hard":
                    fit_overlay = concept / "fit_overlay" / f"{tile_id}_fit_overlay.png"
                    uv_path = concept / "uv" / f"{tile_id}_warp_uv.png"
                    artifacts.append(artifact(
                        repo,
                        pipeline=pipeline,
                        variant=variant,
                        tile_id=tile_id,
                        stage="fit",
                        kind="image",
                        path=fit_overlay,
                        source_script="inkmon美术探索/concept素材-v1/tools/prepare_design_warp_uvs.py",
                        source_report=design_report_path,
                        data=design_report.get(tile_id, {}),
                        title="standard design geometry overlay",
                    ))
                    artifacts.append(artifact(
                        repo,
                        pipeline=pipeline,
                        variant=variant,
                        tile_id=tile_id,
                        stage="uv",
                        kind="image",
                        path=uv_path,
                        source_script="inkmon美术探索/concept素材-v1/tools/prepare_design_warp_uvs.py",
                        source_report=design_report_path,
                        data=design_report.get(tile_id, {}),
                        title="standard UV warp",
                    ))
                    preview = model_report.get("outputs", {}).get("hard", {})
                    images = [
                        {"label": "wire", "path": rel(repo, repo_path(repo, preview["wire"]))} for _ in [0] if preview.get("wire")
                    ] + [
                        {"label": "shaded", "path": rel(repo, repo_path(repo, preview["shaded"]))} for _ in [0] if preview.get("shaded")
                    ]
                    if not images:
                        warnings.append({"pipeline": pipeline, "variant": variant, "stage": "mesh", "message": "hard mesh preview missing"})
                    artifacts.append(artifact(
                        repo,
                        pipeline=pipeline,
                        variant=variant,
                        tile_id=tile_id,
                        stage="mesh",
                        kind="image_set",
                        status="ok" if images else "missing",
                        source_script="blender/scripts/render_art_pipeline_previews.py",
                        source_report=model_report_path,
                        title="mode2 hard Blender mesh preview",
                        notes="Rendered once from grass_e0 geometry; same mesh contract is reused for all terrain tiles.",
                        images=images,
                    ))
                elif pipeline == "bevel":
                    fit_overlay = concept / "beveled_uv_wide_rim" / "fit_overlay" / f"{tile_id}_beveled_fit_overlay.png"
                    uv_path = concept / "beveled_uv_wide_rim" / f"{tile_id}_beveled_uv.png"
                    artifacts.append(artifact(
                        repo,
                        pipeline=pipeline,
                        variant=variant,
                        tile_id=tile_id,
                        stage="fit",
                        kind="image",
                        path=fit_overlay,
                        source_script="inkmon美术探索/concept素材-v1/tools/prepare_beveled_uvs.py",
                        source_report=beveled_report_path,
                        data=beveled_report.get(tile_id, {}),
                        title="beveled design fit overlay",
                    ))
                    artifacts.append(artifact(
                        repo,
                        pipeline=pipeline,
                        variant=variant,
                        tile_id=tile_id,
                        stage="uv",
                        kind="image",
                        path=uv_path,
                        source_script="inkmon美术探索/concept素材-v1/tools/prepare_beveled_uvs.py",
                        source_report=beveled_report_path,
                        data=beveled_report.get(tile_id, {}),
                        title="wide-rim beveled UV",
                    ))
                    preview = model_report.get("outputs", {}).get("bevel", {})
                    images = [
                        {"label": "wire", "path": rel(repo, repo_path(repo, preview["wire"]))} for _ in [0] if preview.get("wire")
                    ] + [
                        {"label": "shaded", "path": rel(repo, repo_path(repo, preview["shaded"]))} for _ in [0] if preview.get("shaded")
                    ]
                    if not images:
                        warnings.append({"pipeline": pipeline, "variant": variant, "stage": "mesh", "message": "bevel mesh preview missing"})
                    artifacts.append(artifact(
                        repo,
                        pipeline=pipeline,
                        variant=variant,
                        tile_id=tile_id,
                        stage="mesh",
                        kind="image_set",
                        status="ok" if images else "missing",
                        source_script="blender/scripts/render_art_pipeline_previews.py",
                        source_report=model_report_path,
                        title="mode3 wide-rim Blender mesh preview",
                        notes="Rendered once from grass_e0 geometry; e1/e2 use the same bevel contract with deeper walls.",
                        images=images,
                    ))
                else:
                    patch_tile = patch_report.get(tile_id, {})
                    overlay_path = Path(repo / patch_tile["overlay"]) if patch_tile.get("overlay") else concept / "patch_fit_overlay" / f"{tile_id}_patch_fit_overlay.png"
                    artifacts.append(artifact(
                        repo,
                        pipeline=pipeline,
                        variant=variant,
                        tile_id=tile_id,
                        stage="fit",
                        kind="image",
                        path=overlay_path,
                        source_script="inkmon美术探索/concept素材-v1/tools/prepare_patch_assets.py",
                        source_report=patch_report_path,
                        data=patch_tile,
                        title="patch fit overlay",
                    ))
                    artifacts.append(artifact(
                        repo,
                        pipeline=pipeline,
                        variant=variant,
                        tile_id=tile_id,
                        stage="mesh",
                        kind="note",
                        status="not_applicable",
                        title="no Blender mesh",
                        notes="Patch pipeline keeps the AI 3D tile as a transparent sprite; fit/anchor replaces UV and mesh stages.",
                    ))

                baked_path = asset_dir / f"tile_{tile_id}_v0.png"
                artifacts.append(artifact(
                    repo,
                    pipeline=pipeline,
                    variant=variant,
                    tile_id=tile_id,
                    stage="baked",
                    kind="image",
                    path=baked_path,
                    source_script="blender bake or prepare_patch_assets.py",
                    source_report=variant_def["bake_report"],
                    title="final baked sprite",
                ))
                manifest = manifest_entry(manifest_path, asset_id)
                artifacts.append(artifact(
                    repo,
                    pipeline=pipeline,
                    variant=variant,
                    tile_id=tile_id,
                    stage="manifest",
                    kind="metadata",
                    path=manifest_path,
                    status="ok" if manifest else "missing",
                    title="manifest entry",
                    data={"entry": manifest["entry"]} if manifest else {},
                ))
                artifacts.append(artifact(
                    repo,
                    pipeline=pipeline,
                    variant=variant,
                    tile_id=tile_id,
                    stage="godot_scene",
                    kind="image",
                    path=variant_def["shot"],
                    source_script=rel(repo, variant_def["scene"]),
                    title="Godot asset_scene screenshot",
                    notes=f"Scene reads baked_dir={rel(repo, asset_dir)}",
                ))

    for pipeline_def in pipeline_defs:
        for variant, variant_def in pipeline_def["variants"].items():
            manifest_path = variant_def["asset_dir"] / "manifest.json"
            if not manifest_path.exists():
                warnings.append({"pipeline": pipeline_def["id"], "variant": variant, "message": "manifest missing"})
                continue
            manifest = read_json(manifest_path)
            for decor in DECORS:
                entry = manifest.get("assets", {}).get(decor)
                artifacts.append(artifact(
                    repo,
                    pipeline=pipeline_def["id"],
                    variant=variant,
                    tile_id=decor,
                    stage="manifest",
                    kind="metadata",
                    path=manifest_path,
                    status="ok" if entry else "missing",
                    title="decor manifest entry",
                    data={"entry": entry} if entry else {},
                ))
                artifacts.append(artifact(
                    repo,
                    pipeline=pipeline_def["id"],
                    variant=variant,
                    tile_id=decor,
                    stage="baked",
                    kind="image",
                    path=variant_def["asset_dir"] / f"{decor}.png",
                    title="processed decor sprite",
                ))

    out = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "repo_root": ".",
        "style_source": {
            "path": "docs/concept.jpg",
            "notes": "Current concept art source for this exploration batch.",
        },
        "tiles": [{"id": tile_id, "kind": "tile"} for tile_id in TILE_IDS] + [{"id": decor, "kind": "decor"} for decor in DECORS],
        "pipelines": [
            {
                "id": item["id"],
                "label": item["label"],
                "default_variant": item["default_variant"],
                "variants": [
                    {
                        "id": variant_id,
                        "label": variant["label"],
                        "asset_dir": rel(repo, variant["asset_dir"]),
                        "scene": rel(repo, variant["scene"]),
                        "shot": rel(repo, variant["shot"]),
                        "bake_report": rel(repo, variant["bake_report"]),
                    }
                    for variant_id, variant in item["variants"].items()
                ],
                "stages": item["stages"],
            }
            for item in pipeline_defs
        ],
        "overview": {
            "final_compare": "inkmon美术探索/concept三管线对比_fit.png",
            "raw_contact": "inkmon美术探索/concept素材-v1/raw_contact_12.png",
            "standard_uv_contact": "inkmon美术探索/concept素材-v1/uv/design_warp_uv_contact.png",
            "beveled_uv_contact": "inkmon美术探索/concept素材-v1/beveled_uv_wide_rim/beveled_uv_wide_rim_contact.png",
            "patch_contact": "inkmon美术探索/concept素材-v1/assets/concept_patch_contact_fit.png",
        },
        "artifacts": artifacts,
        "warnings": warnings,
    }
    output_path = docs / "pipeline_artifacts.json"
    output_path.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=repo_root())
    args = parser.parse_args()
    data = build(args.repo.resolve())
    print(json.dumps({
        "ok": True,
        "artifacts": len(data["artifacts"]),
        "warnings": len(data["warnings"]),
        "output": str(docs_dir(args.repo.resolve()) / "pipeline_artifacts.json"),
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
