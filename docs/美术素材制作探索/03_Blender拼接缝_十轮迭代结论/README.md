# Blender 拼接缝：十轮迭代结论

Source run: `blender/textures/_candidates/blender-owned-tile-seam-20260617-01`

## 定位

这是 `.codex-goal/blender-owned-tile-seam` 的蒸馏结果。它证明 deterministic seam 可以比 AI whole-map seam 更可控，但最终验收必须回到 Godot 拼装。

## 结论

- Round 10 是最佳预览：`full_sprite_painter`。
- 关键修正不是继续调黑线宽度，而是改成和 Godot 一样的完整 tile sprite painter order。
- 早期 round 的问题包括：过粗黑线、highlight 过连续、交点 blob、白边、错误 YSort、错误的 wall/top split。
- 这条路线适合作为 seam 参数探索，不直接替代 Godot candidate scene 验证。

## 最佳参数摘要

```json
{
  "draw_mode": "full_sprite_painter",
  "top_inset_px": 0.75,
  "wall_inset_px": 1.5,
  "white_edge_despill_radius": 4,
  "shadow_width_px": 7.0,
  "shadow_alpha": 54,
  "core_width_px": 1.7,
  "core_alpha": 95,
  "highlight_width_px": 1.1,
  "highlight_alpha": 24,
  "endpoint_trim_px": 2.0
}
```

## 关键文件

- `Blender拼接缝最终预览.png`
- `拼接缝近景对比.png`
- `iteration_log.json`
- `prototype脚本_blender_owned_tile_seam_prototype.py`
- `原始报告.md`

