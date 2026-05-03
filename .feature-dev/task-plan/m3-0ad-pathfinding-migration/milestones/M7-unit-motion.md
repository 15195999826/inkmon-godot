# M7 — UnitMotion 重写 (Long + Short 双轨整合)

> 父 plan: [`../README.md`](../README.md)
> 数据结构: [`../data-structures.md`](../data-structures.md) §8
> API: [`../interfaces.md`](../interfaces.md) §6
>
> Status: 🔒 pending(M6 完成后启动)
> 依赖: M6 (LongPath + VertexPath + Facade 全工作)
> 阻塞: M8 (group-push 优化在新 motion 上)
> ✋ 用户体验点 4: M7 完成时(整体寻路换装,完整 demo 一局)

---

## 0. 目标

把现有 `RtsNavAgent` + `RtsUnitSteering` 替换为 `RtsUnitMotion`(0 A.D. 风格 long+short 双轨 + MoveRequest + Ticket + FailedMovements 反馈)。

**关键点**:
- 单位持 `_long_path` + `_short_path` 双 `RtsWaypointPath`,跟随时优先消费 short(若有),next short 走完触发 long advance
- 4 种 MoveRequest type:NONE / POINT / ENTITY / OFFSET
- Failed movements 累计 (`MAX_FAILED_MOVEMENTS = 35`),活动失败后 abort
- m_FollowKnownImperfectPathCountdown(`= 12 ticks`)在 best-so-far short path 完后触发 long path retry
- group filter 在 short path req 已是 API 输入(M6 wired,M7 真正赋值 control_group = team_id)
- Tick 顺序按 actor.get_id() 字典序(§12.5 Determinism)

**M7 拆 4 sub-phase**:
- **M7a**: Path storage(MoveRequest + WaypointPath 双持 + Ticket)
- **M7b**: Lifecycle(_failed_movements / _follow_imperfect_countdown 反馈)
- **M7c**: Movement + Obstruction flag sync(每 tick step + move_shape + set_unit_moving_flag)
- **M7d**: Activity 集成(attack / gather / build 走 motion API)

---

## 1. Scope

### 1.1 必做

