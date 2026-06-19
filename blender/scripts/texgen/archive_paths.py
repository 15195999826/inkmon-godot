from pathlib import Path


ARCHIVE_ROOT_REL = Path("docs") / "美术素材制作探索" / "原始候选完整归档"

ARCHIVED_RUN_DIRS = {
    "single-stage-tile-6-variants-20260617-01": "01_单地块标准方案_六地块样本_完整候选",
    "tile-pipeline-seam-prototype-20260617-01": "02_Godot拼接缝_当前最佳参数_完整候选",
    "beveled-tile-prototype-20260617-01": "03_顶面倒角模型_模式3原型_完整候选",
    "original-no-ink-map-20260617-01": "04_NoInk参考源_阴影职责_完整候选",
    "template-connected-20260616-01": "05_DualCanvas早期参考_路线3诊断_完整候选",
    "left-warp-corner-ink-20260616-01": "06_黑线专项_角线与缝线_完整候选",
    "left-warp-source-cut-variants-baked-20260616-01": "07_二十一图矩阵_源切分基准_完整候选",
    "left-warp-source-cut-variants-top-edge-clean-20260616-01": "08_二十一图矩阵_顶边清理_完整候选",
    "quality-bake": "09_Bake清晰度基准_完整候选",
}


def candidates_root(repo: Path) -> Path:
    return repo / "blender" / "textures" / "_candidates"


def archive_root(repo: Path) -> Path:
    return repo / ARCHIVE_ROOT_REL


def candidate_run(repo: Path, run_name: str) -> Path:
    return candidates_root(repo) / run_name


def archived_run(repo: Path, run_name: str) -> Path:
    archive_name = ARCHIVED_RUN_DIRS.get(run_name, run_name)
    return archive_root(repo) / archive_name


def existing_run(repo: Path, run_name: str) -> Path:
    candidate = candidate_run(repo, run_name)
    if candidate.exists():
        return candidate
    archive = archived_run(repo, run_name)
    if archive.exists():
        return archive
    return candidate

