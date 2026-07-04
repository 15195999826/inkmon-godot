# Inkmon (Godot)

Godot 4.6 回合制 / ATB 战斗模拟框架。Hex grid + Timeline 技能系统，最终导出为 Web/WASM，在浏览器中通过 JS ↔ Godot 桥接运行；也支持本地 headless 模拟。

## 核心架构

三层设计（顺序 = 依赖方向，上层依赖下层，下层绝不引用上层）：

1. **Core Logic** — 纯模拟，无渲染（`addons/logic-game-framework/core/`）
2. **Game Logic** — 战斗规则/机制（`addons/logic-game-framework/example/<example>/core/` + `logic/`）
3. **Presentation** — VFX / 弹道 / 动画（`addons/logic-game-framework/example/<example>/frontend/`）

事件驱动：`event_processor.gd` 管 pre/post handlers；技能用 timeline keyframe 驱动 actions（hex 例子）；实时类例子（dota2）用固定 tick + `attack_cooldown` 替代 timeline 调度。

目前有两个示例：[hex-atb-battle](addons/logic-game-framework/example/hex-atb-battle/) (回合制 + hex grid) 与 [dota2-auto-battle](addons/logic-game-framework/example/dota2-auto-battle/) (实时固定 tick 30Hz / ARAM 单中路自动战斗 / sim-nav movement adapter; M1 垂直切片)。

## 主游戏逻辑层组织（inkmon/，adr/0002）

主游戏（顶层 `inkmon/` 模块，非 LGF 示例）逻辑层组织铁律。**物理目录已按三层对齐**：`inkmon/host`（composition root）· `inkmon/logic`（`world` / `battle` / `services`）· `inkmon/presentation`；app shell `InkMonMain.tscn` 提到 repo 根。架构真相见 [`docs/main-game-architecture.md`](docs/main-game-architecture.md) + [`docs/adr/0002-gi-organization-state-decides-form.md`](docs/adr/0002-gi-organization-state-decides-form.md)；数据模型见 `docs/adr/0001-unified-live-actor-model.md`。

**一段代码/数据放哪 = state 性质决定（三叉）**：
- **不需跨调用保留状态** → **static 纯函数**（收 `gi`/`actor` 当参数；传参 ≠ 有状态）
- **需保留且 transient（不进存档）** → **GI 持的 RefCounted**；tick 驱动用 LGF `System`
- **需保留且进存档** → **不是 service**，是 **data shape**：活 actor（单只 `InkMonUnitActor` / 玩家级 `InkMonPlayerActor`）或 GI 持的纯数据类

**铁律**：
- **存档从 `InkMonWorldGI` 序列化；service 永不进存档**（持久只走 data shape → "存了啥只看 data shape" 一行审计）
- **actor = 完整游戏实体（数据+逻辑+身份），不是数据袋**；纯数据用普通 RefCounted 数据类，别为序列化硬塞 actor
- **傀儡测试**：RefCounted 升类的唯一理由 = 自己要记 transient 私有 state；没私有 state、全在调 gi → 退回 static 纯函数
- **battle 与 overworld 都不从 GI 拆（对称）**：`WorldGameplayInstance` 基类把 world-host 机器（`start_battle`/`tick`/`grid`/`add_actor` registry/`actor_position_changed`/`add_system`）钉死在 GI 上、**同时**服务 battle 与 overworld；两者杂活皆归 static service（battle → `InkMonBattleSetup`），都不抽成有状态域对象（硬抽得傀儡）。overworld 唯一私有 transient 状态 grid 已是 `InkMonWorldGrid`；详见 adr/0002 推论。

## 目录速查

| 路径 | 职责 |
|---|---|
| `InkMonMain.tscn`（repo 根） | 项目入口 / app shell（`project.godot` main_scene；标题→菜单→进游戏切屏路由，建内层 `inkmon/host`） |
| `inkmon/` | 主游戏模块，物理对齐三层：`host/`（composition root + 入口场景）· `logic/`（`world` / `battle` / `services`）· `presentation/` ＋ `tools/` · `tests/` |
| `scenes/Simulation.tscn` | Web/WASM 桥场景（与主游戏模块正交，非 main_scene） |
| `scripts/SimulationManager.gd` | 主入口，Web 下注册 `window.godot_*` 回调 |
| `scripts/SkillValidator.gd` | AI 生成技能四阶段验证（Compile → Interface → Runtime → Structure） |
| `scripts/SkillPreviewBattle.gd` | 技能预览沙盒战斗 |
| `addons/` | 单一 git submodule → `godot-addons.git`，内含 `logic-game-framework` / `lomolib` / `ultra-grid-map` |
| `logic-game-framework-config/` | 项目级 attribute set 配置（hero / tower） |

