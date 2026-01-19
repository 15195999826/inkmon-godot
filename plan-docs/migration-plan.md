**Logic Layer Migration Plan (TS → Godot 4.6 GDScript)**

**Scope**
- 仅迁移逻辑层（无表现层适配）。
- 覆盖模块：`attributes`, `abilities`, `actions`, `world`, `entity`, `events`, `tags`, `timeline`。
- 以 TS `tests/` 中的用例为验证标准。

**Target Runtime**
- Godot 4.6
- 语言：GDScript
- 测试：自定义轻量测试运行器（命令行运行）

---

## 1. Project Structure

**Godot逻辑目录**
- `res://logic/`
  - `attributes/`
  - `abilities/`
  - `actions/`
  - `world/`
  - `entity/`
  - `events/`
  - `tags/`
  - `timeline/`
  - `utils/`

**测试目录**
- `res://tests/`
  - `tests/core/...`
  - `tests/events/...`
  - `test_framework.gd`
  - `run_tests.gd`

---

## 2. Migration Phases

### Phase 1: Core Types / Utils / Tags
**Goal**
- 迁移基础类型与工具，保证依赖最小闭环。

**Deliverables**
- `logic/types/*.gd`
- `logic/utils/*.gd`（IdGenerator/Logger 等）
- `logic/tags/TagContainer.gd`

**Tests**
- 若 TS tests 中有相关用例，则创建对应测试脚本。

---

### Phase 2: Attributes + Tests
**Goal**
- 完整迁移属性系统与 modifier 计算。

**Deliverables**
- `logic/attributes/*.gd`
- 对应测试脚本：
  - `tests/core/attributes/AttributeSet_test.gd`
  - `tests/core/attributes/defineAttributes_test.gd`

**Validation**
- 四层公式逻辑（AddBase, MulBase, AddFinal, MulFinal）
- modifier 管理与监听器行为一致

---

### Phase 3: Events + Tests
**Goal**
- 迁移事件系统（MutableEvent / EventProcessor）。

**Deliverables**
- `logic/events/*.gd`
- 对应测试脚本：
  - `tests/events/EventProcessor_test.gd`
  - `tests/events/PreEventComponent_test.gd`（部分会依赖 abilities）

**Validation**
- MutableEvent 的 add/set/multiply 顺序
- EventProcessor handler 注册/注销/trace/深度限制

---

### Phase 4: Abilities + Timeline + Tests
**Goal**
- Ability、AbilitySet、执行实例与组件体系迁移。

**Deliverables**
- `logic/abilities/*.gd`
- `logic/timeline/*.gd`
- 对应测试脚本：
  - `tests/core/abilities/Ability_test.gd`
  - `tests/core/abilities/ActivateInstanceComponent_test.gd`
  - `tests/core/abilities/AbilityExecutionInstance_test.gd`

**Validation**
- Ability 生命周期
- ExecutionInstance 状态推进与清理
- Component 生命周期回调一致

---

### Phase 5: Actions / World / Entity
**Goal**
- 完整迁移执行上下文、Action 系统与世界/实体系统。

**Deliverables**
- `logic/actions/*.gd`
- `logic/world/*.gd`
- `logic/entity/*.gd`
- 对应 tests 中的 `core/actions` / `integration` 用例

---

## 3. Testing Strategy (Godot CLI)

**Custom Test Framework**
- `test_framework.gd` 实现 `describe/it/expect/before_each/after_each`
- `expect` 支持 `to_be`, `to_equal`, `to_be_close_to`, `to_be_true`, `to_be_false` 等
- Mock/Spy：提供 `mock_fn` 与 `spy_on`

**Runner**
- `run_tests.gd` 统一加载与执行测试文件

**CLI Execution**
```
godot --headless --path . --script res://tests/run_tests.gd
```

**Output**
- 通过/失败统计
- 失败断言与堆栈信息

---

## 4. Git Commit Strategy
- 每完成一个阶段，执行一次提交：
  - Phase 1: core基础迁移
  - Phase 2: attributes + tests
  - Phase 3: events + tests
  - Phase 4: abilities + timeline + tests
  - Phase 5: actions/world/entity + tests

---

# 参考项目路径
E:\talk\LomoMarketplace\packages\logic-game-framework