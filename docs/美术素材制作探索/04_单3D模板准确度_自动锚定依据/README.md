# 单 3D 模板准确度：自动锚定依据

Source run: `blender/textures/_candidates/single-3d-template-accuracy-low-20260616-01`

## 定位

这个实验回答一个关键问题：如果只给单个 3D 地块模板，AI 是否会严格贴合模板几何。

## 结论

- AI 输出会相对数学模板发生像素级偏差，不同地块偏差还不一致。
- 这不是单纯 retune warp 参数能解决的问题。
- 后续导入工具需要支持 auto-anchor / per-image fitting，并允许人工微调。
- 纯白背景有利于自动找 foreground bbox，但不能替代人工校正入口。

## 关键文件

- `diagnostics/accuracy_contact_sheet.png`
- `diagnostics/*_sidecar_overlay.png`
- `logs/accuracy_metrics.json`
- `raw/`
- `原始报告.md`

