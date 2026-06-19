# Bake 清晰度基准：2048 降采样 sharp80

Source run: `blender/textures/_candidates/quality-bake`

## 定位

这是 bake 清晰度的基准记录，解释为什么 `texture-gen quality=low` 不等于最终贴图模糊。

## 推荐参数

```text
internal bake canvas_px: 2048
texture interpolation: Linear
downsample: Lanczos -> 512
postprocess: UnsharpMask(radius=0.75, percent=80, threshold=2)
```

## 结论

- direct `512` bake 太软。
- `1024 -> 512` 明显比 direct `512` 保留更多细节。
- `2048 -> 512 sharp80` 是当前默认候选：清晰但不过度锐化。
- `Closest` 和 `sharp220` 不适合作为默认生产参数。

## 关键文件

- `quality_sharpen_compare.png`
- `quality_sharpen_zoom.png`
- `recommended_2048_to_512_sharp80.png`
- `quality_metrics_round2.json`
- `REPORT.md`

