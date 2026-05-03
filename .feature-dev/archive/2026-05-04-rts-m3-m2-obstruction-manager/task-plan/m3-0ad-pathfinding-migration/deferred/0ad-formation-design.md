# 0 A.D. Formation 设计 (Handoff to Next Epic)

> **此文档不在 M3 Epic 范围内** — 是给**下个 Epic** (假设 M9 / "RTS Formation" Epic) 的 handoff。
> 本 Epic (M0-M8) 完成时已为 Formation 留好 wiring(MoveRequest.OFFSET / control_group / RtsObstructionManager API),Formation 实现走单独 Epic。

---

## 0. 范围

实现 0 A.D. 风格 Formation:
- **虚拟 entity**:Formation 自身是 entity,有 position / velocity 但**不是物理实体**(不在 ObstructionManager 注册 obstruction shape)
- **Slot 系统**:每个成员 unit 跟 formation 在某 slot offset(相对 formation.position)
- **Formation 自己寻路**:formation 整体规划 path,成员单位用 `MoveRequest.OFFSET(formation_id, slot_offset)` 跟随
- **散开 / 集合**:遇到障碍时 formation 自动 disband(回单兵模式),通过后 reform

---

## 1. 为什么推迟到下个 Epic

| 原因 | 详细 |
|---|---|
| 工程量 | Formation controller 是 0 A.D. 又一个完整子系统,~3000 行 C++,我们 GDScript 等价 ~3000 行 |
| 不影响 M3 Epic 验收 | M0-M8 体验点 ✋1-✋5 都基于"单兵移动",不依赖 formation |
| 风险隔离 | Formation 引入虚拟 entity 概念,跟 RTS 现有 actor model 有冲击,需独立 Epic 处理 |
| 用户优先级 | 用户当前痛点是寻路 / 障碍 / 绕角,而不是队形 |

---

## 2. M3 Epic 已为 Formation 准备的接口

### 2.1 RtsMoveRequest.OFFSET

