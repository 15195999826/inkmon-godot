# M2.1 — Phase A — Multi-Resource Foundation

> Phase A 是 RTS M2.1 Economy 的第一个 phase。**Scope 限定**: 把 cost / starting_resources / team_resources 全链路从 `int` 迁到 `Dictionary[String, int]`; 既有 6 个 RTS smoke fixture 全部硬迁; LGF 73/73 + bit-identical replay 不退化。
>
> **不引入** worker / harvest / 经济闭环 (那些是 Phase B/C/D)。

---

## Acceptance (7 条, 详见 `.feature-dev/Next-Steps.md`)

- AC1 — `RtsBuildingConfig.cost: int` → `cost: Dictionary[String, int]`
- AC2 — `RtsTeamConfig.starting_resources: int` → `Dictionary[String, int]`
- AC3 — `RtsAutoBattleProcedure._team_resources` runtime + signature dict 化
- AC4 — `RtsBuildingPlacement.validate` multi-resource check (reason 含 `not_enough_<kind>`)
- AC5 — 6 个既有 smoke 全过 (硬迁 fixture, 0 行为差)
- AC6 — LGF 73/73 + bit-identical replay 不退化 + frontend smoke 不退化
- AC7 — Demo HUD Label 拆 "Gold: X | Wood: Y"

---

## 子任务 6 步 (推荐顺序)

### A.1 — RtsBuildingConfig.cost 迁 dict

**文件**: `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_building_config.gd`

**改动**:
- `cost: int = 100` → `cost: Dictionary[String, int] = {"gold": 100}`
- 若有 `static create_*` factory 默认值, 同步改 default
- 任何读取 cost 的 internal helper 同步 (typically 没有, 字段 by-name 读)

**完成判定**: grep `\.cost\b` 在 `addons/logic-game-framework/example/rts-auto-battle/` 全部命中点适配; 0 处 `int` 型 cost 读取

---

### A.2 — RtsTeamConfig.starting_resources 迁 dict

**文件**: `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_team_config.gd`

**改动**:
- `starting_resources: int = 200` → `starting_resources: Dictionary[String, int] = {"gold": 200, "wood": 0}`
- `static create(...)` factory 同步改入参类型
- `static unconfigured(team_id)` factory return dict 形态 (default {"gold": 0, "wood": 0})
- 既有 helpers (若有 `has_resources` / `get_resources`) 同步

**完成判定**: grep `starting_resources` 全部命中点适配

---

### A.3 — RtsAutoBattleProcedure._team_resources runtime + signature 改 dict

**文件**: `addons/logic-game-framework/example/rts-auto-battle/core/rts_auto_battle_procedure.gd`

**改动**:
- `_team_resources: Dictionary[int, int]` → `_team_resources: Dictionary[int, Dictionary[String, int]]`
  - key = team_id; value = `{"gold": 200, "wood": 0}` 之类的 dict
- `spend_team_resources(team_id: int, cost: Dictionary)` signature 改; 内部逐 key 减 (逐 key 假设资源充足, 上层 placement.validate 已 check)
- 若有 `add_team_resources` / `refund_team_resources` (Phase D 会加), 不预先加; Phase A 仅适配 spend
- `get_team_resources(team_id: int) -> Dictionary` 返回 dict 拷贝 (避免外部改 reference 影响 internal state)
- `start()` 起手用 team_config.starting_resources 初始化 _team_resources[team_id] 改 dict 化
- PlaceBuildingCommand.apply 调用点适配 (若 spend signature 变了, apply 内部同步; 见 A.4 placement.validate 联动)

**完成判定**: grep `_team_resources` + `spend_team_resources` + `get_team_resources` 全部命中点适配; smoke_player_command 跑通验证

---

### A.4 — RtsBuildingPlacement.validate 走 multi-resource check

**文件**: `addons/logic-game-framework/example/rts-auto-battle/logic/commands/rts_building_placement.gd`

**改动**:
- validate 内资源 check 从 `if resources < cost: reason = "not_enough_resources"` 改为逐 key:
  ```gdscript
  for kind in cost:
      if team_resources.get(kind, 0) < cost[kind]:
          return {"ok": false, "reason": "not_enough_" + kind, ...}
  ```
- reason 枚举 (commands/README.md 若有 reason 列表) 加 `not_enough_gold` / `not_enough_wood`; 移除老的 `not_enough_resources` 字面量
- 调用 procedure.get_team_resources(team_id) 拿 dict 形态 (依赖 A.3)

**完成判定**: grep `not_enough_resources` 0 命中; smoke_player_command 中 fail case (build_zone 之外 / 同位置二次) 验证 OK; 新增 fail case (gold 不足) 走 not_enough_gold

---

### A.5 — 既有 6 smoke fixture 适配

**文件**:
- `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_player_command.gd`
- `tests/battle/smoke_player_command_production.gd`
- `tests/battle/smoke_castle_war_minimal.gd`
- `tests/battle/smoke_production.gd` (若有创建 RtsBuildingConfig 的地方; production smoke 主要走 spawn 不走 cost)
- `tests/battle/smoke_crystal_tower_win.gd` (起手就有 ct, cost 路径不走; 主要 fixture 是 starting_resources)
- `tests/battle/smoke_rts_auto_battle.gd` (4v4 主, 不传 team_configs → fallback; 检查 fallback 路径不破坏)

