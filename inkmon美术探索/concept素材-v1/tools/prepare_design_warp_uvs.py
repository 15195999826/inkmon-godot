from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


TERRAINS = ("grass", "dirt", "stone", "water")
ELEVATIONS = (0, 1, 2)


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def prepare(root: Path, out_dir: Path) -> None:
    scripts_dir = repo_root() / "blender" / "scripts"
    if str(scripts_dir) not in sys.path:
        sys.path.insert(0, str(scripts_dir))

    from texgen import warp  # noqa: PLC0415

    raw_dir = root / "raw"
    out_dir.mkdir(parents=True, exist_ok=True)
    report: dict[str, dict] = {}
    missing: list[Path] = []

    for terrain in TERRAINS:
        for elevation in ELEVATIONS:
            key = f"{terrain}_e{elevation}"
            raw_path = raw_dir / f"{key}_design_raw.png"
            if not raw_path.exists():
                missing.append(raw_path)
                continue
            design_sidecar = warp.load_sidecar(warp.default_sidecar("design", elevation))
            uv_sidecar = warp.load_sidecar(warp.default_sidecar("uv", elevation))
            out_path = out_dir / f"{key}_warp_uv.png"
            report[key] = {
                "raw": str(raw_path),
                "uv": str(out_path),
                "warp": warp.warp_design_to_uv(str(raw_path), design_sidecar, uv_sidecar, str(out_path)),
            }

    if missing:
        joined = "\n".join(str(path) for path in missing)
        raise FileNotFoundError(f"Missing raw images:\n{joined}")

    (out_dir / "design_warp_uv_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--out-dir", type=Path, default=None)
    args = parser.parse_args()
    root = args.root.resolve()
    prepare(root, (args.out_dir or root / "uv").resolve())


if __name__ == "__main__":
    main()
