# L2 3D Hex Overworld 实现架构 🗺️

> 只读咨询。基于约束给方案，不动代码。核心原则：**Fork hex-atb 的 Move 语义到 `scenes/inkmon-main` 本地实现，绝不 type against example 类，绝不碰 RTS/sim-nav-map 寻路。**

---

## 1️⃣ 新增/改动文件（`scenes/inkmon-main/`）

| 文件 | 类型 | 职责 |
|---|---|---|
| `overworld/OverworldGrid.gd` | 新增 `class_name InkMonOverworldGrid` | 本地 hex 占用网格：`Dictionary<axial, occupant_id>` + reservation set。**fork**，不引用 example 的 grid |
| `overworld/OverworldMoveController.gd` | 新增 | 承接 Move pipeline：`start_move`→`apply_move` 两段式，发本地 event |
| `overworld/OverworldEvents.gd` | 新增 | 本地轻量 event 定义（`MoveStartEvent`/`MoveCompleteEvent`），不复用 battle GI 的 event |
| `overworld/OverworldView3D.gd` | 新增 (Node3D) | fork 自 `world_view.gd` 思路：GridMapRenderer3D + coord↔world 投影 + 单位 Node3D |
| `overworld/OverworldView3D.tscn` | 新增 | GridMap（KayKit hex tiles）+ Camera3D + player/NPC 单位锚点 |
| `overworld/HexPicker.gd` | 新增 | 右键 raycast → world hit → axial coord（纯几何，无依赖） |
| `InkMonAppRoot.gd` | **改** | 把 `move_player(delta)` 键盘移动替换为：右键命令进 `OverworldMoveController`；订阅 `MoveCompleteEvent` 后跑 NPC proximity |
| `InkMonMain.tscn` | **改** | 用 `OverworldView3D` 替换 2D Node2D view 节点 |

**不改**：`InkMonGameSession` / `InkMonPlayerState` / NPC handlers / ItemSystem / save-load / battle launch —— 全部保留，只换 view + 移动来源。

---

## 2️⃣ Move 语义保留（本地化）

Fork hex-atb 两段式，**坐标层而非渲染层**：

```
OverworldMoveController.request_move(from, to):
  1. StartMove:  grid.reserve(to)          # 目标格占位，防并发
                 emit MoveStartEvent{actor, from, to}
  2. ApplyMove:  grid.move_occupant(from→to)
                 player_state.tile = to     # 逻辑坐标真源
                 grid.release_reservation(to)
                 emit MoveCompleteEvent{actor, to}
```

- **reservation**：单人 overworld 也保留，语义对齐 hex-atb，未来多 NPC 行走可直接复用。
- **occupant**：`grid` 持 `tile→id`，NPC 静态占格也注册进来，移动时做碰撞拒绝。
- **event**：本地 `OverworldEvents`，**不挂 battle 的 GameInstance**——这是 L2 battle 的 `InkMonMove` 不能直接用的根因（tied to battle GI）。

---

## 3️⃣ 右键 → hex → 移动 → session 同步

```
_unhandled_input(RMB click)
  → HexPicker.raycast(camera, mouse_pos) → world Vector3
  → GridMapModel.world_to_coord() → axial            # 复用 KaykitPreview 的 coord 转换思路
  → 单步邻接校验（只允许相邻 hex 或简单直线逐格）：
       不引入 A*；用 hex 邻接表逐格 step，遇占用/越界即停
  → 对每个 step 调 OverworldMoveController.request_move
  → MoveCompleteEvent → OverworldView3D 插值动画 + InkMonGameSession.sync(player_state.tile)
```

- **path = naive hex line / 单步**，不是 pathfinding。明确不用 RTS A*。
- session 同步走**已有** `InkMonGameSession`，落点写 `InkMonPlayerState.tile` 作为存档真源。

---

## 4️⃣ 移动后 NPC 交互（view 不耦合 handler）

```
AppRoot 订阅 OverworldMoveController.move_completed(tile):
  → 查 grid 占用 + NPC 注册表，算 proximity（原 NPC proximity 逻辑搬过来，从 delta 触发改为 event 触发）
  → 命中 → 调既有 NPC handler / 弹既有 NPC side sheet
```

- **View 只发 `move_completed` 信号**，AppRoot 是唯一 orchestrator，handler 不知道 3D view 存在 → 解耦达成。
- NPC handlers / side sheet / DevAgent ops 签名不变。

---

## 5️⃣ 明确 Reject ❌

- ❌ 不 `preload`/`extends` 任何 `example/hex-atb-battle/**` 类（grid/event/action/world_view 全 fork）。
- ❌ 不用 sim-nav-map / RTS A* / steering / nav grid。
- ❌ 不复用 battle 的 `InkMonMove` action（绑 battle GI）。
- ❌ 不保留键盘 `move_player(delta)` 作为主路径（可留 debug 隐藏入口）。
- ❌ 不新建 UnitAI 中间层（对齐已有约定，actor 自己承接）。

---

## 6️⃣ Smoke + DevAgent 验证

**新增 group**（`scenes/inkmon-main/tests/test_groups.json`，namespace=`main`）：

| smoke | 断言 |
|---|---|
| `smoke_overworld_move.tscn` | request_move 邻接格 → grid 占用迁移 + player_state.tile 更新 + MoveStart/Complete 各发一次 + reservation 清空 |
| `smoke_overworld_blocked.tscn` | 目标格被 NPC 占用 → move 拒绝，tile 不变 |
| `smoke_overworld_npc_trigger.tscn` | 移动到 NPC 邻格 → move_completed 触发既有 handler（mock handler 收到调用） |
| `smoke_overworld_pick.tscn` (UI 交互) | `Viewport.push_input` 右键点 → HexPicker 出正确 axial（`InputHelper` 模板） |
| `smoke_overworld_save_load.tscn` | 移动后 save → load → tile 恢复（验证 session/save 未被破坏） |

跑：`./tools/run_tests.ps1 main/overworld`

**DevAgent 验证**：复用现有 DevAgent ops 加一条 `goto_tile(axial)` 命令走同一 `OverworldMoveController`，确认 headless 下逻辑路径与 UI 右键完全同源（无第二条移动实现）。

---

⚠️ 落地前需我**实读**这 4 个真源文件确认字段名再动手（按 [[feedback_verify_field_names_before_use]]）：
- `KaykitPreview.gd` 的 `coord_to_world`/`world_to_coord` 实际签名
- `world_view.gd` 的 Node3D 投影与信号名
- `InkMonAppRoot.gd` 现有 `move_player` / NPC proximity 实现
- `InkMonPlayerState` 存档字段（`tile`? `position`?）

要我继续读这些文件、把架构里的占位名换成真实 API 吗？
