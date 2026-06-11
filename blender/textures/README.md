# blender/textures — UV 贴图入库目录（git = 批准品真相）

生图管线（根目录 `CONTEXT.md` + adr/0009/0010）的入库末端之一：**批准**的 UV 贴图 +
每资产 provenance JSON 落这里并 git 提交；`bake_assets.py` 烘焙时按文件名自动发现。

## 命名约定（= bake 自动发现规则）

| 文件名 | 含义 |
|---|---|
| `tile_<terrain>_e<N>_v<K>.png` | 地块 UV 贴图（UV 展开布局，见 `texgen/geometry.py uv_layout`）：该地形/海拔的第 K 变体改用 image texture 材质烘焙；没有对应文件的变体继续走程序化材质 |
| `decor_<name>.png` | 图片装饰透明底 sprite：alpha 面片烘焙（shadow catcher 接地影，锚点从 alpha bottom-center 自动算）；高度读 `gen_config.json` 的 `image_decor` |
| `<上述文件名>.provenance.json` | 入库溯源（模板：`provenance.template.json`），prompt/方案/参考图/lab session+image id |

## 子目录

- `_candidates/` — 候选评估缓冲（**gitignore，永不 commit**）：后置闸门要求批准前烘焙试评，
  试评候选放这里；用户点头后 export 正式入库到本目录。随时可清。

## 配置

- `gen_config.json` — 地形 → lab 现役 session id 映射（lab 持 session 本体）+ QC 阈值 + 装饰参数
