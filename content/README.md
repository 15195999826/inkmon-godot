# content/ — 游戏内容分区（T2 美术资产契约，2026-07-02）

代码 / 框架 / 内容三分中的**内容根**。契约权威文档在 Lab 仓：
`inkmon-lab/docs/architecture/godot-contract.md`（Art Asset Contract 章）+ ADR-0003。

## 分区规则

```text
content/
  maps/*.map.json    ← 🖐 手写区：人编辑，机器永不覆盖（inkmon-map/1）
  terrains.json      ← 🖐 手写区：terrain key → 逻辑性质/资产族 目录表
  art/               ← 🤖 机器发布区：只有 Lab publish 命令能写
    tiles/<set_id>/manifest.json + tile_*.png   （inkmon-tileset/1）
    decor/<set_id>/…   （T3 定 payload）
    units/<set_id>/…   （T7 定 payload）
    vfx/<set_id>/…
```

- `art/` 下 per-set 目录由 Lab 侧 publish **原子换**（temp → rename swap），manifest 盖
  `version + hash`。**不要手改** `art/` 内容——改了也会在下次 publish 被整目录换掉。
- 发布后必须 reimport，否则引擎吃旧 `.ctex` 缓存：
  `godot_console --headless --import --path <repo>`
- 投影/几何常量以每份 set manifest 的 `projection` 块为准（发布时从 Lab 单源
  `tile_projection_contract.json` 盖入）——运行时**只读 set manifest**，不跨文件引用。
