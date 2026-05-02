# M2.1 — Phase D — Cost Rebalance + smoke_economy_demo

> **Status**: ✅ done (2026-05-02; 5/5 AC PASS, 18/18 validation 全套 PASS, simplify pass clean)
>
> **Phase D 是 RTS M2.1 Economy 的最后一个 phase, 经济闭环对外可观**: 给 archer_tower / barracks 重定 multi-resource cost (Phase A 占位 cost 改为有差异化的双资源 trade-off) + 新 smoke_economy_demo (full cycle: worker harvest → 资源到达 cost → enqueue PlaceBuildingCommand → 自动放下个建筑) + 编辑器 F6 视觉验证 demo_rts_frontend worker spawn 视觉链路。

---

## Acceptance

- [x] **AC1** Building cost 重平衡 — multi-resource trade-off
  - 数值 (D17 finalized): barracks `{"gold": 80, "wood": 50}`; archer_tower `{"gold": 60, "wood": 100}`; crystal_tower `{}` (起手就有)
  - 实现: `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_building_config.gd:104` (_BARRACKS_STATS cost), `:130` (_ARCHER_TOWER_STATS cost), `:85` (_CRYSTAL_TOWER_STATS cost {})
  - 数值原则: gold-rich 偏 barracks (近战推 ct); wood-rich 偏 archer_tower (远程防空); 两资源都需要才能两者皆造
- [x] **AC2** starting_resources 调值
  - 数值 (D17 finalized): `{"gold": 100, "wood": 100}` — 起手能造 barracks 或 archer_tower 之一, 不能两个; worker 必须 harvest 补另一资源
  - 实现 (按 "或 smoke setup" 分支): rts_team_config.gd 默认 `{}` 不动 (unconfigured 占位); 各 smoke 直接走 RtsTeamConfig.create 传 `{"gold": 100, "wood": 100}`:
    - `smoke_player_command.gd:38-39` (STARTING_GOLD/WOOD = 100)
    - `smoke_player_command_production.gd:32-33` (同)
    - `smoke_castle_war_minimal.gd:36-37` (STARTING_GOLD_LEFT/STARTING_WOOD_LEFT = 100)
    - `frontend/demo_rts_frontend.gd:33-34` (同)
  - smoke_economy_demo.gd 用 `{0, 0}` 强制 harvest cycle (与 demo 玩法 starting 不同; 见 AC3 设计说明)
