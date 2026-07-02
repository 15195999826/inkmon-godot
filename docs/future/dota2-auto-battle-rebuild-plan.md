# dota2-auto-battle 重建方案（task-queue 1c）

> 2026-07-02 fable 起草。**待用户过目批准后才动代码。**
> 定调（task-queue）：从头重做非修补，基于项目目标（README 定位）。
> 现状：旧 M1 smoke 2/2 绿——「能跑但垃圾」，不是「坏了」。
> 关联：1b 提案 [`simnav-examples-disposition-proposal.md`](simnav-examples-disposition-proposal.md)
> （dota2 lab 是旧 M1 的移动底座，两案联动）。

## 一、诊断：旧 M1 为什么「垃圾」

1. **移动底座选型错误（主因）**。ARAM 单中路是一条**无静态障碍的开阔直线**
   （`dota2_movement_adapter.gd:36-38` 自注 "开阔中路，无静态障碍"），却背了整套 sim-nav
   dota2 lab 栈：JPS 长径 + vertex 短径 + hierarchical + 五态 FSM + ticket 队列 + path
   budget——**寻路在这张图上永远算出直线**，全部复杂度没换来任何东西；反而把 lab 的
   hard-block 契约原样继承进来（站定重试 N 次 → FAILED 站桩，1b 已定性「契约把差手感
   钉死」）。lane 4v4 接敌时全队追同一目标，自己人挡自己人正是该契约的最坏工况。
   真 Dota 小兵的手感是：直线走、贴着友军**滑动绕行**、接敌自然停——不需要寻路，需要
   的是 steering。
2. **M1 没有游戏目标**。无塔、无 core、无胜负判定、单波 spawn——两队对戳完就没事了，
   「玩起来不像个东西」。
3. **前端只有 debug 面板**。327 行 frontend 全是 debug 富面板 + 占位形状，没有最小
   战斗观感闭环（血条变化/攻击挥动/死亡反馈）。

> 诊断待用户确认/补充：「更垃圾」若另有所指（如某次实际运行的具体现象），以用户主诉为准。

## 二、保什么（定位与形状不变，重写时保形）

以下经 M1 验证是对的，重建照抄形状：

- **30Hz 单线程定长 tick** + 前端私有 clock + 有限 catch-up + warning 契约；
- **persistent intent 模型**：controller 决策（`DecisionResult`）→ `current_intent` →
  systems 每 tick 推进 → `IntentStepResult` 回报 → controller 拥有 lifecycle；
- **基础攻击从首版即 LGF Ability-backed**：`AttackTargetIntent` → adapter 停步 →
  `AbilitySet` → Timeline（attack point）→ `DamageAction` → 事件流；
- **AttributeSet family**（BattleActor 基类 hp/max_hp + Unit 派生五属性；先 max_hp 后 hp）；
- **logic/view 只读契约** + `Dota2LogicFrame` snapshot + 既有事件词汇
  （`unit_spawned` … `unit_died`）；
- **分层 core / logic / frontend / tests** 与依赖方向。
- **Movement Adapter 边界本身**（controller/ability 永不直接动移动内部）——恰恰因为这个
  边界存在，换底座才是局部手术。

## 三、扔什么

1. **sim-nav dota2 lab 栈依赖**（见决策点 1）。替换为 example 内专用 **lane steering
   移动**（估 ~150-250 行）：
   - 直线 seek 朝目标 + 到停止距离自然减速停步；
   - 单位间**半径分离 + 切向滑动**（重叠推开、被挡时沿切线绕行），无 FAILED 终态——
     小兵永远在动或在打，不站桩摆烂；
   - 确定性：固定迭代序 + 纯函数 steering，30Hz tick 输入决定一切；
   - `Dota2MovementAdapter` 对上接口不变（`ensure_march` / `ensure_chase` /
     `request_stop` / `advance` / 事实查询），底下从 lab 栈换成 steering。
   未来英雄走位/复杂地形真需要寻路时，在 M4' 决策点切回 sim-nav（届时 1b 的 lab 手感
   契约也已重做）。
2. **attributes route-3 共享生成器债**：重做时一步到位 example-local
   （`logic/attributes/` 自持 config + 生成输出），不再挂共享 `example/attributes/`。
3. **debug-only 前端**：重做为「最小战斗观感 + debug 面板」双层（观感层：形状单位 +
   血条 + 攻击/死亡反馈；debug 层保留 intent/movement/ability 状态展示）。

## 四、重建里程碑

- **M1' —— 完整可玩闭环**（一次交付一个「像游戏的东西」）：
  - 周期波次 spawn（两队各 N creep / 波，间隔可配）；
  - lane steering 移动（上文）；
  - aggro → chase → 基础攻击（LGF Ability 全链路，同旧 M1 形状）；
  - **胜负条件**：两端各一个 lane core（有 HP 的静态 actor，creep 走到攻击它），
    core 破 = 战斗结束 + `battle_ended` 事件（见决策点 2）；
  - 最小观感闭环 + debug 面板；
  - **护栏从 day 1**：确定性金样 smoke——借主游戏 `smoke_battle_golden` 模式
    （N tick 事件流基线快照 + 跨进程重放逐条一致），接续本 example 旧有
    determinism/replay 传统。
- **M2' —— targeting/攻击硬化**（≈原 M2）：latch / invalidation / no-jitter /
  cooldown-phase focused tests。
- **M3' —— 技能模型扩展**（≈原 M3）：DOT/HOT/aura/attack-modifier 不进 Procedure
  tick 分支；技能保持 GDScript 脚本形态（一技能一类，2026-07-02 已拍板不做数据驱动）。
- **M4' —— 移动底座升级决策点**（原 M4 改造）：出现英雄走位/静态障碍需求时评估切回
  sim-nav；adapter 接口不变即可换。
- **M5' —— 前端增强**（≈原 M5）。

规模预估：M1' 约 1500-2000 行（与旧 M1 相当，砍 lab 栈依赖换手感可控 + 胜负闭环）。

## 五、决策点（用户拍板后动工）

1. **移动底座**：
   - **A（推荐）**：example 内 lane steering（直线 seek + 分离滑动），无寻路依赖；
   - B：继续接 sim-nav dota2 lab，等 1b 把 lab 手感契约重做完再接——1c 被 1b 阻塞。
2. **M1' 是否含胜负条件（lane core）**：推荐含——这是「像个游戏」的最小要素；不含则
   回到旧 M1 的无限对戳。
3. **旧代码处置**：推荐**定义类复用、执行类全重写**——events / attributes 定义 /
   unit type config / intent DTO 词汇保留（形状已验证），procedure / controllers /
   movement adapter 内部 / systems / frontend 全部重写。备选：全删从零。

## 六、约束自查

- 守 enforcing-lgf / gdscript-coding；Systems/Abilities/Actions 是唯一状态变更权威；
  controller 不直改 position/HP/cooldown。
- 技能不做数据驱动（脚本形态是终态）。
- 不过度设计：M1' 不建 command 层 / PlayerController / 行为树 / EventBus；steering
  不做 RVO/ORCA/编队（那是 sc2 lab 划掉的范围）。
- submodule 纪律：改动在 `addons/logic-game-framework` 内单独 commit，主仓 bump。
