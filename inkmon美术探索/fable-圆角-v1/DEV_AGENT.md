# tile_pipeline_scene — DevAgent 契约

标准地块美术管线拼装场景：读 `assets/baked/manifest.json`（Blender 写的角度/比例单一真相）
+ `InkMonIsoSandboxDemoMap` 固定 seed 地图，拼烘焙 hex 地块 + 装饰 + 水带。
用途 = 截图肉眼自评迭代（goal: tile-art-pipeline），无战斗逻辑。

## 启动

```bash
SESS_NAME="tile-pipeline"
SESS_DIR="$APPDATA/Godot/app_userdata/Inkmon/dev-agent/sessions/$SESS_NAME"
rm -rf "$SESS_DIR" && mkdir -p "$SESS_DIR"
godot --path D:/GodotProjects/inkmon/inkmon-godot \
  res://inkmon美术探索/fable-圆角-v1/tile_pipeline_scene.tscn \
  -- --dev-agent --dev-agent-session=$SESS_NAME \
  > "$SESS_DIR/godot.log" 2>&1
```

后台运行；等 `outbox.jsonl` 出现后发 op。

## Scene ops（`{"op":"scene","name":...,"args":{...}}`）

| op | args | 说明 |
|---|---|---|
| `state` | — | tile/decor 计数、manifest 角度、相机 zoom/pos |
| `set_view` | `zoom`/`x`/`y`（可省） | 调相机看局部（拼缝/排序近检） |
| `set_decor_density` | `density`（默认 1.0） | 调装饰密度并整图重建 |

## 观察

截图走通用 op：`{"id":"01","op":"capture","label":"assembled"}`（默认 960 宽 JPEG；
要像素级看拼缝用 `"format":"png","width":1920`）。场景启动即拼好，无需触发动作；
改 `manifest.json`/贴图后需重启场景（Godot 启动时只读一次）。

## 已知注意

- 装饰散布是场景内固定 seed RNG（树位来自 demo map，灌木/石头堆是 scene 自己撒的）
- 相机自动 fit 全图；`set_view` 改完不会自动还原，重建（`set_decor_density`）会重新 fit
