# Tile Pipeline Seam Prototype Goal

完成现有 tile production pipeline 下的 seam prototype，只做 candidate-only 输出。

## Scope

- Repo: `D:\GodotProjects\inkmon\inkmon-godot`
- Output: `blender/textures/_candidates/tile-pipeline-seam-prototype-20260617-01/`
- 不改正式地图资源，不替换正式 pipeline，不开 ADR。
- Raw texture 只作为单 tile bake 输入；最终 map preview 必须来自 Godot candidate scene 拼装结果。

## Acceptance

- 6 张 raw tile 通过现有 Blender bake 链路产出 baked PNG with alpha。
- Godot candidate scene 复用 `tile_pipeline_scene.gd` 的 flat-top center、projected painter order、camera fit 规则。
- 输出 `map_no_seam_baseline.png`、`map_godot_seam_preview.png`、`map_seam_zoom_compare.png`、`tile_contact_sheet.png`、`REPORT.md`。
- seam 更接近“窄暗缝 + 轻微受光边”，无明显白边、错位、粗黑描边、双线、错误 side wall。
