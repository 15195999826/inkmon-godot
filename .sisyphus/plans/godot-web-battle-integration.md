# Godot + Web 战斗系统集成

## Context

### Original Request
完整跑通 Godot + Web 战斗系统集成流程：
Godot 编码 → 打包为 Web 项目 → Web 无头模式启动 Godot → Web 调用 Godot 战斗逻辑 → 获取回放数据 → Web battleReplay 组件渲染

### Interview Summary

**Key Discussions**:
- 战斗逻辑来源：完全使用 Godot，TypeScript 版本是临时方案
- 数据格式适配：Web 端适配 Godot 输出
- 开发工作流：使用现有导出脚本 `scripts/export-godot.bat`
- 数据传递：JSON 字符串
- InkMon 属性系统：暂不改造，使用现有职业系统
- 任务范围：最小可行流程
- 页面位置：完善现有 `/battle` 页面（不是替换，是让它真正工作）
- 测试策略：手动验证

**Research Findings**:
- Godot 项目已有完整的 HexBattle 战斗系统和 BattleRecorder 回放系统
- SimulationManager.gd 已有 greet() 示例，JS Bridge 模式已验证
- Web 项目已有完整的 BattleReplayPlayer 和 Visualizer 系统
- 现有 /battle 页面使用 /api/battle/simulate API

### Metis Review

**Identified Gaps** (addressed):
- 格式差异：Godot snake_case vs Web camelCase → 创建适配层
- 缺失字段：element, effectiveness → 使用默认值
- 地图配置：需要从 replay.configs.map 读取 → 动态适配

---

## Work Objectives

### Core Objective
让现有 `/battle` 页面完整工作：接入 Godot WASM 战斗逻辑，使用现有的 BattleReplayPlayer 渲染战斗回放。

**现有基础设施**（已完成，不需修改）：
- ✅ 队伍选择 UI（TeamSlot, InkMonPicker）
- ✅ BattleReplayPlayer 回放渲染器
- ✅ Visualizer 系统（Damage, Heal, Move 等）
- ✅ BattleStage Canvas 渲染

**需要接入**：
- Godot WASM 战斗逻辑（替换 TypeScript API 调用）
- 格式适配层（Godot 输出 → Web 期望格式）

### Concrete Deliverables
- Godot: SimulationManager.gd 扩展，支持 `run_battle()` 方法
- Web: godotReplayAdapter.ts 格式适配层
- Web: BattleSimulator.tsx 改造，调用 Godot 而非 API
- 导出: 更新后的 Godot WASM 文件

### Definition of Done
- [ ] 在 /battle 页面点击"开始战斗"，能看到战斗回放动画
- [ ] 回放显示角色移动、攻击、伤害飘字、血条变化
- [ ] 控制台无 JavaScript 错误

### Must Have
- Godot 战斗逻辑运行并返回回放数据
- Web 端能解析并渲染回放
- 基本的错误处理

### Must NOT Have (Guardrails)
- 不改造 InkMon 属性系统
- 不修改 HexBattle 核心逻辑
- 不添加新的战斗特效
- 不优化性能（先跑通再说）

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (跨项目集成，无自动化测试)
- **User wants tests**: Manual-only
- **Framework**: none

### Manual QA Procedures

每个 TODO 包含详细的手动验证步骤，使用：
- **Playwright browser**: 验证 Web 页面渲染
- **Browser Console**: 检查 JavaScript 错误和日志
- **Godot Console**: 检查 GDScript 输出

---

## Task Flow

```
Task 1 (Godot: run_battle)
    ↓
Task 2 (导出 Godot)
    ↓
Task 3 (Web: 适配层)
    ↓
Task 4 (Web: 集成)
    ↓
Task 5 (端到端验证)
```

## Parallelization

| Task | Depends On | Reason |
|------|------------|--------|
| 1 | - | 独立任务 |
| 2 | 1 | 需要 Godot 代码完成 |
| 3 | - | 可与 1 并行 |
| 4 | 2, 3 | 需要 WASM 和适配层 |
| 5 | 4 | 需要集成完成 |

---

## TODOs

