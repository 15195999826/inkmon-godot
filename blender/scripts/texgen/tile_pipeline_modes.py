# texgen.tile_pipeline_modes -- named tile bake pipeline contracts
#
# This file is the naming boundary for the three current tile model pipelines:
#   mode 1 / 圆边: current production rounded prism
#   mode 2 / 硬边: no-bevel diagnostic prism
#   mode 3 / 倒角: explicit top-edge bevel prototype

from copy import deepcopy


MODE1_ROUNDED = "mode1_rounded"
MODE2_HARD = "mode2_hard"
MODE3_TOP_EDGE_BEVEL = "mode3_top_edge_bevel"


PIPELINES = {
    MODE1_ROUNDED: {
        "id": MODE1_ROUNDED,
        "index": 1,
        "zh_name": "圆边",
        "en_name": "rounded_production",
        "aliases": ["1", "mode1", "模式1", "圆边", "rounded", "round", "production", "current"],
        "mesh_contract": "standard_hex_prism_with_bevel_modifier",
        "texture_layout": "standard paper-net UV or atlas layout",
        "template_set": "blender/templates/standard-templates",
        "builder": "bake_assets.build_hex_tile",
        "config_patch": {
            "tile_pipeline_mode": MODE1_ROUNDED,
            "tile_bevel_enabled": True,
            "tile_smooth_enabled": True,
            "bevel_width": 0.06,
            "bevel_segments": 3,
        },
        "notes": "Current production default: standard prism, Blender Bevel modifier, smooth normals.",
    },
    MODE2_HARD: {
        "id": MODE2_HARD,
        "index": 2,
        "zh_name": "硬边",
        "en_name": "hard_no_bevel_diagnostic",
        "aliases": ["2", "mode2", "模式2", "硬边", "hard", "sharp", "no-bevel", "nobevel"],
        "mesh_contract": "standard_hex_prism_no_bevel",
        "texture_layout": "standard paper-net UV or atlas layout",
        "template_set": "blender/templates/standard-templates",
        "builder": "bake_assets.build_hex_tile",
        "config_patch": {
            "tile_pipeline_mode": MODE2_HARD,
            "tile_bevel_enabled": False,
            "tile_smooth_enabled": False,
            "bevel_width": 0.0,
            "bevel_segments": 0,
        },
        "notes": "Diagnostic mode: same prism topology and UV as mode 1, but no bevel modifier and flat face shading.",
    },
    MODE3_TOP_EDGE_BEVEL: {
        "id": MODE3_TOP_EDGE_BEVEL,
        "index": 3,
        "zh_name": "倒角",
        "en_name": "explicit_top_edge_bevel",
        "aliases": ["3", "mode3", "模式3", "倒角", "bevel", "top-bevel", "top_edge_bevel", "edged"],
        "mesh_contract": "explicit_top_bevel_faces",
        "texture_layout": "beveled UV: top + bevel_0..5 + visible walls",
        "template_set": "blender/templates/standard-edged-templates",
        "builder": "texgen.beveled_tile_prototype._build_beveled_mesh",
        "config_patch": {
            "tile_pipeline_mode": MODE3_TOP_EDGE_BEVEL,
            "tile_bevel_enabled": False,
            "tile_smooth_enabled": False,
            "bevel_width": 0.0,
            "bevel_segments": 0,
        },
        "notes": "Candidate mode: topology has real bevel-band faces; do not reuse standard paper-net UV directly.",
    },
}


def _alias_map() -> dict:
    out = {}
    for pipeline_id, spec in PIPELINES.items():
        out[pipeline_id] = pipeline_id
        out[spec["en_name"]] = pipeline_id
        out[spec["zh_name"]] = pipeline_id
        for alias in spec["aliases"]:
            out[str(alias).lower()] = pipeline_id
    return out


def normalize(value=None) -> str:
    if value is None or value == "":
        return MODE1_ROUNDED
    key = str(value).strip().lower()
    aliases = _alias_map()
    if key not in aliases:
        raise ValueError("unknown tile pipeline mode: %s" % value)
    return aliases[key]


def spec(value=None) -> dict:
    return deepcopy(PIPELINES[normalize(value)])


def config_patch(value=None) -> dict:
    return dict(PIPELINES[normalize(value)]["config_patch"])


def list_specs() -> list:
    return [deepcopy(PIPELINES[key]) for key in (MODE1_ROUNDED, MODE2_HARD, MODE3_TOP_EDGE_BEVEL)]