修改 `addons/` 下任何文件 = 改上游 submodule，需要在 submodule 内单独 commit。

## Autoload 单例

见 `project.godot` 的 `[autoload]`：
`Log` / `IdGenerator` / `GameWorld` / `TimelineRegistry` / `WaitGroupManager` / `ItemSystem` / `UGridMap`

全局名可直接调用（如 `Log.info(...)`、`GameWorld.get_actor(id)`）。

## 测试

### 首选入口：`tools/run_tests.ps1`

跑测试默认走 launcher，不要手敲多条 `godot --headless`。

```powershell
./tools/run_tests.ps1 -List              # 列出所有 group
./tools/run_tests.ps1 -Required          # 必跑组（core/unit + hex/regression 等）
./tools/run_tests.ps1 hex/skills         # 单组
./tools/run_tests.ps1 hex/all            # 整个 namespace
./tools/run_tests.ps1 dota2autobattle/smoke hex/skills   # 多组合并去重
```

特性：自锁 cwd 到 repo root（pwd 漂走问题根治）；JSON manifest 自动发现（`addons/.../tests/test_groups.json`，加 example 不动 launcher）；真并行 + 独立 timeout；日志写 `.claude/tmp/test-runs/<key>.log`；FAIL 时自动打印末 30 行；退出码 0/1 给 CI。

新增 group → 编辑对应 example 的 `tests/test_groups.json`（在 submodule 内，submodule commit 后主仓 bump pointer）。

### 手跑单 scene 的入口（非 launcher 路径）

| 入口 | 覆盖 |
|---|---|
| **LGF 单元测试** `addons/logic-game-framework/tests/run_tests.tscn` | core（attributes/events/abilities/actions/resolvers/timeline/world）+ 框架特性 |
| **Hex Skill scenario 契约** `addons/logic-game-framework/example/hex-atb-battle/tests/battle/smoke_skill_scenarios.tscn` | 具体 skill 的数值/tag/effect 断言 |
| **Hex 示例前端冒烟** `addons/logic-game-framework/example/hex-atb-battle/tests/frontend/smoke_frontend_main.tscn` | demo_frontend.tscn → core 战斗 → replay → director 播放（~80% 回归面） |
| **Dota2 lane 战斗冒烟** `addons/logic-game-framework/example/dota2-auto-battle/tests/battle/smoke_lane_wave_engage.tscn` | 波次生成 → 相遇 → 攻击 → 伤害 → 死亡 / 持续战斗（M1 垂直切片）|
| **Dota2 前端冒烟** `addons/logic-game-framework/example/dota2-auto-battle/tests/frontend/smoke_frontend_main.tscn` | demo scene 加载 + world / unit view 创建不崩（编辑器 F6 看 lane battle）|

> 其余 smoke 在 `addons/logic-game-framework/tests/**/smoke_*.tscn` 与各 example 子目录下，按文件名打开即可（skill-preview / buff / shield / world-view / nav / ai / attack 等）。

### 跑测试：优先在 Godot 编辑器里跑

**Godot 编辑器**（最快，日常开发用这个）：打开 `run_tests.tscn` / `smoke_*.tscn`，F6 跑当前场景，**1 秒出结果**。

**Headless 命令行**（CI 或脚本化时用）：
```bash
godot --headless --path . <scene.tscn> > /tmp/godot_out.txt 2>&1
# 然后读 /tmp/godot_out.txt
```

**❌ 不要 `| grep`**：Windows Git Bash 下 pipe buffering + Godot ObjectDB leak cleanup 组合会让命令"假卡住"2-3 分钟（Godot 实际 30s 内就退了，但 pipe 不 flush）。**永远用 `> file 2>&1` redirect**，再 `cat` / `tail` / `Read` 读文件。

退出码 0 = PASS；smoke 测试输出 `SMOKE_TEST_RESULT: PASS|FAIL - <reason>`。

### 推荐流程

