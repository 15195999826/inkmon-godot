# Godot 拼接缝：当前最佳参数

Source run: `blender/textures/_candidates/tile-pipeline-seam-prototype-20260617-01`

## 定位

这是 `.codex-goal/tile-pipeline-seam-prototype` 的蒸馏结果。它验证的是：最终 map preview 必须来自 Godot candidate scene，而不是 Python/Blender 侧拼图。

## 结论

- 选中的 final round 是 `round_04_final-narrow-seam`。
- seam 应表现为窄暗缝和轻微受光边，而不是粗黑描边或双线。
- Godot 侧必须复用 `tile_pipeline_scene.gd` 的 projected center、painter order 和完整 `Sprite2D` 排序规则。
- raw texture 只作为单 tile bake 输入，不直接拼 map。

## 核心参数

```json
{
  "shadow_width_px": 6.6,
  "shadow_alpha": 0.24,
  "core_width_px": 1.8,
  "core_alpha": 0.44,
  "highlight_width_px": 1.05,
  "highlight_alpha": 0.12,
  "highlight_offset_px": 1.35,
  "endpoint_trim_px": 2.2
}
```

## 关键文件

- `Godot拼接缝最终预览.png`
- `拼接缝近景对比.png`
- `无拼接缝基线.png`
- `seam_geometry.json`
- `原始报告.md`