- [x] 1. Godot: 扩展 SimulationManager 支持战斗

  **What to do**:
  - 在 `SimulationManager.gd` 中添加 `run_battle()` 方法
  - 创建 HexBattle 实例，运行战斗循环
  - 返回回放 JSON 数据
  - 注册 JS Bridge: `window.godot_run_battle`

  **Must NOT do**:
  - 不修改 HexBattle 核心逻辑
  - 不添加配置解析（使用默认配置）

  **Parallelizable**: NO (基础任务)

  **References**:
  - `scripts/SimulationManager.gd:21-44` - 现有 JS Bridge 模式
  - `addons/logic-game-framework/example/hex-atb-battle/hex_battle.gd:54-130` - HexBattle.start() 方法
  - `addons/logic-game-framework/example/hex-atb-battle/hex_battle.gd:227-260` - tick() 循环
  - `addons/logic-game-framework/example/hex-atb-battle/hex_battle.gd:509-512` - get_replay_data()

  **Acceptance Criteria**:
  - [ ] `run_battle()` 方法存在并可调用
  - [ ] 返回有效的 JSON 字符串
  - [ ] `window.godot_run_battle` 已注册
  - [ ] 本地测试：在 Godot 编辑器中运行，控制台输出回放 JSON

  **Commit**: YES
  - Message: `feat(simulation): add run_battle method for web integration`
  - Files: `scripts/SimulationManager.gd`

- [x] 2. 导出 Godot 项目到 Web

  **What to do**:
  - 运行导出脚本 `D:\GodotProjects\inkmon\scripts\export-godot.bat`
  - 验证 WASM 文件已复制到 `inkmon-web/public/godot/`

  **Must NOT do**:
  - 不修改导出配置

  **Parallelizable**: NO (依赖 Task 1)

  **References**:
  - `D:\GodotProjects\inkmon\scripts\export-godot.bat` - 导出脚本
  - `export_presets.cfg` - 导出配置

  **Acceptance Criteria**:
  - [ ] 导出脚本执行成功，无错误
  - [ ] `inkmon-web/public/godot/inkmon-web.js` 已更新
  - [ ] `inkmon-web/public/godot/inkmon-web.wasm` 已更新
  - [ ] `inkmon-web/public/godot/inkmon-web.pck` 已更新

  **Commit**: NO (不涉及代码变更)

- [x] 3. Web: 创建 Godot 回放格式适配层

  **What to do**:
  - 创建 `lib/battle-replay/adapters/godotReplayAdapter.ts`
  - 实现 snake_case → camelCase 字段转换
  - 处理缺失字段（element, effectiveness 等）
  - 导出 `adaptGodotReplay(godotData: unknown): IBattleRecord`

  **Must NOT do**:
  - 不修改现有 Visualizer
  - 不添加新的事件类型

  **Parallelizable**: YES (可与 Task 1 并行)

  **References**:
  - `inkmon-web/components/battle-replay/types.ts:109-143` - Web 期望的事件格式
  - `addons/logic-game-framework/example/hex-atb-battle/events/replay_events.gd` - Godot 事件格式
  - `addons/logic-game-framework/stdlib/replay/replay_types.gd` - Godot 回放数据结构

  **字段映射**:
  ```
  Godot                    → Web
  target_actor_id          → targetActorId
  source_actor_id          → sourceActorId
  damage_type              → element (映射: physical→normal, magical→psychic)
  is_critical              → isCritical
  is_reflected             → (新增字段或忽略)
  heal_amount              → healAmount
  from_hex/to_hex          → fromHex/toHex
  ```

  **Acceptance Criteria**:
  - [ ] `adaptGodotReplay()` 函数存在
  - [ ] 能正确转换 Godot 回放 JSON
  - [ ] 返回的数据符合 `IBattleRecord` 类型
  - [ ] TypeScript 编译无错误

  **Commit**: YES
  - Message: `feat(battle-replay): add Godot replay format adapter`
  - Files: `lib/battle-replay/adapters/godotReplayAdapter.ts`, `lib/battle-replay/adapters/index.ts`