- 新建 `RtsMoveRequest` / `RtsMotionTicket` data class
- 新建 `RtsUnitMotion` 完整(按 [data-structures §8.3](../data-structures.md#83-rtsunitmotion-替换-rtsnavagent--rtsunitsteering))
- 新建 `RtsMotionComponent`(挂 actor)
- 删除 `RtsNavAgent` + `RtsUnitSteering`(M2 死者留 world 部分逻辑迁到 motion)
- 修改 `RtsCharacters._create_unit` → 创建 RtsMotionComponent
- 修改所有 `RtsActivity` 子类接 `motion.move_to / move_to_entity / stop` API
- 修改 `RtsWorld.tick` 顺序按 §10.3 的 6 步
- 加 4 新 smokes(每 sub-phase 一)

### 1.2 不做

| 不做 | 原因 |
|---|---|
| Stance 系统(7 种 0 A.D. stance) | 当前 RtsActivity + 默认行为够用,留 M9 |
| Async path computation | 同步够用 |
| Push pass(group push 让位) | M8 |

### 1.3 文件清单

#### 新建

```
addons/.../logic/movement/
├── rts_move_request.gd
├── rts_motion_ticket.gd
├── rts_unit_motion.gd                        ← 核心(~600 行)
└── rts_motion_component.gd
```

#### 修改

```
addons/.../logic/
├── characters/rts_characters.gd              ← _create_unit 接 RtsMotionComponent
├── activities/rts_activity_*.gd              ← 全部接 motion API
└── core/rts_auto_battle_procedure.gd         ← _world_tick 顺序调整(§10.3)
```

#### 删除

```
addons/.../logic/movement/
├── rts_nav_agent.gd                           ← M7c 末删除
└── rts_unit_steering.gd                      ← M7c 末删除
```

#### 新建 smokes

```
addons/.../tests/battle/
├── smoke_motion_path_storage.tscn             ← M7a
├── smoke_motion_failed_movements.tscn         ← M7b
├── smoke_motion_obstruction_sync.tscn         ← M7c
└── smoke_motion_activity_integration.tscn     ← M7d
```

---

## 2. 子任务

### M7a — Path Storage (1 周)

**M7a.1 — RtsMoveRequest / RtsMotionTicket data class**

按 [data-structures §8.1 / §8.2](../data-structures.md#81-rtsmoverequest-替换现有-rtsnavagentfinal_target-的-4-种类型抽象)。

**M7a.2 — RtsUnitMotion 雏形(只持有 path)**

```gdscript
class_name RtsUnitMotion
extends RefCounted

const MAX_FAILED_MOVEMENTS: int = 35
const KNOWN_IMPERFECT_PATH_RESET_COUNTDOWN: int = 12

# 模板字段(从 unit_kind config 读)
var _template_walk_speed: float = 80.0
var _pass_class: RtsPassabilityClassConfig

# 动态身体属性
var _clearance: float = 14.0
var _walk_speed: float
var _block_movement: bool = true

# 反馈计数
var _failed_movements: int = 0
var _follow_known_imperfect_path_countdown: int = 0

# 当前请求 + 异步 ticket
var _move_request: RtsMoveRequest
var _expected_path_ticket: RtsMotionTicket

# 双 path
var _long_path: RtsWaypointPath
var _short_path: RtsWaypointPath

# === 公开 API ===

func move_to(pos: Vector2, min_r: float, max_r: float) -> void:
    _move_request = RtsMoveRequest.to_point(pos, min_r, max_r)
    _failed_movements = 0
    _short_path = RtsWaypointPath.new()
    _long_path = RtsWaypointPath.new()
    _expected_path_ticket = null

func move_to_entity(eid: String, min_r: float, max_r: float) -> void:
    _move_request = RtsMoveRequest.to_entity(eid, min_r, max_r)
    _failed_movements = 0
    # ...

func stop() -> void:
    _move_request = RtsMoveRequest.new()
    _move_request.type = RtsMoveRequest.Type.NONE
    _short_path.clear()
    _long_path.clear()

func has_target() -> bool:
    return _move_request != null and _move_request.type != RtsMoveRequest.Type.NONE

func get_clearance() -> float:
    return _clearance

func set_clearance(c: float) -> void:
    _clearance = c
    # ⚠️ 同步通知 obstr_mgr (clearance ≡ obstruction_shape.radius 不变量, D2)
    # 由 RtsMotionComponent 在 _set_clearance 调用时 emit
```

**M7a.3 — Smoke**

`smoke_motion_path_storage`:
- 创 motion + assign 一个 long_path
- 验证持有 path size > 0
- 清 stop() 后 path empty
- 通过 motion API 不能直接读 _long_path / _short_path(走 has_target)

### M7b — Lifecycle / Failed Movements (1 周)

**M7b.1 — `tick()` 状态机**

```gdscript
func tick(delta: float, world: RtsWorld, facade: RtsPathfinderFacade) -> void:
    if not has_target():
        return
    
    if _path_update_needed():
        _request_long_path(facade)
    
    if _short_path.is_empty():
        if _long_path.is_empty():
            # 两 path 都空 → request short (若 facade 给 best-so-far 仍可能空)
            _request_short_path(facade)
            if _short_path.is_empty():
                _failed_movements += 1
                if _failed_movements >= MAX_FAILED_MOVEMENTS:
                    stop()
                    # emit MoveFailed event 给 activity (M7d 接)
                return
        else:
            # 从 long pop 一个 waypoint 作下一目标,request short to reach it
            var next_long: Vector2 = _long_path.pop_back()
            _request_short_path_to(next_long, facade)
    
    _step(delta, world)

func _path_update_needed() -> bool:
    # 触发条件:_long_path 是空 + 还有 _move_request + 没有 active ticket
    return _long_path.is_empty() and _expected_path_ticket == null

func _request_long_path(facade: RtsPathfinderFacade) -> void:
    var goal := _make_path_goal_from_request()
    if goal == null:
        return
    _long_path = facade.compute_path_immediate(_actor.position_2d, goal, _pass_class.bit_index << 1)
    if _long_path.is_empty():
        _failed_movements += 1
```

**M7b.2 — m_FollowKnownImperfectPathCountdown**

```gdscript
# 在 _step 里:
func _step(delta: float, world: RtsWorld) -> void:
    if _short_path.is_empty():
        return
    var next: Vector2 = _short_path.back()
    var to_next: Vector2 = next - _actor.position_2d
    var step_len: float = _walk_speed * delta
    if to_next.length() < step_len:
        # 到达 next waypoint
        _short_path.pop_back()
        _actor.position_2d = next
    else:
        _actor.position_2d += to_next.normalized() * step_len
    
    # m_FollowKnownImperfectPathCountdown
    if _follow_known_imperfect_path_countdown > 0:
        _follow_known_imperfect_path_countdown -= 1
        if _follow_known_imperfect_path_countdown == 0:
            # short path 已被走完,可能是 best-so-far,触发 long retry
            _long_path.clear()
            _expected_path_ticket = null   # 让下 tick path_update_needed 触发
```

**M7b.3 — Smoke**

`smoke_motion_failed_movements`:
- spawn 单位 + goal 完全围死(M4 make_goal_reachable 也找不到可达)
- 35 tick 内 _failed_movements 累到 35 → motion stop()
- emit MoveFailed event(供 activity 订阅)

### M7c — Movement + Obstruction Sync (1.5 周)

**M7c.1 — `move_shape` per tick + `set_unit_moving_flag`**

```gdscript
func _step(delta: float, world: RtsWorld) -> void:
    var was_moving: bool = (_actor.velocity_2d.length() > 1.0)
    # ... position update ...
    
    var new_velocity: Vector2 = (_actor.position_2d - prev_pos) / delta
    _actor.velocity_2d = new_velocity
    var is_moving: bool = (new_velocity.length() > 1.0)
    
    # Sync obstruction
    var obstr_mgr: RtsObstructionManager = world.obstruction_manager
    obstr_mgr.move_shape(_actor.obstruction_tag, _actor.position_2d)
    if was_moving != is_moving:
        obstr_mgr.set_unit_moving_flag(_actor.obstruction_tag, is_moving)
```

**M7c.2 — RtsWorld.tick 严格顺序(§interfaces.md §10.3)**

```
1. RtsPlayerCommandQueue.flush()
2. for actor in sorted_by_id(motion-bearing):
     actor.motion.tick(delta, world, facade)
3. RtsActivity.tick(delta) — 走刚更新位置
4. ObstructionManager.flush_dirty()
5. HierarchicalPathfinder.update()
6. EventProcessor.flush()
```

**M7c.3 — RtsMotionComponent obstruction sync**

```gdscript
class_name RtsMotionComponent
extends RefCounted

var owner: RtsActor
var motion: RtsUnitMotion

func _init(o: RtsActor, m: RtsUnitMotion) -> void:
    owner = o
    motion = m

func set_clearance(c: float) -> void:
    motion.set_clearance(c)
    # 同步 obstr_mgr (D2: clearance ≡ obstruction_shape.radius 不变量)
    var obstr_mgr: RtsObstructionManager = GameWorld.get("obstruction_manager")
    if obstr_mgr != null and owner.obstruction_tag != 0:
        var shape = obstr_mgr.get_shape(owner.obstruction_tag)
        if shape is RtsObstructionShapeUnit:
            shape.clearance = c    # 直接 mutate (因为 spatial_index 没改 radius...)
            # TODO M7c 决定: 如果 radius 变化,需要 _spatial_index.update(tag, pos, old_r, new_r)
            # 实际项目 unit clearance 罕见运行时变化,本 Epic 先 mutate field, M9 再加完整逻辑
```

**M7c.4 — 删除 RtsNavAgent / RtsUnitSteering**

- grep "RtsNavAgent" / "RtsUnitSteering" 调用列全
- 全部迁到 RtsMotionComponent / RtsUnitMotion
- 删除两个 `.gd` 文件
- ⚠️ M2.3 stuck_detector / push_out 部分逻辑迁到 motion._handle_obstructed_move

**M7c.5 — Smoke**

`smoke_motion_obstruction_sync`:
- 单位 spawn + move 5s
- 每 tick 验证 obstr_mgr.get_shape(actor.obstruction_tag).center == actor.position_2d
- 起步 / 停步时 FLAG_MOVING 切换正确

### M7d — Activity 集成 (1.5 周)

**M7d.1 — Activity API 迁移**

逐个改 RtsActivity 子类:
- `RtsActivityAttack`:`motion.move_to_entity(target_id, min_range=attack_range-tolerance, max_range=attack_range)`
- `RtsActivityGather`:`motion.move_to_entity(resource_id, min_range=0, max_range=interact_distance)`
- `RtsActivityBuild`:同上
- `RtsActivityMoveOrder`:`motion.move_to(target_pos, 0, 0)`(玩家右键)
- `RtsActivityIdle`:`motion.stop()`

**M7d.2 — Activity 监听 motion 事件**

motion 在 abort 时 emit MoveFailed event(`actor.emit_event("motion_move_failed")`),activity 接事件后:
- attack:re-acquire target / abort
- gather:reset 状态
- move order:end activity

**M7d.3 — Smoke**

`smoke_motion_activity_integration`:
- 跑完整 demo 1 局(类似 smoke_rts_auto_battle 4v4 + buildings)
- 验证 attack / gather / build / spawn / die 全套行为正常

---

## 3. 验收准则 (M7 总)

### AC1-AC4 — Sub-phase 单元 🔒 各 sub-phase 单 AC

### AC5 — RtsNavAgent / RtsUnitSteering 删除 🔒
- 文件不存在;调用方 0 处

### AC6 — Activity 全部接 motion API 🔒
- grep "RtsActivity" 子类全部走 `motion.move_to_*`,无遗留旧 API 调用

### AC7 — RtsWorld.tick 6 步顺序正确 🔒
- 单元测试覆盖(unit_A.tick 后 unit_B 看到 obstr_mgr 更新)

### AC8 — Validation + 体验点 ✋4 🔒
- 14 项 + LGF 73 + replay seed=42 deep-equal
- baseline CSV diff: 字段 long_path_size / long_path_wp_json / short_path_size / short_path_wp_json / clearance / failed_movements / ticket_state 全部从占位变实填(预期)
- 体验点 ✋4:demo F6 完整 1 局,attack/gather/build 全正常 + 整体寻路换装

### AC9 — Determinism §12.5 严格遵守 🔒
- Tick 顺序按 actor.get_id() 字典序
- 同 tick 内 unit_A → unit_B 立即可见

### AC10 — Perf ≤ 100% (M7 是大重构,允许放宽到 2×) 🔒
- 若 ≥3× 慢则 stop runner 调优

---

## 4. 关键决策

### M1 — clearance ≡ obstruction.radius 同步策略

- **A. RtsMotionComponent.set_clearance 同步 mutate obstruction.clearance 字段**(field mutate,spatial_index 不动 radius)— Recommended
- B. 删 obstruction shape 后用新 clearance 重新 add_unit_shape(简单但 tag 变 → 影响 motion._actor.obstruction_tag)

> default A;100 单位 game 中 unit 半径罕见运行时改;若有 buff 大幅改半径 → M9 加完整逻辑;A 选项 spatial_index radius 暂不更新会导致少数边角 query 误差(通常 ≤ 1 cell),可接受。

### M2 — Activity emit MoveFailed 事件方式

- **A. motion 自己 emit "motion_move_failed" event 给 actor → activity 监听**(LGF event 风格) — Recommended
- B. activity 每 tick polling motion.has_target / motion.is_failed

> default A;event-driven 更解耦;LGF 已有 event 框架。

---

## 5. 子任务进度

- [ ] M7a — Path Storage
- [ ] M7b — Lifecycle / Failed Movements
- [ ] M7c — Movement + Obstruction Sync
- [ ] M7d — Activity 集成

---

## 6. 残余风险

| # | 风险 | 缓解 |
|---|---|---|
| R1 | Tick 顺序错 → 同 tick unit_B 看到 unit_A 旧位置 → bit-identical 漂 | M7c 末写 unit test 跑 100 tick 跨 unit_A unit_B 交错移动 + verify |
| R2 | Activity 子类多, 漏改 motion API | grep "nav_agent" / "RtsNavAgent" / "RtsUnitSteering" 全部列;每 activity 单元 smoke 跑 |
| R3 | RtsActivity Attack: target 被 obstruction 完全包围 → motion abort → activity 反复 retry | M7d failed_movements 阈值阻止反复;activity 接 MoveFailed 事件后 abort,而非自己 retry |
| R4 | move_to_offset (formation slot) M7 暂不实现 | 留接口 (RtsMoveRequest.with_offset),M9 formation 时用 |
| R5 | Replay 漂:_failed_movements 累加规则错 | 严格按 0 A.D. (每 long path 失败 +1, 重置在 move_to 调用时);smoke_motion_failed_movements 验证 |

---

## 7. 决策来源

- 数据结构: data-structures §8 (codex R2 §12.5 显式定义 tick 顺序)
- 0 A.D. 对照: components/CCmpUnitMotion.h + CCmpUnitMotion_System.cpp(注意:0ad 实际**没有** `CCmpUnitMotion.cpp`,实现拆 .h + System.cpp)
- M6 末态 baseline

---

## 8. 完成后下一步 (M8 启动)

M7 完成 → M8 push pass + 多单位行为 polish。

详见 [`M8-group-push.md`](M8-group-push.md)。
