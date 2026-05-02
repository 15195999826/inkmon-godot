# Task Plan — RTS Auto-Battle M1 架构重构

> **Feature 总目标**：把 RTS M0（功能 spike）演进为遵守 LGF 根原则的、支持城堡战争玩法的、可流式 simulation + 决定性 replay 的工业级架构。
>
> **三 phase 串联**：Foundation（修根偏离 + 基础设施）→ Core Systems（玩法支柱）→ Advanced（高级特性）。
>
> **执行模式**：一次只开发一个 phase。当前 phase 收口后才进下一 phase。

---

## 文档索引

| 文档 | 角色 | 状态 |
|---|---|---|
| [`architecture-baseline.md`](architecture-baseline.md) | 锁定决策 + 总图（13 条决策 + 模块拓扑 + 基类骨架）| **稳定 spec**，跨 phase 不变 |
| [`phase-1-foundation.md`](phase-1-foundation.md) | Phase 1 详细子任务 P1.1–P1.7 | ✅ **已完成 9/9 AC**（2026-05-01） |
| [`phase-2-core-systems.md`](phase-2-core-systems.md) | Phase 2 详细子任务 P2.1–P2.8 | ✅ **已完成 10/10 AC**（2026-05-02）|
| [`phase-3-advanced.md`](phase-3-advanced.md) | Phase 3 详细子任务 P3.1–P3.4（可选项）| 🚧 **active — 本轮选 P3.2 + P3.3 + 寻路 demo**（2026-05-02 用户授权）|

> `architecture-baseline.md` 是稳定 spec，所有 phase 文档引用它而不重复决策。
> 各 phase 文档自给自足，autonomous-feature-runner 一次只读当前 phase 的文档。

---

## Phase 总览

### Phase 1 — Foundation（M1 启动前不可妥协）

修复 RTS M0 架构审查发现的**对 LGF 根原则的硬偏离**（S1/S2/S3/M4），铺好基础设施（fixed-tick + grid wrapper + actor 三层基类）。

**核心承诺**：Phase 1 完成后，RTS 4v4 仍能跑到 winner，且代码骨架支持 Phase 2 平滑加入 Activity / Steering / Production / Player Command。

7 个子任务：
- P1.1 Actor 三层基类 / P1.2 Grid wrapper / P1.3 Procedure 内化（S1）
- P1.4 Action 标准化（S2）/ P1.5 AI 拆分（S3）/ P1.6 Cooldown tag-duration（M4）
- P1.7 Fixed-tick + RtsRng + light determinism

**Acceptance**：9 条（详见 [phase-1-foundation.md §收口条件](phase-1-foundation.md)）

---

### Phase 2 — Core Systems（M1 期间核心玩法）

在 Phase 1 修好的骨架上，搭建**城堡战争核心玩法支柱**（含飞行单位）。

**核心承诺**：Phase 2 完成后，城堡战争最小可玩 demo 跑通 — 玩家放置兵营 → 兵营周期 spawn 单位 → 单位走 grid / 互避障 / 找最近敌人 / 攻击建筑 → 飞行 vs 防空对位 → 水晶塔被毁判胜负。

8 个子任务：
- P2.1 Activity 系统（OpenRA 风）
- P2.2 Spatial Hash + Steering（避障 1+2 层）
- P2.3 Stuck Detection + Local Repath（避障第 3 层）
- P2.4 AutoTargetSystem（Mindustry + OpenRA 合璧）
- P2.5 Production System + Building Factory
- P2.6 Player Command + Building Placement + 胜负判定改写
- P2.7 Frontend BattleDirector 接入流式 events
- **P2.8 AIR Layer + target_layer_mask + 飞行单位**（前移自原 P3.2，城堡战争一等公民）

**Acceptance**：10 条（详见 [phase-2-core-systems.md §收口条件](phase-2-core-systems.md)），含 bit-identical replay determinism + 飞行 vs 防空验证

---

### Phase 3 — Advanced（M2+ 高级特性，可选）

在 Phase 2 已完成的"功能可玩"城堡战争上加**高级 RTS 特性**：高低地形 / 群体队形 / 声明式 scenario / fog of war。

**核心承诺**：Phase 3 各子任务**独立可选**；用户可按项目需要选做哪些。

4 个子任务（独立可选）：
- P3.1 离散 tile.height + LOS（D3-E）
- P3.2 Group Formation（避障第 4 层）
- P3.3 RtsScenarioHarness（声明式测试）
- P3.4 Fog of War / Vision System

**Acceptance**：用户认可的子任务集各自 PASS（不强制全做）

> 飞行单位已前移到 Phase 2 P2.8，不在 Phase 3 范围内。

---

## 全局收口条件

整个 RTS M1 架构重构 feature 完成 = **Phase 3 全过 OR 用户决定不做完 Phase 3 的剩余子任务**。

完成时执行：
1. 创建 `archive/<YYYY-MM-DD>-rts-m1-refactor/` 归档全部 phase 进度
2. 主 `Next-Steps.md` 切回"等待用户确认下一个 feature"
3. 主 `Current-State.md` 更新为 RTS M1 重构后的 baseline

---

## Phase 间过渡协议

### Phase 1 → Phase 2
- Phase 1 acceptance 全过 → **不归档**（同一 feature 的早期 phase）
- 更新 `Next-Steps.md` 当前目标 → Phase 2
- 更新 `Progress.md` 切到 Phase 2 子任务清单
- `task-plan/phase-2-core-systems.md` 已就位（无需重新规划）
- 用户在新会话调 `/autonomous-feature-runner` 即可继续

### Phase 2 → Phase 3
- Phase 2 acceptance 全过 → 仍**不归档**
- 用户**明确决定**是否启动 Phase 3（不像 Phase 1→2 自动衔接）
- 若启动：更新 `Next-Steps.md / Progress.md` 切到 Phase 3
- 若不启动：直接进归档流程（见下）

### Phase 3 完成 / 用户决定收尾
- 创建 archive，主 docs 切回等待状态

---

## 实现纪律（贯穿三 phase）

来自 `Autonomous-Work-Protocol.md`，Phase 期间不变：

1. **不修改 LGF submodule core / stdlib**
2. **测试入口规范**：`.tscn` 入口 + `> /tmp/*.txt 2>&1` redirect，不用 `--script` 不用 pipe
3. **触发 stop 条件**：需要修改 `project.godot` autoload / `scripts/SimulationManager.gd` / LGF submodule 时要先确认
4. **每 phase 完成 re-run validation 顺序**：import → LGF 73/73 → RTS smoke → hex demo
5. **决策来自 architecture-baseline.md**：实现时如发现需要改决策，**先停下来跟用户对齐**再改 baseline
