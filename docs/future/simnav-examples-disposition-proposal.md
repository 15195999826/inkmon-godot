# sim-nav-map examples 处置方向提案（task-queue 1b）

> 2026-07-02 fable 起草。**待用户拍板，动手前不执行任何删除/重写。**
> 决策底座：1a review（`addons/sim-nav-map/docs/reviews/2026-07-02-core-vs-0ad-review.md`）+
> 三 lab 文档全读（development-plan / movement-feel-policy / layer-2-ai-control-plan /
> 0ad-unit-motion-policy-parity-audit / sc2 README）。

## 核心判断：手感差 ≠ example 代码烂

三个具体根源，一半在 example 之下：

1. **core 两个确认缺陷直接造成「单位卡墙/僵死」**（1a C1/C2）：长程栅格缺
   `CLEARANCE_EXTENSION_RADIUS`（repro_005 HEAD FAIL、被排除出 smoke 组）；单位被 push 进
   clearance 环后缺「impassable→passable 允许离开」逃逸规则（CORE-020 僵死链路）。
2. **0ad lab 节拍错位**（core-021，open）：60Hz 跑 0ad 按 5Hz 设计的逻辑，push/重试/repath 以
   12× 设计频率发火；asymmetric-push、chaser 抖动等一堆「手感补丁」都在补这个架构错位。
   0ad 本尊 = 5Hz 模拟 + 渲染插值。
3. **dota2 lab 契约把差手感钉死**：纯 hard-block + 站定重试 + FAILED 接受为 baseline（群移
   8 单位 5 FAILED 站桩，文档自认 "poor-feel outcomes"）。0ad 原版短径对 unit-unit 有 **−½ 格
   clearance 放宽**（"makes movement smoother"，1a 存疑差异 Q2），本实现未带过来，密集群通过
   性天然紧一档。

## 提案

### 0ad-rts-pathfinding-lab —— 保留 + 定向修（不删不重做）

- 理由：core 的主要回归资产（40 motion smoke + repro_020 + stress harness + 密集 repro 护栏
  网）；1a 结论 core 是要保住的，example 测试是资产的一部分。
- 顺序：
  1. 修 core C1/C2（1a P0，两条都有 repro 实证）；
  2. sim/render 节拍分离（core-021 medium：5Hz 固定 tick accumulator + 渲染插值，issue 里已
     有 sketch）——预期顺带简化/删除若干 lab-only 手感补丁（issue 内有逐条评估表）；
  3. 对用户具体主诉复测，剩余问题再定点修。

### dota2-rts-pathfinding-lab —— 骨架保留、手感契约重做（推荐），与 1c 联动

- 现状：工程质量好（五态 FSM、controller-owned ticket 生命周期、6 smoke 全绿、文档纪律好），
  **问题在契约不在实现**——movement-feel-policy 把「群移大半 FAILED / 窄缝互堵放弃」接受成
  baseline。
- 它是 1c dota2-auto-battle 的移动底座（lab Layer 2 = MOBA auto-battle 的直接前身），MOBA 需
  要什么手感应由 1c 倒推。
- 推荐方向：保 FSM/ticket/smoke 骨架，重写 movement-feel-policy——放宽纯 hard-block，加
  Dota2 式滑动绕行/让位；unit-unit −½ clearance 放宽（core 或 adapter 层落点待定）。
- 备选：冻结等 1c 方案定型倒推；或删了按 1c 需求重建（骨架一起推倒）。

### sc2-rts-pathfinding-lab —— 建议整个删除

- 纯 README 占位（0 行代码）；README 自己写明其 Layer 2 对 MOBA 目标「可能整个砍掉」；
  MOBA auto-battle 每单位独立 AI 下移动指令，不需要群体编队/cluster pathfinding。
- git 历史可考，未来真做 RTS 玩法再捡。
- **删除是破坏性操作，等用户确认后执行。**

## 待用户回答（已用 AskUserQuestion 发出，用户暂离，回来补答）

1. 0ad lab 手感主诉具体现象（卡墙僵死 / 一卡一卡 / 到达后互挤 / 绕大弯 / 其他）
2. dota2 lab 手感主诉具体现象（群移 FAILED 站桩 / 窄缝互堵 / 转身起步僵硬 / 轨迹僵硬 / 其他）
3. sc2 lab：删 or 留
4. dota2 lab：保骨架重做契约 / 冻结等 1c / 删了重建
