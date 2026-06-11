# blender/designs — 设计稿存档（git = 批准品真相）

生图管线（根目录 `CONTEXT.md` + adr/0009/0010）的入库末端之一：**批准**的设计稿
（GPT 按线稿模板画出的 3D 视角完成态画面——审美批准对象，UV 贴图的源头）存档于此并 git 提交。

- 命名：`design_<terrain>_e<N>_<scheme>_<序号或日期>.png` + 同名 `.provenance.json`
  （模板：`../textures/provenance.template.json`）
- 海拔三档各画各审：e0/e1/e2 每档独立设计稿独立批准（CONTEXT.md）
- 烘焙不读本目录（烘焙读 `../textures/`）；这里是审美真相与重摇/重展 UV 的源头存档
