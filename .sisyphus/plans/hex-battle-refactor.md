# HexBattle 重构为 GameplayInstance

## TL;DR

> **Quick Summary**: 重构 HexBattle 使其继承 GameplayInstance，遵循 GameWorld → GameplayInstance 架构模式，与 TypeScript 侧 InkMonBattle 保持一致。
> 
> **Deliverables**:
> - HexBattle 继承 GameplayInstance
> - 所有调用点改用 GameWorld.tick_all()
> - CharacterActor 通过 create_actor() 创建
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: NO - sequential (依赖链)
> **Critical Path**: Task 1 → Task 2 → Task 3 → Task 4 → Task 5

---

## Context

### Original Request
用户发现 Godot 侧的 hex-atb-battle 没有遵循 GameWorld → GameplayInstance 架构，而 TypeScript 侧的 InkMonBattle 是严格遵循的。需要重构以保持一致性。

### Interview Summary
**Key Discussions**:
- HexBattle 保留自己的 `_actors: Dictionary`，覆盖父类方法（不修改框架层）
- CharacterActor 通过 `create_actor()` 创建
- 所有 3 个调用点都需要迁移：main.gd、SimulationManager.gd、hex-atb-battle-frontend/main.gd
- 暂不抽取 System
- 测试策略：手动验证（运行 main.tscn）
- 序列化不需要兼容

**Research Findings**:
- Godot 框架已完整实现 GameWorld 和 GameplayInstance
- TypeScript 和 Godot 的接口基本一致
- HexBattle 有自己的 `_actors: Dictionary`（key=id），需要保留以保持 O(1) 查找性能

### Metis Review
**Identified Gaps** (addressed):
- _actors 数据结构冲突 → 保留 Dictionary，覆盖父类方法
- tick() 方法处理 → 调用 base_tick(dt) 支持未来 System
- 多个调用点 → 全部迁移
- 逻辑时间管理 → 删除 HexBattle.logic_time，使用父类的 _logic_time

---

## Work Objectives

### Core Objective
使 HexBattle 遵循 GameWorld → GameplayInstance 架构，与 TypeScript 侧保持一致。

### Concrete Deliverables
- `hex_battle.gd`: 继承 GameplayInstance，使用 create_actor()
- `main.gd`: 使用 GameWorld.create_instance() 和 tick_all()
- `SimulationManager.gd`: 使用 GameWorld.create_instance() 和 tick_all()
- `hex-atb-battle-frontend/main.gd`: 使用 GameWorld.create_instance() 和 tick_all()

### Definition of Done
- [x] HexBattle 继承 GameplayInstance
- [x] 所有调用点使用 GameWorld.tick_all()
- [x] 战斗运行正常（headless 模式验证）
- [x] 无语法错误

### Must Have
- HexBattle 继承 GameplayInstance
- CharacterActor 通过 create_actor() 创建
- 所有调用点迁移到 GameWorld.tick_all()
- 保留现有战斗逻辑（ATB、技能执行、事件处理）

### Must NOT Have (Guardrails)
- 不修改 GameplayInstance 基类（保持框架层不变）
- 不改变 HexBattle 的公开接口（Action 类依赖）
- 不改变战斗逻辑（只改架构）
- 不抽取 System（后续优化）

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (无自动化测试框架)
- **User wants tests**: Manual verification
- **Framework**: N/A

### Automated Verification (ALWAYS include)