- **改 LGF core / 框架层**：跑单元测试 + 相关 `addons/logic-game-framework/tests/example/**/smoke_*.tscn`；新机制加 `*_test.gd` 登记到 `addons/logic-game-framework/tests/run_tests.gd::TEST_PATHS`
- **开发新技能**：写 `addons/logic-game-framework/example/hex-atb-battle/tests/battle/skill_scenarios/*_scenario.gd`，由 `smoke_skill_scenarios.tscn` 自动扫描；再跑示例前端 smoke 确保集成不崩
- **修 bug**：找覆盖到该路径的 smoke 复现，修完跑同一个验证

### 写 smoke scene 的约定

模板 `addons/logic-game-framework/tests/example/**/smoke_*.gd`：
- `extends Node`，`_ready()` 同步跑断言（或 `_process` 轮询异步）
- 结尾 `SMOKE_TEST_RESULT: PASS - <reason>` / `FAIL - <reason>`
- `get_tree().quit(0/1)` 让 CI 读 exit code
- 一个 `.gd` + 一个 `.tscn`（`.tscn` 只是挂 script 的空 Node）

`smoke_frontend_main` 是**结构不变量断言**（frame 推进 / unit 数量 > 0 / hp ∈ [0, maxHp]），不断言具体数值，加新技能/单位通常不用改它。

### 禁忌与既知坑

- **别用** `godot --headless --script <file>.gd`：`--script` 模式不触发 autoload，`Log`/`GameWorld` 全报错。始终用 `.tscn` 入口。
- **别用** `godot ... | grep`：pipe buffering bug，见上面"跑测试"段。
- Godot 退出时 `ObjectDB instances leaked` / `N resources still in use` 警告是 main.tscn 流程的既有资源泄漏，**不影响退出码**，修要去 LGF addon 内部排。
- AutoLoad 已由 `project.godot` 完整配置，**无需手工设置**（不存在需要手敲 AutoLoad 的步骤）。

## Web / JS 桥接

`SimulationManager._setup_js_bridge()` 注册的 window 回调：
- `godot_greet` — 连通性测试
- `godot_run_battle` — 跑一场战斗
- `godot_test_runtime_script` — 动态加载脚本
- `godot_validate_skill` — 校验 AI 生成技能
- `godot_preview_skill` — 预览技能

只在 `OS.has_feature("web")` 下注册；本地跑会进 headless 测试分支。

## 规范与踩坑

项目自带 Codex Skill（`.agents/skills/`，按需加载，不常驻 context；Claude mirror 在 `.claude/skills/`）：

- **`gdscript-coding`** — 通用 GDScript 编码规范（类型、shadowing、I* pattern、`Log.assert_crash` 等 14 条）；踩坑见同目录 `reference/troubleshooting.md`
- **`enforcing-lgf`** — Logic Game Framework 约定（Actor 生命周期、共享对象无状态、Intent 返回、Resolver 等）；详细 API 在 `reference/*.md`
- **`lgf-new-logic-skill`** — 实现新 skill / ability / buff / passive 时的 "去哪写、怎么 wire 进 submodule、怎么测" 指南（搭配上面两个使用）
- **`sim-nav-map`** — `addons/sim-nav-map` 背景速记：现役 `dota2-rts-pathfinding-lab`、已删除的旧 `rts-pathfinding-lab`/`0ad-rts-pathfinding-lab` 边界，以及 0 A.D. 本地源码优先规则

配套 Claude slash command（`.claude/commands/`）：

- `/review-gdscript <path>` — 按 14 条规范批量审 `.gd` 文件
- `/update-lgf-skill` — 根据 LGF addon 新提交增量更新 `enforcing-lgf` 文档

LGF 原始架构文档：`addons/logic-game-framework/AGENTS.md` 和同级 `docs/`。

修改 `.gd` 文件 / 接触 LGF 类时 skill 会自动触发，不要在此文件复述规范内容。

## 本地约定

- **分支策略：除非用户明确要求，开发与提交一律在主分支（`master`）直接进行，不擅自开 feature/refactor 分支**（覆盖"在默认分支上先 branch"的通用习惯）。需要隔离时用户会明说要开分支。
- 响应用中文，技术术语/代码保留英文
- UI/场景改动需在编辑器中验证，不能仅靠 headless
- `texture-gen` 生图一律使用 `quality=low`；这不等于低分辨率，地图参考图等需要细节的场景可以提高 `size`（如 4K）。不要为了贴图清晰度切 `medium/high`，清晰度优先通过更高 `size`、`2048 internal -> 512 Lanczos + UnsharpMask` 等 bake 后处理保证。
