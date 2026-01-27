# hex-grid → ultra-grid-map 迁移计划

## Context

### Original Request
将 hex-atb-battle-frontend 示例代码从旧的 hex-grid 插件完全迁移到 ultra-grid-map 插件，删除重复的 FrontendHexGridConfig 类。

### Interview Summary
**Key Discussions**:
- 迁移策略：完全迁移，删除 FrontendHexGridConfig，统一使用 ultra-grid-map
- API 兼容性：不需要，这是内部示例代码，可以自由重构
- 测试策略：运行现有测试验证迁移正确性

**Research Findings**:
- `battle_replay_scene.gd` 已使用 `GridMapModel.coord_to_world()` 进行坐标转换
- `GridLayout.coord_to_pixel()` 返回 `Vector2`，需要转换为 `Vector3(x, 0, y)` 用于 3D 渲染
- 旧 `FrontendHexGridConfig.hex_to_world()` 返回 `Vector3`，Z 轴固定为 0
- 现有测试：test_compilation.gd, test_replay_flow.gd, test_3d_visualization.gd

### Metis Review
**Identified Gaps** (addressed):
- Z 轴处理：旧实现 Z=0，新实现需要手动添加 → 已确认 Z=0 是正确的
- 隐藏引用：已用 grep 确认无 .tscn 文件引用
- 测试期望值：测试中无硬编码坐标值，使用动态计算

---

## Work Objectives

### Core Objective
将 `hex-atb-battle-frontend` 中的坐标转换逻辑从 `FrontendHexGridConfig` 迁移到 `ultra-grid-map` 的 `GridLayout`，消除代码重复。

### Concrete Deliverables
- 删除 `grid/hex_grid_config.gd` 文件
- 修改 `core/render_world.gd` 使用 `GridLayout`
- 修改 `core/visualizer_context.gd` 使用 `GridLayout`
- 更新 `tests/frontend/test_compilation.gd` 移除旧测试
- 更新 `README.md` 移除对旧文件的引用

### Definition of Done
- [ ] 所有 3 个 frontend 测试通过
- [ ] 无 LSP 错误
- [ ] `FrontendHexGridConfig` 类不再存在
- [ ] 3D 可视化渲染位置正确（单位位置与迁移前一致）

### Must Have
- 坐标转换结果与旧实现一致（Z=0）
- 保持现有 API 签名（`hex_to_world()` 方法名可保留或改为 `coord_to_world_3d()`）
- 所有现有测试通过

### Must NOT Have (Guardrails)
- 不修改 `battle_replay_scene.gd`（已正确迁移）
- 不添加新测试（只修改现有测试）
- 不进行性能优化
- 不重构无关代码
- 不修改测试期望值（除非必要）

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES
- **User wants tests**: 已有测试
- **Framework**: Godot headless test

### Test Commands
```bash
# 编译测试
godot --headless --script addons/logic-game-framework/tests/frontend/test_compilation.gd

# 回放流程测试
godot --headless --script addons/logic-game-framework/tests/frontend/test_replay_flow.gd

# 3D 可视化测试
godot --headless --script addons/logic-game-framework/tests/frontend/test_3d_visualization.gd
```

---

## Task Flow

```
Task 0 (分析) → Task 1 (render_world) → Task 2 (visualizer_context) → Task 3 (test_compilation) → Task 4 (删除旧文件) → Task 5 (README) → Task 6 (最终验证)
```

## Parallelization

| Task | Depends On | Reason |
|------|------------|--------|
| 0 | - | 分析阶段，无依赖 |
| 1 | 0 | 需要分析结果确定 GridLayout 配置 |
| 2 | 1 | 可能复用 Task 1 的模式 |
| 3 | 1, 2 | 需要先完成代码修改 |
| 4 | 1, 2, 3 | 确保所有引用已迁移 |
| 5 | 4 | 删除文件后更新文档 |
| 6 | 5 | 最终验证 |

---

## TODOs

- [x] 0. 分析阶段：确认 GridLayout 配置模式

  **What to do**:
  - 读取 `battle_replay_scene.gd` 中 GridLayout/GridMapModel 的使用方式
  - 确认 hex_size、orientation 等参数的来源
  - 记录 `FrontendHexGridConfig.hex_to_world()` 的完整实现逻辑

  **Must NOT do**:
  - 不修改任何文件

  **Parallelizable**: NO (第一步)

  **References**:
  - `scene/battle_replay_scene.gd:139-182` - GridMapModel 初始化和使用模式
  - `grid/hex_grid_config.gd:41-60` - 旧的 hex_to_world 实现
  - `addons/ultra-grid-map/core/grid_layout.gd:202-210` - coord_to_pixel 实现

  **Acceptance Criteria**:
  - [x] 记录 GridLayout 初始化所需参数
  - [x] 确认 Z 轴处理方式（应为 0）
  - [x] 确认方向枚举映射关系

  **Commit**: NO

