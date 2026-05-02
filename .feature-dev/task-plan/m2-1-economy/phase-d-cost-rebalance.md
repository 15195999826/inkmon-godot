# M2.1 — Phase D — Cost Rebalance + smoke_economy_demo (DRAFT)

> **Status**: 🔒 pending (2026-05-02 Phase C 收口时落 skeleton, 等待用户启动 Phase D 时 finalize 数值与 smoke 设计)
>
> **Phase D 是 RTS M2.1 Economy 的最后一个 phase, 经济闭环对外可观**: 给 archer_tower / barracks 重定 multi-resource cost (Phase A 占位 cost 改为有差异化的双资源 trade-off) + 新 smoke_economy_demo (full cycle: worker harvest → 资源到达 cost → enqueue PlaceBuildingCommand → 自动放下个建筑) + 编辑器 F6 视觉验证 demo_rts_frontend worker spawn 视觉链路。

---

## Acceptance (待用户启动 Phase D 时 finalize)

- [ ] **AC1** Building cost 重平衡 — multi-resource trade-off
  - 例草案 (用户启动时调): barracks `{"gold": 80, "wood": 50}`; archer_tower `{"gold": 60, "wood": 100}`; crystal_tower `{}` (起手就有)
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_building_config.gd`
  - 数值原则: gold-rich 偏 barracks (近战推 ct); wood-rich 偏 archer_tower (远程防空); 两资源都需要才能两者皆造
- [ ] **AC2** starting_resources 调值
  - 例草案: `{"gold": 100, "wood": 100}` 或 `{"gold": 150, "wood": 80}` 让起手能造一种但不能造两种, 必须 worker harvest 补
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_team_config.gd` 或 smoke setup
- [ ] **AC3** 新 `smoke_economy_demo.{gd,tscn}` PASS
  - Setup: 双方各 5 worker + 2 gold node + 2 wood node + ct + 起手 starting (按 AC2 调好的不够直接造 barracks)
  - Tick N: worker harvest → 资源到达 cost → 玩家 enqueue PlaceBuildingCommand barracks
  - Tick M: barracks spawn melee → melee 攻 ct
  - 验证: cycle 完整, worker 不卡, drop-off 计数对, building 放置成功
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_economy_demo.{gd,tscn}` (新)
- [ ] **AC4** demo_rts_frontend 起手 spawn worker + node — 编辑器 F6 视觉验证经济闭环
  - 文件: `addons/logic-game-framework/example/rts-auto-battle/frontend/demo_rts_frontend.gd` (改起手 spawn 列表)
  - 用户在编辑器 F6 跑 demo_rts_frontend.tscn 观察 worker harvest + 资源 bar 增长 + 攒到 cost 后能放兵营
  - HUD Label 已 "Gold: X | Wood: Y" (Phase A 完成), Phase D 不动
- [ ] **AC5** Validation 全套不退化 (LGF 73/73 + 12 既有 RTS smoke + smoke_harvest_loop + smoke_economy_demo + 2 replay smoke + frontend smoke)
  - Phase D cost 数字改可能影响:
    - smoke_player_command (硬码 cost 检验) — 若改了可能需要适配
    - smoke_player_command_production (gold_remaining 数字断言) — 同上
    - smoke_castle_war_minimal — 若 starting 改, 数字漂移
  - 改 fixture 顺手 + 文档同步, 与 Phase A 末态 fixture 适配同模式

---

## 设计决策 (待用户启动 Phase D 时确认)

### D17 — Cost 数值具体配方

**待定** — 等用户启动 Phase D 时给:
- barracks: `{"gold": ?, "wood": ?}`
- archer_tower: `{"gold": ?, "wood": ?}`
- starting_resources: `{"gold": ?, "wood": ?}`

**原则**:
- 让两资源都对玩家"有用"(否则 wood 就是死字段)
- 让起手不够直接造 barracks (强制 worker harvest 补)
- 让 trade-off 有意义 (gold-only 玩家造 barracks; wood-only 玩家偏 archer_tower)

### D18 — smoke_economy_demo 时长 + 阈值

**待定** — 取决于 cycle 数:
- worker 5 个 cycle 后能凑 cost (Phase C 实测 cycle ≈ 3s, 5 cycle = 15s)
- smoke 跑 N tick (>= 600 但可能要 900 让 barracks 实际 spawn melee + 攻 ct)
- 验证 building 放置成功 + 至少 1 melee spawn + ≥ 1 次 melee 打 ct

### D19 — demo_rts_frontend Phase D 起手 spawn 列表

**待定** — 默认草案:
- 双方各 spawn 5 worker + 1 ct + 2 gold node + 2 wood node
- 玩家用鼠标点击放 barracks (现有 Click left mouse 玩家命令链路)
- 用户在 F6 看到: worker → harvest → cycle → 资源 bar 涨 → 鼠标点击放 barracks → barracks spawn melee → melee 攻击对面

---

## 子任务 (待用户启动 Phase D 时按需调整顺序)

### D.1 — Cost 数值改 + smoke fixture 适配
- `rts_building_config.gd` 改 cost 数值
- `rts_team_config.gd` (或 smoke setup) 改 starting_resources
- 既有 fixture (smoke_player_command / smoke_player_command_production) 数字断言适配

### D.2 — `smoke_economy_demo.{gd,tscn}` 新文件
- Setup 双方 5 worker + 2 gold + 2 wood + ct + 起手 starting
- 跑 N tick, 玩家 enqueue PlaceBuildingCommand barracks
- 验证 cycle + building 放置 + melee spawn + 攻 ct

### D.3 — `demo_rts_frontend.gd` 起手 spawn 改 + F6 视觉验证
- 起手 spawn 列表加 worker + ResourceNode
- 用户编辑器 F6 验证经济闭环视觉链路
- HUD 不动 (Phase A 完成)

### D.4 — Validation 全套 + 文档同步
- 跑 LGF 73/73 + 13 RTS smoke (含新 smoke_economy_demo) + 2 replay + frontend
- 数字与 Phase C 末态对齐 (除有意改的 cost 数值)

---

## Phase D 收口 = M2.1 Economy 整体收口

Phase D 收口后:
1. 创建 `archive/<YYYY-MM-DD>-rts-m2-1-economy/` 归档全部 phase 进度 (按 SKILL.md §Done Criteria For This Skill)
2. 主 `Next-Steps.md` 切回"等待用户确认下一个 feature"
3. 主 `Current-State.md` 更新为 RTS M2.1 完成后的 baseline (worker / harvest / 经济闭环 已落地)
4. M2 路线图 (`m2-roadmap.md`) 中 M2.1 status 标 "✅ done"
5. 用户决定是否启动 M2.2 (AI 对手) 或 M2.3 (UI HUD)