**For CLI/headless changes** (using Bash):
```bash
# 运行战斗并捕获输出
godot --headless --script addons/logic-game-framework/example/hex-atb-battle/main.gd 2>&1

# 验证关键输出
# - 应包含 "战斗开始"
# - 应包含 "战斗结束"
# - 应包含 "[伤害]"
# - 应包含 "AI 决策:"
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Sequential - all tasks depend on previous):
Task 1: HexBattle 继承 GameplayInstance
    ↓
Task 2: 迁移 Actor 创建方式
    ↓
Task 3: 迁移 main.gd 调用方式
    ↓
Task 4: 迁移 SimulationManager.gd
    ↓
Task 5: 迁移 hex-atb-battle-frontend/main.gd
    ↓
Task 6: 验证

Critical Path: 1 → 2 → 3 → 4 → 5 → 6
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2, 3, 4, 5 | None |
| 2 | 1 | 3, 4, 5 | None |
| 3 | 2 | 6 | None |
| 4 | 2 | 6 | 3 (但建议顺序执行) |
| 5 | 2 | 6 | 3, 4 (但建议顺序执行) |
| 6 | 3, 4, 5 | None | None |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Agents |
|------|-------|-------------------|
| 1 | 1-6 | delegate_task(category="quick", load_skills=[], run_in_background=false) |

---

## TODOs

- [x] 1. HexBattle 继承 GameplayInstance

  **What to do**:
  - 修改 `extends RefCounted` → `extends GameplayInstance`
  - 删除 `var id: String`（使用父类的）
  - 删除 `var logic_time: float = 0.0` 和 `var logicTime: float`（使用父类的 `_logic_time`）
  - 在 `_init()` 中调用 `super._init()` 并设置 `type = "hex_battle"`
  - 修改 `tick(dt)` 在开头调用 `base_tick(dt)`
  - 修改 `start()` 调用 `super.start()` 在状态设置之前
  - 修改 `_end()` 调用 `super.end()` 或 `end()`
  - 覆盖 `get_actor()` 使用自己的 `_actors` Dictionary
  - 覆盖 `get_actors()` 返回 `_actors.values()`

  **Must NOT do**:
  - 不修改 GameplayInstance 基类
  - 不改变战斗逻辑
  - 不删除 `_actors: Dictionary`（保留 O(1) 查找）

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 单文件修改，明确的改动点
  - **Skills**: `[]`
    - 无需特殊技能

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Tasks 2, 3, 4, 5
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `addons/logic-game-framework/core/world/gameplay_instance.gd:1-50` - GameplayInstance 基类接口
  - `addons/logic-game-framework/tests/core/world/world_test.gd:40-60` - GameplayInstance 使用示例

  **API/Type References**:
  - `GameplayInstance._init(id_value: String)` - 构造函数签名
  - `GameplayInstance.base_tick(dt: float)` - 基础 tick 实现
  - `GameplayInstance.start()` - 生命周期方法

  **WHY Each Reference Matters**:
  - `gameplay_instance.gd` - 了解父类接口，确保正确覆盖
  - `world_test.gd` - 参考正确的使用模式

  **Acceptance Criteria**:

  ```bash
  # 验证继承关系
  grep -q "extends GameplayInstance" addons/logic-game-framework/example/hex-atb-battle/hex_battle.gd
  # Assert: 返回 0（找到匹配）

  # 验证删除了 logic_time
  grep "var logic_time: float" addons/logic-game-framework/example/hex-atb-battle/hex_battle.gd
  # Assert: 返回 1（未找到匹配）

  # 验证调用 base_tick
  grep -q "base_tick(dt)" addons/logic-game-framework/example/hex-atb-battle/hex_battle.gd
  # Assert: 返回 0（找到匹配）
  ```

  **Commit**: YES
  - Message: `refactor(hex-battle): inherit from GameplayInstance`
  - Files: `addons/logic-game-framework/example/hex-atb-battle/hex_battle.gd`

---

- [x] 2. 迁移 Actor 创建方式

  **What to do**:
  - 修改 `_create_actor()` 使用 `create_actor(factory)` 模式
  - 在 factory 回调中创建 CharacterActor
  - 保留 `_actors[actor.get_id()] = actor` 字典存储（在 factory 外部）
  - 确保 Actor 的 `on_spawn()` 被调用（create_actor 会自动调用）

  **Must NOT do**:
  - 不改变 CharacterActor 内部逻辑
  - 不删除 `_actors` Dictionary

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Tasks 3, 4, 5
  - **Blocked By**: Task 1

  **References**:

  **Pattern References**:
  - `addons/logic-game-framework/core/world/gameplay_instance.gd:81-86` - create_actor 实现
  - `addons/logic-game-framework/tests/core/world/world_test.gd:52-54` - create_actor 使用示例

  **Current Implementation**:
  - `addons/logic-game-framework/example/hex-atb-battle/hex_battle.gd:220-223` - 当前 _create_actor 实现

  **WHY Each Reference Matters**:
  - `gameplay_instance.gd:81-86` - 了解 create_actor 的工厂模式
  - `world_test.gd:52-54` - 参考正确的调用方式

  **Acceptance Criteria**:

  ```bash
  # 验证使用 create_actor
  grep -q "create_actor(func" addons/logic-game-framework/example/hex-atb-battle/hex_battle.gd
  # Assert: 返回 0（找到匹配）
  ```

  **Commit**: YES
  - Message: `refactor(hex-battle): use create_actor() for CharacterActor`
  - Files: `addons/logic-game-framework/example/hex-atb-battle/hex_battle.gd`

---

- [x] 3. 迁移 main.gd 调用方式

  **What to do**:
  - 在 `_ready()` 中使用 `GameWorld.create_instance()` 创建 HexBattle
  - 将 `battle.tick(tick_interval)` 改为 `GameWorld.tick_all(tick_interval)`
  - 将 `battle._ended` 检查改为 `not GameWorld.has_running_instances()`
  - 在 `_run_battle_sync()` 中同样修改

  **Must NOT do**:
  - 不改变 UI 逻辑
  - 不改变配置传递方式

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Task 6
  - **Blocked By**: Task 2

  **References**:

  **Pattern References**:
  - `addons/logic-game-framework/core/world/game_world.gd:43-53` - create_instance 实现
  - `addons/logic-game-framework/core/world/game_world.gd:79-82` - tick_all 实现

  **Current Implementation**:
  - `addons/logic-game-framework/example/hex-atb-battle/main.gd:22-49` - 当前实现

  **WHY Each Reference Matters**:
  - `game_world.gd:43-53` - 了解 create_instance 的工厂模式
  - `game_world.gd:79-82` - 了解 tick_all 如何驱动所有实例

  **Acceptance Criteria**:

  ```bash
  # 验证使用 GameWorld.tick_all
  grep -q "GameWorld.tick_all" addons/logic-game-framework/example/hex-atb-battle/main.gd
  # Assert: 返回 0（找到匹配）

  # 验证使用 create_instance
  grep -q "GameWorld.create_instance" addons/logic-game-framework/example/hex-atb-battle/main.gd
  # Assert: 返回 0（找到匹配）
  ```

  **Commit**: YES
  - Message: `refactor(hex-battle): use GameWorld.tick_all() in main.gd`
  - Files: `addons/logic-game-framework/example/hex-atb-battle/main.gd`

---

- [x] 4. 迁移 SimulationManager.gd

  **What to do**:
  - 在 `run_battle()` 中使用 `GameWorld.create_instance()` 创建 HexBattle
  - 将 `battle.tick(dt)` 改为 `GameWorld.tick_all(dt)`
  - 将 `battle._ended` 检查改为 `not GameWorld.has_running_instances()`
  - 确保 GameWorld.init() 在创建实例之前调用

  **Must NOT do**:
  - 不改变 JS Bridge 逻辑
  - 不改变返回值格式

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO (建议顺序执行以便验证)
  - **Parallel Group**: Sequential
  - **Blocks**: Task 6
  - **Blocked By**: Task 2

  **References**:

  **Current Implementation**:
  - `scripts/SimulationManager.gd:52-82` - 当前 run_battle 实现

  **WHY Each Reference Matters**:
  - 了解当前的战斗循环逻辑，确保迁移后行为一致

  **Acceptance Criteria**:

  ```bash
  # 验证使用 GameWorld.tick_all
  grep -q "GameWorld.tick_all" scripts/SimulationManager.gd
  # Assert: 返回 0（找到匹配）
  ```

  **Commit**: YES
  - Message: `refactor(simulation): use GameWorld.tick_all() in SimulationManager`
  - Files: `scripts/SimulationManager.gd`

---

- [x] 5. 迁移 hex-atb-battle-frontend/main.gd

  **What to do**:
  - 在 `_run_logic_battle()` 中使用 `GameWorld.create_instance()` 创建 HexBattle
  - 将 `_battle.tick(dt)` 改为 `GameWorld.tick_all(dt)`
  - 将 `_battle._ended` 检查改为 `not GameWorld.has_running_instances()`
  - 确保 GameWorld.init() 在创建实例之前调用（已有）

  **Must NOT do**:
  - 不改变 UI 逻辑
  - 不改变回放加载逻辑

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO (建议顺序执行以便验证)
  - **Parallel Group**: Sequential
  - **Blocks**: Task 6
  - **Blocked By**: Task 2

  **References**:

  **Current Implementation**:
  - `addons/logic-game-framework/example/hex-atb-battle-frontend/main.gd:227-253` - 当前 _run_logic_battle 实现

  **WHY Each Reference Matters**:
  - 了解当前的战斗循环逻辑，确保迁移后行为一致

  **Acceptance Criteria**:

  ```bash
  # 验证使用 GameWorld.tick_all
  grep -q "GameWorld.tick_all" addons/logic-game-framework/example/hex-atb-battle-frontend/main.gd
  # Assert: 返回 0（找到匹配）
  ```

  **Commit**: YES
  - Message: `refactor(frontend): use GameWorld.tick_all() in frontend main`
  - Files: `addons/logic-game-framework/example/hex-atb-battle-frontend/main.gd`

---

- [x] 6. 验证重构结果

  **What to do**:
  - 运行 headless 模式验证战斗正常进行
  - 检查关键输出：战斗开始、伤害事件、AI 决策、战斗结束
  - 验证无语法错误

  **Must NOT do**:
  - 不修改任何代码（只验证）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Final
  - **Blocks**: None
  - **Blocked By**: Tasks 3, 4, 5

  **References**:
  - N/A (验证任务)

  **Acceptance Criteria**:

  ```bash
  # 运行战斗并验证
  cd D:\GodotProjects\inkmon\inkmon-godot
  godot --headless --script addons/logic-game-framework/example/hex-atb-battle/main.gd 2>&1 | tee battle_output.txt

  # 验证关键输出
  grep -q "战斗开始" battle_output.txt && echo "✅ 战斗启动成功"
  grep -q "战斗结束" battle_output.txt && echo "✅ 战斗正常结束"
  grep -c "\[伤害\]" battle_output.txt  # 应 > 0
  grep -c "AI 决策:" battle_output.txt  # 应 > 0

  # 验证架构
  grep -q "extends GameplayInstance" addons/logic-game-framework/example/hex-atb-battle/hex_battle.gd && echo "✅ 继承正确"
  grep -q "GameWorld.tick_all" addons/logic-game-framework/example/hex-atb-battle/main.gd && echo "✅ 调用方式正确"
  ```

  **Evidence to Capture:**
  - [ ] 战斗输出日志
  - [ ] grep 验证结果

  **Commit**: NO (验证任务)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `refactor(hex-battle): inherit from GameplayInstance` | hex_battle.gd | grep 验证 |
| 2 | `refactor(hex-battle): use create_actor() for CharacterActor` | hex_battle.gd | grep 验证 |
| 3 | `refactor(hex-battle): use GameWorld.tick_all() in main.gd` | main.gd | grep 验证 |
| 4 | `refactor(simulation): use GameWorld.tick_all() in SimulationManager` | SimulationManager.gd | grep 验证 |
| 5 | `refactor(frontend): use GameWorld.tick_all() in frontend main` | frontend/main.gd | grep 验证 |
| 6 | N/A | N/A | headless 运行验证 |

---

## Success Criteria

### Verification Commands
```bash
# 1. 架构验证
grep "extends GameplayInstance" addons/logic-game-framework/example/hex-atb-battle/hex_battle.gd
# Expected: class_name HexBattle 下一行是 extends GameplayInstance

# 2. 调用方式验证
grep "GameWorld.tick_all" addons/logic-game-framework/example/hex-atb-battle/main.gd
grep "GameWorld.tick_all" scripts/SimulationManager.gd
grep "GameWorld.tick_all" addons/logic-game-framework/example/hex-atb-battle-frontend/main.gd
# Expected: 每个文件都有匹配

# 3. 运行验证
godot --headless --script addons/logic-game-framework/example/hex-atb-battle/main.gd
# Expected: 输出包含 "战斗开始"、"战斗结束"、"[伤害]"、"AI 决策:"
```

### Final Checklist
- [x] HexBattle 继承 GameplayInstance
- [x] 所有 3 个调用点使用 GameWorld.tick_all()
- [x] CharacterActor 通过 create_actor() 创建
- [x] 战斗运行正常（headless 验证通过）
- [x] 无语法错误
