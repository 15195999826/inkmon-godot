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
  1. ✅ **已完成（2026-07-02）** 修 core C1/C2（+1 raster extension + impassable 逃逸），四组
     smoke 50/50 全绿；default 走廊 42→74px（有效通道与旧世界一致）。**执行中发现并记录**：
     ① lab 栅格 cell 8 实验回滚——logged-* 回放锚全是 16px 时代 export，重锚成本归入本步
     契约重做（届时与 5Hz 一并做，量化误差减半值得要）；② `static_vertex_extra_outset`
     在 +1 带下不再清带（顶点可能落带内，靠逃逸规则出、进边可能被拒），同批重配平；
     ③ dota2 lab 已切 cell 8 + outset 配平（它无历史锚包袱）。
  2. sim/render 节拍分离（core-021 medium：5Hz 固定 tick accumulator + 渲染插值，issue 里已
     有 sketch）——预期顺带简化/删除若干 lab-only 手感补丁（issue 内有逐条评估表）；同批：
     cell 16→8 重锚 + outset 重配平 + logged-* 锚全面重放。
  3. 对用户具体主诉复测（绕大弯 / 到达后互挤 / 卡墙僵死），剩余问题再定点修——「到达后互
     挤」的候选根：unit-unit −½ clearance 放宽缺失（1a Q2）+ 无 formation slot。

### dota2-rts-pathfinding-lab —— 骨架保留、手感契约重做 ✅ 已完成（2026-07-02）

- **movement-feel-policy v2 已落地**（submodule e8f0c68）：M1 切向滑动（对实时单位位置 +
  精确 static 几何校验，绕过栅格 DDA 抢走的窄缝侧移空间，滑进栅格带靠 core 逃逸规则走出）、
  M2 unit-unit −½ cell clearance 放宽（0ad 同款）、M3 拥挤到达（预算耗尽后二环半径，群移
  同点收敛成同心圆环）、M4 HOLDING 态（永不因单位阻挡终态放弃，`max_retry_exceeded` 已消灭；
  FAILED 仅剩静态不可达）。
- **实测行为翻转**：群移 8 单位 IDLE 8/FAILED 0（旧 3/5）；窄缝对穿 222 tick 双双滑过到达
  （旧双 FAILED）；围死单位 HOLDING 有界重试、移开阻挡自行恢复（新 A9 锚）。
  dota2lab/smoke 6/6，全量 50 场景绿。
- **待用户 F6 亲手验**：`frontend/dota2_pathfinding_lab.tscn`（手感最终验收人是用户）。

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

## 用户拍板（2026-07-02）

1. **sc2 lab：删掉** ✅（已执行）
2. **dota2 lab：保骨架重做手感契约** ✅
3. **1c 移动底座：继续 sim-nav lab 栈** —— 由此 **1b 的 dota2 lab 契约重做成为 1c 的前置**；
   执行顺序：core P0 修复 → dota2 lab 手感契约重做 → 1c 重建。
4. **core P0（C1/C2）：现在就修** ✅

## 用户手感主诉（验收锚，修复对准这些）

**0ad lab**：绕明显大弯 + 到达后堆叠互挤不停 + 单位卡墙/僵死；且历史上「让 AI 反复修、
问题反复出现，特别是边界情况」——用户心智：底层思路有问题。
**1a 的解释**：底层架构站得住，但 0ad 靠它保边界正确性的两个保守机制没带过来（C1
clearance 扩展 / C2 逃逸规则），历次修复都在上层 motion/example 打补丁——修错了层，
边界 case 自然反复复发。本轮从 core 根上修。

**dota2 lab**：无具体单点主诉，总目标就是「还原 dota2 手感」且当年没做到。新手感契约
要从 dota2 真实机制正向定义（移动单位间滑动绕行、停驻单位是实体障碍、转身速率、指令
即响应），而不是从现有 lab 缺陷倒推。
