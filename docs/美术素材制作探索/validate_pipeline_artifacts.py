from __future__ import annotations

import json
import sys
from pathlib import Path


TERRAINS = ("grass", "dirt", "stone", "water")
ELEVATIONS = (0, 1, 2)
TILE_IDS = [f"{terrain}_e{elevation}" for terrain in TERRAINS for elevation in ELEVATIONS]
REQUIRED_GRASS_E0_STAGES = {
    "hard": {"ai_call", "raw", "fit", "uv", "mesh", "baked", "manifest", "godot_scene"},
    "bevel": {"ai_call", "raw", "fit", "uv", "mesh", "baked", "manifest", "godot_scene"},
    "patch": {"ai_call", "raw", "fit", "mesh", "baked", "manifest", "godot_scene"},
}


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def resolve_path(repo: Path, value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else repo / value


def is_external_ref(value: str) -> bool:
    return value.startswith("%APPDATA%/") or value.startswith("<external>/")


def validate_shape(data: dict) -> list[str]:
    errors: list[str] = []
    required = {"schema_version", "generated_at", "repo_root", "tiles", "pipelines", "overview", "artifacts", "warnings"}
    missing = required - set(data)
    if missing:
        errors.append(f"top-level missing fields: {sorted(missing)}")
    if data.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    for index, artifact in enumerate(data.get("artifacts", [])):
        required_artifact = {"id", "pipeline", "variant", "tile_id", "stage", "kind", "status"}
        missing_artifact = required_artifact - set(artifact)
        if missing_artifact:
            errors.append(f"artifact[{index}] missing fields: {sorted(missing_artifact)}")
        if artifact.get("kind") not in {"image", "image_set", "metadata", "note"}:
            errors.append(f"artifact[{index}] invalid kind: {artifact.get('kind')}")
        if artifact.get("status") not in {"ok", "missing", "not_applicable"}:
            errors.append(f"artifact[{index}] invalid status: {artifact.get('status')}")
    return errors


def validate_paths(repo: Path, data: dict) -> list[str]:
    errors: list[str] = []
    for artifact in data.get("artifacts", []):
        if artifact.get("status") != "ok":
            continue
        path = artifact.get("path")
        if path and not is_external_ref(path) and not resolve_path(repo, path).exists():
            errors.append(f"missing artifact path: {artifact['id']} -> {path}")
        for image in artifact.get("images", []):
            image_path = image.get("path")
            if image_path and not is_external_ref(image_path) and not resolve_path(repo, image_path).exists():
                errors.append(f"missing image_set path: {artifact['id']} -> {image_path}")
    for key, value in data.get("overview", {}).items():
        if isinstance(value, str) and value and not resolve_path(repo, value).exists():
            errors.append(f"missing overview path: {key} -> {value}")
    for pipeline in data.get("pipelines", []):
        for variant in pipeline.get("variants", []):
            for key in ("asset_dir", "scene", "shot"):
                value = variant.get(key)
                if value and not resolve_path(repo, value).exists():
                    errors.append(f"missing pipeline {key}: {pipeline['id']}/{variant['id']} -> {value}")
    return errors


def validate_coverage(data: dict) -> list[str]:
    errors: list[str] = []
    artifacts = data.get("artifacts", [])
    pipeline_defaults = {item["id"]: item["default_variant"] for item in data.get("pipelines", [])}

    for pipeline, required_stages in REQUIRED_GRASS_E0_STAGES.items():
        variant = pipeline_defaults[pipeline]
        present = {
            item["stage"]
            for item in artifacts
            if item["pipeline"] == pipeline
            and item["variant"] == variant
            and item["tile_id"] == "grass_e0"
            and item["status"] in {"ok", "not_applicable"}
        }
        missing = required_stages - present
        if missing:
            errors.append(f"grass_e0 incomplete for {pipeline}/{variant}: missing {sorted(missing)}")

    for pipeline, variant in pipeline_defaults.items():
        for tile_id in TILE_IDS:
            baked = [
                item for item in artifacts
                if item["pipeline"] == pipeline
                and item["variant"] == variant
                and item["tile_id"] == tile_id
                and item["stage"] == "baked"
                and item["status"] == "ok"
            ]
            raw = [
                item for item in artifacts
                if item["pipeline"] == pipeline
                and item["variant"] == variant
                and item["tile_id"] == tile_id
                and item["stage"] == "raw"
                and item["status"] == "ok"
            ]
            if not raw:
                errors.append(f"raw missing for {pipeline}/{variant}/{tile_id}")
            if not baked:
                errors.append(f"baked missing for {pipeline}/{variant}/{tile_id}")

    warnings = data.get("warnings", [])
    missing_ai = [
        item for item in artifacts
        if item["stage"] == "ai_call" and item["status"] == "missing"
    ]
    for item in missing_ai:
        has_warning = any(
            warning.get("tile_id") == item["tile_id"]
            and warning.get("stage") == "ai_call"
            for warning in warnings
        )
        if not has_warning:
            errors.append(f"missing ai_call lacks warning: {item['pipeline']}/{item['variant']}/{item['tile_id']}")
    return errors


def main() -> int:
    repo = repo_root()
    path = Path(__file__).with_name("pipeline_artifacts.json")
    if not path.exists():
        print(f"missing {path}", file=sys.stderr)
        return 1
    data = load_json(path)
    errors = []
    errors.extend(validate_shape(data))
    errors.extend(validate_paths(repo, data))
    errors.extend(validate_coverage(data))
    if errors:
        print(json.dumps({"ok": False, "errors": errors}, ensure_ascii=False, indent=2))
        return 1
    print(json.dumps({
        "ok": True,
        "artifacts": len(data.get("artifacts", [])),
        "warnings": len(data.get("warnings", [])),
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