- [x] **AC3** 新 `smoke_economy_demo.{gd,tscn}` PASS — full cycle 经济闭环
  - Setup: 左 team 5 worker + 1 ct + 1 中立 gold node + 1 中立 wood node (与 smoke_harvest_loop 同模式, 实测 1+1 worker 按距离自然 mix; 2+2 同侧布局会让 worker 全选 gold), 右 team 1 ct (防右方判负)
  - 起手 starting `{"gold": 0, "wood": 0}` (强制 worker harvest 才能放 barracks; 与 demo 玩法 starting 100/100 不同 — smoke 验"harvest 攒到 cost"的 critical path)
  - Tick budget (D18 finalized): **900 tick @ 30Hz (timeout 45000ms)** — 覆盖 worker harvest cycle + 资源到达 cost + barracks 放置 + barracks spawn melee + melee 攻 ct
  - 测试逻辑: 主循环每 tick check resources; 满 80g+50w 时 enqueue PlaceBuildingCommand barracks (一次性 _barracks_enqueued flag) → 等 barracks spawn melee → 验证 melee 至少 1 次攻 ct
  - 验证断言 (5 项): `worker 不卡 (alive=5) + cycle 完整 (≥1 worker carrying 曾非空) + barracks 放置成功 (placement.success=true; _barracks_enqueued 隐含 resources 曾达到 cost) + ≥ 1 melee spawn + ≥ 1 次 melee→right_ct attack event`
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_economy_demo.{gd,tscn}` (新)
  - 实测 PASS evidence: ticks=900 alive_workers=5 cycle_workers=5 barracks_enqueued_tick=348 melee_spawned=4 melee_to_ct_attacks=31
- [x] **AC4** demo_rts_frontend 起手 spawn worker + node — 编辑器 F6 视觉验证经济闭环
  - 起手 spawn (D19 finalized): 双方各 5 worker + 1 ct + 2 gold node + 2 wood node
  - 玩家用鼠标点击放 barracks (现有 Click left mouse 玩家命令链路, 复用 Phase A HUD)
  - 实现: `frontend/demo_rts_frontend.gd` 完全重写 — 删 archer/4 ground/flying_scout, 加 5 worker / 方 + 4 中立 ResourceNode / 方
  - HUD Label 文字更新为 "cost: gold 80 + wood 50" (Phase A 拆 Gold/Wood 双显示沿用)
  - 注意: ResourceNode 没 RtsResourceNodeVisualizer (WorldView._spawn_visualizer 仅对 RtsUnitActor / RtsBuildingActor 创 visualizer); F6 时 node 不可见, 视觉链路依赖 worker 移动 + HUD 资源数字增长。后续若需可视 node, 可加 RtsResourceNodeVisualizer
  - F6 视觉验证留给用户 (headless smoke 不阻塞)
  - frontend smoke_frontend_main 验 visualizers=10 (5 worker × 2 = 10) alive_after_3.0s=10 不崩 ✓
- [x] **AC5** Validation 全套不退化 (LGF 73/73 + 12 既有 RTS smoke + smoke_harvest_loop + smoke_economy_demo + 2 replay smoke + frontend smoke = 14 RTS smoke 共 18 项)
  - Phase D cost 数字改影响的 fixture 已适配 (与 Phase A 末态适配同模式):
    - smoke_player_command (硬码 cost 检验) — STARTING_GOLD/WOOD 200/0 → 100/100; BARRACKS_COST_GOLD 100→80; 加 BARRACKS_COST_WOOD=50; 验证段从 `expected wood=STARTING_WOOD` 改为 `expected wood=STARTING-COST_WOOD`; PASS gold_remaining=20 wood_remaining=50
    - smoke_player_command_production (gold_remaining 数字断言) — STARTING_GOLD/WOOD 200/0 → 100/100; BARRACKS_COST_GOLD 100→80; PASS gold_remaining=20 (其它数字 left_spawned=7 max_eastward=254.74 0 漂移)
    - smoke_castle_war_minimal — STARTING_GOLD_LEFT 仍 100; 加 STARTING_WOOD_LEFT=100; PASS ticks=193 result=left_win unit_to_building_attacks=4 archer_anti_air=1 spawn_count=2 (与 Phase C 末态完全一致 0 漂移)
    - smoke_replay_bit_identical — starting wood 0 → 500 (双方都加, 让 placement 不会失败); PASS bit-identical 0 漂移 frames=9 events=20

---

## 设计决策 (Phase D 启动时已 finalize)

### D17 — Cost 数值具体配方 ✅ finalized (skeleton 草案)

- barracks: `{"gold": 80, "wood": 50}`
- archer_tower: `{"gold": 60, "wood": 100}`
- crystal_tower: `{}` (起手就有, 不可建造来源)
- starting_resources: `{"gold": 100, "wood": 100}`

**意图**:
- 让两资源都对玩家"有用" — wood 不是死字段
- 起手不够直接造 barracks — 强制 worker harvest 补 wood (起手 50w 凑不齐 barracks 50w 之外的 archer_tower 100w; 起手 100w 凑齐 1 个但凑不齐两个)
- trade-off 有意义 — gold-rich 玩家偏 barracks (近战推 ct); wood-rich 玩家偏 archer_tower (远程防空)

### D18 — smoke_economy_demo 时长 + 阈值 ✅ finalized

- **900 tick** (Phase C 实测 cycle ≈ 3s = 90 tick @ 30Hz; 5 worker 凑 cost 约 15s = 450 tick; 再加 barracks spawn + 行军预留 → 900 tick 安全覆盖)
- Bash timeout: **45000ms** (按 CLAUDE.md §Headless smoke 长跑 smoke 档)
- 必验断言: building 放置成功 + ≥ 1 melee spawn + ≥ 1 次 melee 打 ct + cycle 完整 (≥ 1 worker harvest→drop-off 闭环) + worker 不卡

### D19 — demo_rts_frontend Phase D 起手 spawn 列表 ✅ finalized (skeleton 草案)

- 双方各 spawn: **5 worker + 1 ct + 2 gold node + 2 wood node**
- 玩家用鼠标点击放 barracks (复用现有 Click left mouse 玩家命令链路)
- F6 验证视觉链路: worker → harvest → cycle → 资源 bar 涨 → 鼠标点击放 barracks → barracks spawn melee → melee 攻击对面

---

## 子任务进度 (✅ 全过)

- [x] **D.1 — Cost 数值改 + smoke fixture 适配**
  - rts_building_config.gd: barracks cost {gold:80, wood:50}; archer_tower cost {gold:60, wood:100}; crystal_tower 仍 {} (Phase A 默认)
  - 4 个 smoke fixture 适配 starting_resources / cost 数字断言: smoke_player_command / smoke_player_command_production / smoke_castle_war_minimal / smoke_replay_bit_identical
- [x] **D.2 — `smoke_economy_demo.{gd,tscn}` 新文件** (full cycle 经济闭环)
  - 实测 PASS: ticks=900 alive_workers=5 cycle_workers=5 barracks_enqueued_tick=348 melee_spawned=4 melee_to_ct_attacks=31 final_gold=138 final_wood=196
- [x] **D.3 — `demo_rts_frontend.gd` 起手 spawn 改** (5 worker+1 ct+4 中立 node / 方; 删 archer/4 ground/scout)
  - frontend smoke 验 visualizers=10 alive_after_3.0s=10 不崩 ✓
  - F6 视觉验证留给用户 (ResourceNode 当前无 visualizer; 后续若需可视加)
- [x] **D.4 — Validation 全套** (18 项 PASS) + 文档同步 + simplify pass

## Validation 全套 (18/18 PASS)

| 测试 | 结果 | 数字 vs Phase C 末态 |
|---|---|---|
| LGF 73/73 unit tests | 73/73 PASS | 一致 (`/tmp/m21_simp_lgf.txt`) |
| smoke_rts_auto_battle 4v4 main | PASS | ticks=347 attacks=74 (melee=32 ranged=42) deaths=6 melee_max_dist=24.00 ranged_max_dist=125.75 detoured=4 (bit-identical 0 漂移) |
| smoke_castle_war_minimal | PASS | ticks=193 left_win unit_to_building_attacks=4 archer_anti_air=1 spawn_count=2 (0 漂移; cost / starting 改了但行为质性不变) |
| smoke_player_command | PASS | ticks=30 log_entries=3 gold_remaining=20 wood_remaining=50 (Phase D 漂: 之前 100/0) |
| smoke_player_command_production | PASS | ticks=600 left_spawned=7 max_eastward=254.74 gold_remaining=20 (Phase D 漂: 之前 gold_remaining=100; left_spawned/max_eastward 0 漂移) |
| smoke_production | PASS | ticks=600 left_spawned=7 right_spawned=7 max_left_eastward=118.51 (0 漂移; 不放 building) |
| smoke_crystal_tower_win | PASS | ticks=2 left_win (0 漂移) |
| smoke_resource_nodes | PASS | ticks=200 alive_workers=5 max_drift=0.00 (0 漂移) |
| smoke_harvest_loop | PASS | ticks=600 alive_workers=5 team_gold=140 team_wood=212 cycle_workers=5 (0 漂移) |
| **smoke_economy_demo (Phase D 新)** | PASS | ticks=900 alive_workers=5 cycle_workers=5 barracks_enqueued_tick=348 melee_spawned=4 melee_to_ct_attacks=31 final_gold=138 final_wood=196 |
| smoke_replay_bit_identical | PASS | seed=42 commands=2 frames=9 events=20 deep-equal (0 漂移) |
| smoke_determinism | PASS | seed=12345 run1=run2=(left_win, 347) tick_diff=0 (0 漂移) |
| smoke_frontend_main | PASS | visualizers=10 (5 worker × 2) alive_after_3.0s=10 不崩 |

**结论**: Phase D 改动只让 4 个 fixture 数字漂 (cost / starting 直接相关), 其它 14 项数字与 Phase C 末态完全一致 (bit-identical 4v4 ticks=347 / replay frames=9 events=20 deep-equal / det tick_diff=0)。

## Simplify Pass (SKILL.md §7a-7c)

5 AC 全过后 simplify + AC-doc consistency review:

1. **smoke_economy_demo `_max_total_gold` / `_max_total_wood` tracking 删除** — 这两字段 + main loop 跟踪 + 验证段 4 (drop-off 计数 ≥ cost) 是冗余: `_barracks_enqueued = true` 这个 flag 本身已隐含 "resources 曾达到 cost" (enqueue 条件就是 ≥80g+50w), 验 enqueue 已隐含验 drop-off 计数。 删 2 var + main loop 5 行 tracking + 验证段 6 行; 验证条从 6 个简化到 5 个; report 行去掉 max_gold/max_wood 字段。
2. **AC-doc consistency review**: AC1-AC2 实现 file:line 与文档对齐 (rts_building_config.gd:104/130/85, 4 个 smoke fixture starting); AC3 setup 文档原写"2 gold + 2 wood node"已更新为"1+1 模式 (smoke_harvest_loop 同; 实测 2+2 同侧布局让 worker 全选 gold)"; AC3 starting 文档原写"100/100"已更新为"smoke 用 0/0 强制 harvest 路径; 与 demo 玩法 starting 不同"; AC3 验证断言"drop-off 计数对"删除 (隐含通过 _barracks_enqueued); AC4 加注"ResourceNode 无 visualizer; 后续若需可视加"。

re-validation (5 sanity smoke): smoke_economy_demo 0 漂移 (除冗余字段移除); LGF 73/73 + smoke_rts_auto_battle 4v4 + smoke_replay_bit_identical + smoke_harvest_loop 全 0 漂移 (`/tmp/m21_simp_*.txt`)。

---

## Phase D 收口 = M2.1 Economy 整体收口

Phase D 收口后:
1. 创建 `archive/<YYYY-MM-DD>-rts-m2-1-economy/` 归档全部 phase 进度 (按 SKILL.md §Done Criteria For This Skill)
2. 主 `Next-Steps.md` 切回"等待用户确认下一个 feature"
3. 主 `Current-State.md` 更新为 RTS M2.1 完成后的 baseline (worker / harvest / 经济闭环 已落地)
4. M2 路线图 (`m2-roadmap.md`) 中 M2.1 status 标 "✅ done"
5. 用户决定是否启动 M2.2 (AI 对手) 或 M2.3 (UI HUD)