[data-structures §8.1](../data-structures.md#81-rtsmoverequest-替换现有-rtsnavagentfinal_target-的-4-种类型抽象):

```gdscript
class_name RtsMoveRequest

enum Type { NONE, POINT, ENTITY, OFFSET }

var entity_id: String       # OFFSET 用:跟随 formation entity
var position: Vector2       # OFFSET 用:slot offset
```

Formation 实现时 unit.motion.move_with_offset(formation_id, slot_offset) 走这个 type。

### 2.2 control_group

[data-structures §2.1](../data-structures.md#21-rtsobstructionshape-基类) 已含 `control_group` + `control_group_2`。

Formation 实现时:
- 同 formation 的 unit 都 set control_group = formation_id
- VertexPathfinder 同 group 不算障碍(D9,M6/M7 已 wired)

### 2.3 RtsObstructionManager API

`set_unit_control_group(tag, group)` — 把 unit 加入 / 离开 formation 时调用。

---

## 3. Formation 数据结构(Sketch — 下个 Epic 详化)

### 3.1 RtsFormationActor (虚拟 entity)

```gdscript
class_name RtsFormationActor
extends RtsActor    # 仍是 LGF Actor, 但 obstruction_tag = 0 (不注册物理障碍)

var members: Array[String] = []         # member entity_ids
var slot_layout: RtsFormationLayout      # 阵型定义(线 / 楔形 / 方阵)
var formation_motion: RtsUnitMotion      # formation 自己的 motion (走自己 path, 没有 clearance)
```

### 3.2 RtsFormationLayout (Resource)

```gdscript
class_name RtsFormationLayout
extends Resource

enum Pattern { LINE, COLUMN, WEDGE, BOX, CIRCLE }

@export var pattern: Pattern = Pattern.LINE
@export var spacing: float = 32.0       # member 间距 (px)
@export var rotation_follows_motion: bool = true
```

### 3.3 RtsFormationSystem (单例)

```gdscript
class_name RtsFormationSystem
extends RefCounted

func create_formation(member_ids: Array, layout: RtsFormationLayout) -> RtsFormationActor
func disband_formation(formation_id: String) -> void
func reform(formation_id: String, new_pos: Vector2) -> void
```

---

## 4. Formation 主要算法(Sketch)

### 4.1 创建

```gdscript
func create_formation(members: Array, layout: RtsFormationLayout) -> RtsFormationActor:
    var f := RtsFormationActor.new()
    f.position_2d = _compute_centroid(members)
    f.members = members.duplicate()
    f.slot_layout = layout
    
    var formation_id := f.get_id()
    for i in range(members.size()):
        var member: RtsActor = GameWorld.get_actor(members[i])
        var slot_offset: Vector2 = _compute_slot_offset(layout, i, members.size())
        # member.motion 走 OFFSET 模式跟随 formation
        member.motion.move_with_offset(formation_id, slot_offset)
        # 同 control_group
        var obstr_mgr: RtsObstructionManager = world.obstruction_manager
        obstr_mgr.set_unit_control_group(member.obstruction_tag, formation_id)
    return f
```

### 4.2 整体寻路

```gdscript
func tick_formation(f: RtsFormationActor, delta: float, facade: RtsPathfinderFacade) -> void:
    # Formation 自己的 motion 走 long path (但 clearance = formation 总占地半径)
    var formation_clearance: float = _compute_total_clearance(f.members)
    f.formation_motion._clearance = formation_clearance
    f.formation_motion.tick(delta, world, facade)
    # 成员 motion 自己 tick (走 OFFSET 模式)
    # 在 RtsUnitMotion._make_path_goal_from_request:OFFSET → 把 _move_request.position 加 formation.position 作 goal
```

### 4.3 障碍处理

如果 formation_motion 寻路失败:
- option A: disband(formation 解散,member 走单兵模式)
- option B: reform(在最近可达点重组)

0 A.D. 默认 disband + 后续 reform。我们采用同策略。

---

## 5. 与 M3 Epic 的兼容性 / 依赖

| M3 Epic | Formation Epic 依赖 |
|---|---|
| M0 obstruction shape 拆 | ✅ 直接复用 |
| M2 ObstructionManager + control_group | ✅ Formation 用 set_unit_control_group |
| M5 LongPath | ✅ formation_motion 走 LongPath |
| M6 VertexPath + group filter | ✅ 同 control_group 跳过(D9 已 wired)|
| M7 UnitMotion MoveRequest.OFFSET | ✅ 已留接口(`with_offset` 工厂) |
| M8 push pass | ✅ formation member 仍参与 push |

**Formation Epic 不需要改 M3 Epic 的任何代码** — 都是新加。

---

## 6. Formation Epic 工程量预估

参考 0 A.D. 源码:
- `simulation/components/Formation.js` ~700 行 JS
- `simulation/components/FormationAttack.js` ~150 行
- `simulation/components/UnitAI.js` ~3000 行(含 stance,Formation 是其中一段 ~500 行)

我们 GDScript 等价(扣除 stance):**~1500-2000 行 GDScript** + ~500 行 frontend(formation 选择 / 阵型切换 UI)。

预估 4-6 周(全职等价)/ 12-18 周(用户晚上+周末节奏)。

---

## 7. Formation Epic 启动前置条件

- ✅ M3 Epic (M0-M8) 全部 done + 体验点 ✋5 通过
- ✅ M3 archive 完成
- ✅ 用户跑 demo_rts_frontend 一段时间,确认单兵寻路稳定
- ⚠️ Formation Epic 不引入新 0 A.D. 概念,只用 M3 已建立的;若用户在使用过程发现 M3 缺失某关键能力(e.g. unit priority),先补 M3 patch 再启 Formation

---

## 8. 关键决策(Formation Epic 时讨论)

### O1 — Slot offset 计算

- 玩家选 ≥10 unit + right-click:formation_id 自动生成 / 选择阵型?
- 默认 LINE / 用户配置默认 / 通过快捷键(F1=LINE / F2=COLUMN ...)

### O2 — Formation virtual entity 跟 LGF Actor model 集成

- Formation 是 RtsActor 子类(挂在 GameWorld) vs 完全独立 (RtsFormationSystem 单例)?
- 0 A.D. 是 entity-as-formation,我们倾向于同样(LGF 接 actor 系统更自然)

### O3 — Disband 后 reform 阈值

- formation_motion failed_movements 几次后 disband?
- disband 后多远才尝试 reform?(避免反复)

---

## 9. Formation Epic 与现 RTS 例子的整合点

- frontend visualizer:formation indicator(选择圈含成员)
- UI:阵型切换按键 / formation 选择
- AI:AI 对手是否使用 formation(初版可能不用,人手动操作)
- demo_rts_frontend:加 formation 控制示例(不增加复杂度)

---

## 10. 决策来源

- M3 Epic 决策: D9 (group_filter API 在 M6/M7 已是 输入,M8 仅打开)
- 0 A.D. 对照: components/Formation.js + FormationAttack.js
- 范围划分: README §0.2(Formation 推到下个 Epic)

---

## 11. 引用

- 父文档: [`../README.md`](../README.md)
- M3 数据结构: [`../data-structures.md`](../data-structures.md) §2.1 / §8.1
- M3 API: [`../interfaces.md`](../interfaces.md) §6
- 0 A.D. 源码: `addons/logic-game-framework/example/rts-auto-battle/docs/references/0ad-source/source/simulation2/components/`(Formation 相关在 simulation/components/ JS 部分,不在 sparse 范围;若需查阅另外 sparse `simulation/components/`)
