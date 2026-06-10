# 0005: 主游戏表现层 = 真 2D 等轴 hex + AI 烘帧 sprite（弃占位 3D）

主游戏 presentation 从"占位 3D"（`Node3D`/`MeshInstance3D` 基本几何体 + `Camera3D` 透视、零正式美术资产）改为**真 2D 等轴**：Godot `Node2D`/`Sprite2D`/`AnimatedSprite2D` + `Camera2D`，**hex 逻辑网格不变，等轴只是渲染风格**。画风对标 Supergiant（Bastion/Hades）的 painterly 手绘 + 3/4 等轴投影。角色动画走"生成 → 烘成 2D 帧序列"管线：Seedance 生成绿幕视频 → 抠像切帧 → `SpriteFrames`（与 Hades 的"3D 渲染 → 烘 2D 帧"同形，只把生成器换成 AI 视频）。

驱动因素：只按"AI 美术资产生成难度"看，2D 图像/视频生成远比 3D 模型管线（mesh/UV/PBR/rig/Godot 导入返工）成熟。

## Considered Options

- **3D 模型管线** — 弃。AI 生成 3D 的拓扑/UV/绑骨/导入返工点太多。
- **A = 2.5D 立牌（`Sprite3D` in 3D 正交）** — 弃。素材是烘焙光照的扁平视频帧，3D 的招牌能力（场景打光/运镜）要么帮倒忙（双重光照）要么用不上（单朝向禁不起绕镜头），只剩"深度排序"一个优势；且有滑向 HD-2D 的引力（明确不要）。
- **B = 真 2D** — **选**。视频帧序列的原生宿主（`AnimatedSprite2D`），彻底掐死 HD-2D 引力，匹配 Bastion（本就是 2D 游戏）。代价 = y-sort 遮挡排序自己收（hex + 一队单位规模可控）。
- **网格换方/菱形 iso 格** — 弃。美术论证不触及网格拓扑；保留 hex（= lab 设计真相）。

## Consequences

- **零 submodule 改动**：录像数据（`addons/.../stdlib/replay`）已 renderer-agnostic（纯事件 `timeline`，位置是 `Array` 不是 `Vector3`）；inkmon 在 `inkmon/presentation/` **新写 2D battle animator 读同一份录像**。hex-atb / dota2 examples 保留各自 3D 前端。
- **战斗表现是 greenfield**：inkmon 从未接战斗回放画面（架构文档"复用 hex-atb animator"是**未实现的意图**，grep 零引用）→ 直接建 2D，无旧可拆。
- **overworld 改 1 个文件**：`InkMonOverworldView`（`Node3D`→`Node2D`，~556 行重写约 350 行）。`ultra-grid-map` 已有 `coord_to_world()->Vector2` / `world_to_coord(Vector2)` / `GridMapRenderer2D`，坐标与网格渲染白送。UI 层（`InkMonWorldPresentation` / `InkMonWorldPanelView`，Control 节点）零改。
- **致命耦合（命脉，待定）**：棋盘等轴角度 = Seedance 出图角度，必须统一。每只 mon 须按同一"3/4 俯视角 / 站位+朝向 / 光向 / 比例 / 着地阴影"规格生成，否则与棋盘不在一个透视。该"统一出图规格"是 AI 美术管线的命脉，细节待定。→ **2026-06-11 更新：已由 [adr/0008](0008-limited-angle-rotation-two-layer-projection.md) 拍板落定**（保守固定视角主案 + 整图面片 + 一致性 QC；唯一角度值仍待沙盒选定）。
- `docs/main-game-architecture.md` 仍描述 3D 现状，落地 2D 时再同步更新（本 ADR 只记决定）。