**改动**:
- 任何创建 `RtsBuildingConfig.cost = 100` → `RtsBuildingConfig.cost = {"gold": 100}`
- 任何创建 `RtsTeamConfig.starting_resources = 200` → `RtsTeamConfig.starting_resources = {"gold": 200, "wood": 0}`
- 任何 assert `procedure.get_team_resources(team_id) == 100` → `assert procedure.get_team_resources(team_id) == {"gold": 100, "wood": 0}` (或 deep_equal)
- smoke_player_command 中 fail case (out_of_build_zone) 验证 reason 字符串不变; 新增可选 case: 把 starting 改为 {"gold": 50, "wood": 0} 然后试放 cost {"gold": 100} → reason=not_enough_gold

**完成判定**: 6 smoke 全部 PASS, 输出与 RTS M1 末态对比 0 行为差 (ticks / spawn count / max_eastward 等数字一致)

---

### A.6 — Demo HUD Label 升级

**文件**:
- `addons/logic-game-framework/example/rts-auto-battle/frontend/demo_rts_frontend.gd`
- `addons/logic-game-framework/example/rts-auto-battle/frontend/demo_rts_pathfinding.gd` (若也显示 resources)

**改动**:
- HUD Label 文本从 `"Resources: %d"` 升级 `"Gold: %d | Wood: %d"` (左方); 右方同理
- 取数源走 `procedure.get_team_resources(team_id)["gold"]` / `["wood"]` (依赖 A.3 的 dict 形态)
- ct hp Label 不动 (与 resources 无关)

**完成判定**: 编辑器 F6 跑 demo_rts_frontend.tscn → HUD 显示 "Gold: 200 | Wood: 0" 起手, 放 barracks 后 Gold=100; demo_rts_pathfinding 同理 (若改了)

---

## Validation 顺序 (A.1-A.6 全做完后)

按 `.feature-dev/Autonomous-Work-Protocol.md` §Validation 顺序:

```bash
# 1) Type check (Godot import — 主仓不需要每次 import, 但 cost 字段类型变了走一次确认 .gd 编译过)
godot --headless --path . --import > /tmp/m21_a_import.txt 2>&1

# 2) LGF unit tests (regression gate, baseline 73/73)
godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn > /tmp/m21_a_lgf_unit.txt 2>&1

# 3) RTS 6 smoke (AC5)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_player_command.tscn > /tmp/m21_a_pc.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_player_command_production.tscn > /tmp/m21_a_pcp.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_castle_war_minimal.tscn > /tmp/m21_a_cw.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_production.tscn > /tmp/m21_a_prod.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_crystal_tower_win.tscn > /tmp/m21_a_ct.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn > /tmp/m21_a_main.txt 2>&1

# 4) Replay determinism (AC6, 关键风险点 — Dictionary iteration order)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/replay/smoke_replay_bit_identical.tscn > /tmp/m21_a_replay.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/replay/smoke_determinism.tscn > /tmp/m21_a_det.txt 2>&1

# 5) Frontend smoke (AC6)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/frontend/smoke_frontend_main.tscn > /tmp/m21_a_fe.txt 2>&1

# 6) Hex demo regression (sanity, 每 phase 完成走一次)
godot --headless --path . addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn > /tmp/m21_a_hex.txt 2>&1
```

每个文件读末尾 100 行检查 `SMOKE_TEST_RESULT: PASS` + 退出码 0; 失败时不抬 timeout 重跑, 直接看 `SCRIPT ERROR` / `await` 链断点。

按 `Autonomous-Work-Protocol.md` 的 Bash 并行约定: 1+2 串行 → 3 (6 smoke 分 2 批并行 3 个/批) → 4 (replay 2 个并行) → 5+6 (并行)。

---

## 风险与对策

| 风险 | 触发条件 | 对策 |
|---|---|---|
| Dictionary iteration order 破坏 bit-identical replay | spend_team_resources / get_team_resources 内部 keys() 迭代顺序变化间接影响 RNG / event order | smoke_replay_bit_identical 是关键 gate; 若 fail, grep dict.keys() 用法, 改为 sorted keys() 或固定顺序遍历 |
| 6 smoke fixture 漏改 | smoke_*.gd 内创建 RtsBuildingConfig / RtsTeamConfig 时 cost / starting_resources 用了旧 int 字面量 | 实施前 grep `cost\s*=\s*\d+\b\|starting_resources\s*=\s*\d+\b` 全检; 实施后再 grep 0 命中确认 |
| Demo 改动破坏 F6 | HUD Label 改字段后 procedure.get_team_resources 返回类型不匹配 → demo crash | demo 改动单独验证; smoke 不依赖 demo, demo crash 不阻塞收口 (打 followup 即可) |
| 旧 reason 字符串外漏 | smoke / 文档 用了 `not_enough_resources` 字面量, 迁后改 `not_enough_gold` 后字符串不匹配 | grep `not_enough_resources` 全检, 改/删字面量 |

---

## Commit 策略 (沿用 Autonomous-Work-Protocol.md)

Phase A 收口时: 子任务 (A.1-A.6) 全部 acceptance 子项 PASS + smoke 不退化 + 文档同步更新 → submodule commit (`feat(rts-m21): Phase A done — multi-resource cost dict 化`) → 主仓 bump pointer commit (`feat(rts-m21): bump addons + 同步 .feature-dev`)。

不预先 commit 中间状态 (A.1 改完但 A.5 fixture 没适配会让 smoke 全 fail)。