---

- [x] 1. 修改 `render_world.gd` 使用 GridLayout

  **What to do**:
  - 将 `_hex_config: FrontendHexGridConfig` 替换为 `_layout: GridLayout`
  - 修改构造函数参数
  - 修改 `initialize_from_replay()` 中的配置初始化
  - 修改所有 `hex_to_world()` 调用为 `coord_to_pixel()` + Vector3 转换
  - 修改所有 `world_to_hex()` 调用为 `pixel_to_coord()`

  **Must NOT do**:
  - 不修改信号定义
  - 不修改其他无关逻辑

  **Parallelizable**: NO (depends on 0)

  **References**:
  - `core/render_world.gd:42` - `_hex_config` 成员变量定义
  - `core/render_world.gd:62-67` - 构造函数
  - `core/render_world.gd:84-91` - `initialize_from_replay` 中的配置初始化
  - `core/render_world.gd:152` - `world_to_hex()` 调用
  - `core/render_world.gd:379, 386` - `hex_to_world()` 调用
  - `addons/ultra-grid-map/core/grid_layout.gd:77-89` - GridLayout 构造函数
  - `scene/battle_replay_scene.gd:163-166` - GridMapConfig 配置示例

  **Acceptance Criteria**:
  - [x] 无 LSP 错误
  - [x] `godot --headless --script addons/logic-game-framework/tests/frontend/test_compilation.gd` → 通过
  - [x] `godot --headless --script addons/logic-game-framework/tests/frontend/test_replay_flow.gd` → 通过

  **Commit**: YES
  - Message: `refactor(frontend): migrate render_world.gd to GridLayout`
  - Files: `core/render_world.gd`
  - Pre-commit: `godot --headless --script addons/logic-game-framework/tests/frontend/test_compilation.gd`

---

- [x] 2. 修改 `visualizer_context.gd` 使用 GridLayout

  **What to do**:
  - 将 `_hex_config: FrontendHexGridConfig` 替换为 `_layout: GridLayout`
  - 修改构造函数参数
  - 修改 `get_actor_position()` 中的坐标转换
  - 修改 `hex_to_world()` 方法
  - 修改 `get_hex_config()` 为 `get_layout()` 或保持兼容

  **Must NOT do**:
  - 不修改只读查询逻辑
  - 不修改 Actor 状态管理

  **Parallelizable**: NO (depends on 1, 可复用模式)

  **References**:
  - `core/visualizer_context.gd:23` - `_hex_config` 成员变量
  - `core/visualizer_context.gd:28-37` - 构造函数
  - `core/visualizer_context.gd:43-45` - `get_actor_position()` 坐标转换
  - `core/visualizer_context.gd:106-114` - `get_hex_config()` 和 `hex_to_world()`
  - Task 1 中 `render_world.gd` 的修改模式

  **Acceptance Criteria**:
  - [x] 无 LSP 错误
  - [x] `godot --headless --script addons/logic-game-framework/tests/frontend/test_compilation.gd` → 通过
  - [x] `godot --headless --script addons/logic-game-framework/tests/frontend/test_3d_visualization.gd` → 通过

  **Commit**: YES
  - Message: `refactor(frontend): migrate visualizer_context.gd to GridLayout`
  - Files: `core/visualizer_context.gd`
  - Pre-commit: `godot --headless --script addons/logic-game-framework/tests/frontend/test_compilation.gd`

---

- [x] 3. 更新 `test_compilation.gd` 移除旧测试

  **What to do**:
  - 移除 Test 1 中对 `FrontendHexGridConfig` 的测试
  - 可选：添加对 `GridLayout` 的基本测试（验证坐标转换）

  **Must NOT do**:
  - 不修改其他测试用例
  - 不添加复杂的新测试

  **Parallelizable**: NO (depends on 1, 2)

  **References**:
  - `tests/frontend/test_compilation.gd:7-12` - FrontendHexGridConfig 测试代码
  - `addons/ultra-grid-map/core/grid_layout.gd` - GridLayout API

  **Acceptance Criteria**:
  - [x] 测试文件无 LSP 错误
  - [x] `godot --headless --script addons/logic-game-framework/tests/frontend/test_compilation.gd` → 通过
  - [x] 测试输出不再包含 "FrontendHexGridConfig"

  **Commit**: YES
  - Message: `test(frontend): update compilation test for GridLayout migration`
  - Files: `tests/frontend/test_compilation.gd`
  - Pre-commit: `godot --headless --script addons/logic-game-framework/tests/frontend/test_compilation.gd`

---

