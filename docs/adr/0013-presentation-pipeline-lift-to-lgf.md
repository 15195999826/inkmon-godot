# 0013: 表演管线上提为 LGF `presentation/` 标配层（取代 adr/0006「暂弃共享」与 glossary 1.2「各自重写」）

[adr/0006](0006-battle-presentation-framework-port.md) 把 hex frontend 的表演框架**拷进** inkmon 改 2D，并明确「抽到共享层」暂弃：仅 2 个消费者，未到 rule-of-three，等第 3 个 2D 消费者再评估。[glossary](../glossary.md) 1.2 据此写了「表演层刻意不总结成框架复用，各项目各自重写」。2026-09-10 LGF 十刀锐评把「表演管线上提」列为刀 9、另开计划，前提是先对齐 hex 3D 与 inkmon 2D 两份分叉。

2026-09-24 用户 + fable 读真实代码对比两份分叉后拍板（过程与事实见 [`plan/lgf-presentation-lift-plan.md`](../plan/lgf-presentation-lift-plan.md) §0–§1）：

- 两份分叉去掉前缀后几乎逐字相同，唯一设计分歧是坐标出口（hex 核心持 `GridLayout` 出 `Vector3`；inkmon 核心只出逻辑 axial `Vector2`，像素转换在 view 边界）。
- 用户认可框架设计本身（事件 → 翻译员 → 卡片 → 账本 → 视图），问题在 AI 起的名字误导。
- 用户定位：**共享表演包是 LGF 标配层**——kards-tavern 用得上（框架改完由用户单独去接），未来所有基于 LGF 的项目表演层都可用。rule-of-three 不再是门槛。
- inkmon 冻结（task-queue 2e）不解除；2e 重设计留不留这条管线，启动时再定。

## Decision

1. **LGF 顶层新建 `presentation/`**，把 hex frontend 中与数据、2D/3D、网格无关的核心搬进去：`VisualDirector` / `ReplayDirector`、`Translator` + `TranslatorRegistry`、`VisualAction` + 内置卡片、`ActionStepper`、`VisualState` + `ActorVisualState` + `VisualStateQuery`、`VisualUpdater`、`AnimationConfig`。依赖方向 `presentation/ → core/`；不依赖 `stdlib/`、不依赖 ultra-grid-map。
2. **坐标约定 = inkmon 那套**：框架只讲逻辑平面 `Vector2`（含义由项目定），像素 / 3D 投影只在项目 view 层。这是「对齐两份分叉」的实质，本轮在 hex 侧落地。
3. **本轮范围 = 只抽 hex 半边**（用户选 B）。hex 成为第一个消费者；inkmon 现有拷贝一行不动，维持到 2e；kards 由用户在框架改完后自己接。
4. **命名规则**：框架件无前缀；项目件带项目前缀（hex `Frontend*`、inkmon `InkMon*`）。`RenderWorld` → `VisualState` + `VisualUpdater`，`Scheduler` → `ActionStepper`，`Visualizer` → `Translator`（`Interpreter` 亦否决：编程语境里是执行不是翻译）。
5. **扩展缝两处**：卡片种类 `kind: StringName` + Updater handler 表（项目可加私有卡片，不改框架）；一次性效果信号收成 `effect_spawned / effect_updated / effect_removed` 三条（项目私有效果种类不改框架信号）。

## Considered Options

- **A 暂不动，只登记，等 2e 一起做** — 弃。两份拷贝已在各自漂（inkmon 多 live 入口、hex 多 cone overlay），kards 已明确要用，等下去只会多一份分叉。
- **B 现在只抽 hex 半边** — **选**。hex 侧的坐标对齐无论如何都要做；不碰 inkmon 冻结；框架先成型，kards / 2e 各自按接入清单接。
- **C 两份一起对齐上提** — 弃。要给 inkmon 表演层解冻，2e 重设计可能推翻这部分工作。
- **目录放 `stdlib/`** — 弃。presentation 含 Node（Director）与 signal，与 stdlib 全 RefCounted 逻辑电池性质不同；它是三层架构的第三层，应物理落地为顶层目录。
- **卡片多态 `action.apply(state)` 替代 Updater handler 表** — 弃。卡片保持纯数据、记账规则集中一处，更贴「State / Updater / 卡片」的心智模型。

## Consequences

- **adr/0006 的「暂弃」选项被采纳**，其「拷进 inkmon」决策对 inkmon 现有代码继续有效（冻结期间不动），对新项目不再是范式。adr/0006 顶部加标注指向本 ADR。
- **glossary 1.2 改写**：example 铁律不变（主游戏绝不引用 `example/`），但主游戏与所有项目**可以**依赖 LGF `presentation/`；表演层不再「各自重写」，各项目只写事件源 + 翻译员 + 视图。
- **LGF 三层架构物理落地**：`core/` → `stdlib/` → `presentation/` → `example/`；LGF `CLAUDE.md` 分层图与铁律随执行期 PL4 更新。
- **hex 示例瘦身**：`frontend/` 只剩视图、翻译员、Animator / WorldView、私有卡片（cone debug overlay），成为「怎么消费 `presentation/`」的活范例；「新技能表演层接入清单」留在 hex README。
- **inkmon 2e 的选择空间**：若留管线，`InkMonRender2D*` 整目录删除、`InkMonBattle2DAnimator` / `InkMonOverworldLiveDriver` 改继承 `ReplayDirector` / `VisualDirector`；若不留，本 ADR 对 inkmon 无约束。
- **验收基线新增**：hex 表演 golden（卡片序列 + 逐帧账本快照指纹）成为表演层的长期钉子，与逻辑层 `hex/random-golden` 并列。