- [ ] 4. Web: 创建 Godot 服务封装

  **What to do**:
  - 创建 `lib/godot/GodotBattleService.ts`
  - 封装 Godot 初始化和战斗调用
  - 处理 WASM 加载状态
  - 提供 `runBattle()` 异步方法

  **Must NOT do**:
  - 不修改现有 godot-test 页面

  **Parallelizable**: YES (可与 Task 1, 3 并行)

  **References**:
  - `inkmon-web/app/godot-test/page.tsx:18-63` - 现有 Godot 初始化代码
  - `inkmon-web/app/godot-test/page.tsx:91-106` - 现有 JS Bridge 调用模式

  **Acceptance Criteria**:
  - [ ] `GodotBattleService` 类存在
  - [ ] `initialize()` 方法加载 Godot WASM
  - [ ] `runBattle()` 方法调用 `window.godot_run_battle`
  - [ ] 返回适配后的 `IBattleRecord`
  - [ ] TypeScript 编译无错误

  **Commit**: YES
  - Message: `feat(godot): add GodotBattleService for battle integration`
  - Files: `lib/godot/GodotBattleService.ts`, `lib/godot/index.ts`

- [ ] 5. Web: 修改 BattleSimulator 使用 Godot

  **What to do**:
  - 修改 `components/battle/BattleSimulator.tsx`
  - 替换 `/api/battle/simulate` 调用为 `GodotBattleService.runBattle()`
  - 添加 Godot 加载状态显示
  - 处理错误情况

  **Must NOT do**:
  - 不修改队伍选择 UI
  - 不修改 BattleReplayPlayer

  **Parallelizable**: NO (依赖 Task 2, 3, 4)

  **References**:
  - `inkmon-web/components/battle/BattleSimulator.tsx:137-176` - 现有战斗调用逻辑
  - `inkmon-web/components/battle/BattleSimulator.tsx:269-273` - 回放渲染

  **Acceptance Criteria**:
  - [ ] 不再调用 `/api/battle/simulate`
  - [ ] 使用 `GodotBattleService.runBattle()`
  - [ ] 显示 Godot 加载状态
  - [ ] 战斗结果能正确渲染

  **Commit**: YES
  - Message: `feat(battle): integrate Godot battle engine`
  - Files: `components/battle/BattleSimulator.tsx`

- [ ] 6. 端到端验证

  **What to do**:
  - 启动 Web 开发服务器
  - 访问 /battle 页面
  - 选择队伍并开始战斗
  - 验证回放渲染

  **Parallelizable**: NO (最终验证)

  **References**:
  - `inkmon-web/app/battle/page.tsx` - 战斗页面入口

  **Acceptance Criteria**:
  - [ ] 页面加载无错误
  - [ ] Godot WASM 加载成功（控制台显示 "[Godot] Simulation Ready"）
  - [ ] 点击"开始战斗"后，战斗开始运行
  - [ ] 回放播放器显示战斗过程
  - [ ] 能看到角色移动动画
  - [ ] 能看到伤害飘字
  - [ ] 能看到血条变化
  - [ ] 战斗结束后显示结果

  **Manual Verification Steps**:
  1. 运行 `pnpm dev` 启动 Web 服务器
  2. 打开浏览器访问 `http://localhost:3000/battle`
  3. 等待 Godot 加载完成
  4. 点击"随机队伍"填充两边队伍
  5. 点击"开始战斗"
  6. 观察回放播放器
  7. 检查浏览器控制台无错误

  **Commit**: NO (验证任务)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(simulation): add run_battle method` | SimulationManager.gd | Godot 编辑器运行 |
| 3 | `feat(battle-replay): add Godot adapter` | godotReplayAdapter.ts | TypeScript 编译 |
| 4 | `feat(godot): add GodotBattleService` | GodotBattleService.ts | TypeScript 编译 |
| 5 | `feat(battle): integrate Godot engine` | BattleSimulator.tsx | 浏览器测试 |

---

## Success Criteria

### Verification Commands
```bash
# Web 项目编译检查
cd D:\GodotProjects\inkmon\inkmon-web && pnpm build

# 启动开发服务器
cd D:\GodotProjects\inkmon\inkmon-web && pnpm dev
```

### Final Checklist
- [ ] Godot 战斗逻辑通过 WASM 运行
- [ ] 回放数据正确传递到 Web
- [ ] BattleReplayPlayer 能渲染战斗过程
- [ ] 无 JavaScript 控制台错误
- [ ] 无 TypeScript 编译错误