- [x] 4. 删除 `grid/hex_grid_config.gd` 文件

  **What to do**:
  - 使用 `lsp_find_references` 最终确认无引用
  - 删除 `grid/hex_grid_config.gd` 文件
  - 删除 `grid/hex_grid_config.gd.uid` 文件（如果存在）
  - 如果 `grid/` 目录为空，删除该目录

  **Must NOT do**:
  - 不删除其他文件

  **Parallelizable**: NO (depends on 1, 2, 3)

  **References**:
  - `grid/hex_grid_config.gd` - 待删除文件
  - `grid/hex_grid_config.gd.uid` - 待删除文件

  **Acceptance Criteria**:
  - [x] `lsp_find_references` 返回空或只有自身
  - [x] 文件已删除
  - [x] `godot --headless --script addons/logic-game-framework/tests/frontend/test_compilation.gd` → 通过
  - [x] 无 "FrontendHexGridConfig" 相关的 LSP 错误

  **Commit**: YES
  - Message: `refactor(frontend): remove deprecated FrontendHexGridConfig`
  - Files: `grid/hex_grid_config.gd`, `grid/hex_grid_config.gd.uid`
  - Pre-commit: `godot --headless --script addons/logic-game-framework/tests/frontend/test_compilation.gd`

---

- [ ] 5. 更新 README.md

  **What to do**:
  - 移除目录结构中对 `hex_grid_config.gd` 的引用
  - 更新相关说明（如果有）

  **Must NOT do**:
  - 不重写整个文档
  - 不添加新章节

  **Parallelizable**: NO (depends on 4)

  **References**:
  - `README.md:128` - 目录结构中的 hex_grid_config.gd 引用

  **Acceptance Criteria**:
  - [ ] README 中不再引用 `hex_grid_config.gd`
  - [ ] 目录结构描述与实际一致

  **Commit**: YES
  - Message: `docs(frontend): update README for GridLayout migration`
  - Files: `README.md`
  - Pre-commit: N/A

---

- [ ] 6. 最终验证

  **What to do**:
  - 运行所有 3 个 frontend 测试
  - 检查 LSP 诊断
  - 确认无 FrontendHexGridConfig 相关引用

  **Must NOT do**:
  - 不修改任何文件

  **Parallelizable**: NO (最后一步)

  **References**:
  - `tests/frontend/test_compilation.gd`
  - `tests/frontend/test_replay_flow.gd`
  - `tests/frontend/test_3d_visualization.gd`

  **Acceptance Criteria**:
  - [ ] `godot --headless --script addons/logic-game-framework/tests/frontend/test_compilation.gd` → 通过
  - [ ] `godot --headless --script addons/logic-game-framework/tests/frontend/test_replay_flow.gd` → 通过
  - [ ] `godot --headless --script addons/logic-game-framework/tests/frontend/test_3d_visualization.gd` → 通过
  - [ ] `grep -r "FrontendHexGridConfig" addons/logic-game-framework/` → 无结果
  - [ ] LSP 诊断无错误

  **Commit**: NO (验证步骤)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `refactor(frontend): migrate render_world.gd to GridLayout` | `core/render_world.gd` | test_compilation.gd |
| 2 | `refactor(frontend): migrate visualizer_context.gd to GridLayout` | `core/visualizer_context.gd` | test_compilation.gd |
| 3 | `test(frontend): update compilation test for GridLayout migration` | `tests/frontend/test_compilation.gd` | test_compilation.gd |
| 4 | `refactor(frontend): remove deprecated FrontendHexGridConfig` | `grid/hex_grid_config.gd*` | test_compilation.gd |
| 5 | `docs(frontend): update README for GridLayout migration` | `README.md` | N/A |

---

## Success Criteria

### Verification Commands
```bash
# 所有测试通过
godot --headless --script addons/logic-game-framework/tests/frontend/test_compilation.gd
godot --headless --script addons/logic-game-framework/tests/frontend/test_replay_flow.gd
godot --headless --script addons/logic-game-framework/tests/frontend/test_3d_visualization.gd

# 无旧类引用
grep -r "FrontendHexGridConfig" addons/logic-game-framework/
# Expected: 无输出

# 旧文件已删除
ls addons/logic-game-framework/example/hex-atb-battle-frontend/grid/
# Expected: 目录不存在或为空
```

### Final Checklist
- [ ] 所有 "Must Have" 已实现
- [ ] 所有 "Must NOT Have" 未违反
- [ ] 所有测试通过
- [ ] 无 LSP 错误
- [ ] FrontendHexGridConfig 类已删除

---

## Learnings (执行时写入 learnings.md)

### 写入大文件注意事项
- **问题**: 一次性写入过多内容会导致 write 工具调用失败
- **解决方案**: 对于大文件，使用分段写入或优先使用 edit 命令进行增量修改
- **适用场景**: 单次 write 内容超过 15KB 时需要分段
