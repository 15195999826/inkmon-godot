# 进化关系 = 解耦的 edge-list 森林 + species_id 全局唯一身份；trigger 数据住 canon、评估住 godot

早期 InkMon 把进化关系**内嵌**在物种记录里：`evolution.evolves_from`（裸 `name_en`）+ `evolves_to`（裸 `name_en[]`）。问题：① 物种记录上同时存 from + to，双向裸引用易 desync；② lab 侧无任何遍历 / 校验代码（`queries.ts` 只按 `evolution_stage` 过滤），真正的进化链行为只在 godot；③ 用 `name_en` 当关系键，设计期改名即断链。

需求驱动（用户）：图鉴要展示整条进化线；canon 要当进化**触发条件**的权威源；生成会话要"链感知"（知道在做新物种 / 某物种的进化 / 预进化形态）。结构上进化关系是**树**（一个低阶可分支进化到多个高阶），全体物种是**森林**。

## 决定

- **结构 = 进化森林**：树（单亲多子，恰一个直接前体、零或多后继），非线性链。游戏内进化**只正向**、不可逆；"退化形态"仅指**制作顺序**（先做高阶后补低阶的预进化补齐），不是游戏机制。
- **拓扑解耦成独立 edge-list 边表**（`evolution_edges`）：每行 `(parent_species_id, child_species_id, trigger)`。整个森林 = 一张边表；一棵树 = 连通分量（身份 = 根 species_id）；孤儿 = 无边的物种。**无独立 tree / chain 实体**。物种记录不再内嵌拓扑——`InkMonSchema` **移除** `evolves_from` / `evolves_to`；物种按 `species_id` 查询自己的进化 / 退化关系。边表是拓扑的**唯一真相源**（两个方向都是对它的查询）。
- **`species_id` = 全局唯一不可变身份**：格式 `mon_NNNN`，由权威写入方 server 在 `POST` 时 `MAX+1` 原子发号、**不可变、删除不复用**（留号段空隙，防边引用误指到别的物种）。它**替代 `name_en` 作一切寻址 + 关系 key**：JSON 文件名、图目录、godot unit id、`inkmonasset://` 协议、边表节点。`name_en` 降级为可改的**显示名**，`dex_number` 降级为可变的**图鉴展示序**，二者均不作 key。
- **trigger 挂在边上** = `{ level, condition? }`。`level` **必填** = 进化等级**阈值**（设计数据），**住 canon**——见下文「修订 0007」。`condition` **可选** = 分支区分器，**开放结构** `{ type, params }`：`type` 为自由 string（canon **不** enum 校验，故"加条件不改 schema"），已知集 `item / stat / element` 仅由 contract 文档约定。**canon 只做结构校验**（`type` 非空、`params` 是 object），**condition 语义评估在 godot**（按 `type` 分派）——沿用 adr/0009「逻辑住 godot、元数据住 canon」。
- **生成链感知**：生成会话三态 —— `new`（新物种 = 新树根 / 孤儿）/ `evolve-from(X)`（造 X 的下一阶段，把 X 全量数据喂 AI 作连贯参考、会话内设这条边 trigger）/ `pre-evolve-of(Y)`（造 Y 的低阶前体）。`POST /inkmon` 可选携带 edge，server 分配新 `species_id` 并**原子写 species + edge**；新树 = 一节节顺序 promote，每次引用已存在亲属（新节点 id 在 promote 前不需要）。
- **校验分层**：结构不变量（**单亲 / 无环 / 阶段单调 `parent.stage < child.stage`（允许跳阶 baby→adult，拒逆序 / 同阶）/ 引用存在**）由 `@inkmon/canon` 提供校验函数、**server 在 POST 增量硬拒**（违反则 HTTP 4xx，species + edge 都不写），lab 生成期用同函数预检（UX）。分支 `condition` 互斥 / 确定性 canon **管不了**（语义盲）→ 归 godot / 生成期软警告。

## 修订 adr/0007（level 阈值归属）

0007 / `godot-contract.ts` 把「进化 **level 阈值**由 godot 持有」。本 ADR 修订该点：进化阈值是**设计数据**，移入 canon 边表的 `trigger.level`，随 inkmon `lab→server→godot` 投影。**注意区分**：被搬走的是"在第几级触发进化"这个设计阈值；单位的**运行时 current level**（成长状态）仍归 godot，不动。其余 0007（canon 唯一 schema 源、server 投影、godot editor tool 拉取）不变。

## 为何这样

- **解耦 + 唯一真相源**：物种记录只存"自己是什么"，关系单独一份、无双向 desync；图鉴取线 / 生成接枝 / 校验都有清晰边界。
- **全局 species_id**：创作工具设计期高频改名；稳定 id 让改名只动显示名，文件 / asset / godot / 边全不断。
- **trigger 住 canon、评估住 godot**：兑现"canon 当进化设计权威"（驱动 2），与"lab = 设计源"一致；语义评估留 godot 沿用技能的"逻辑住 godot"，开放 `{type,params}` 让加条件不改 schema。

## 为何不

- **不保留内嵌 `evolves_from/to`**：双向 desync、无链实体、改名断链。
- **不用 `name_en` 当 key**：改名即断一切引用。
- **不开 tree-record / 独立 chain 表**：对 2-3 节的树过度设计；写放大、并发易冲、查单节点要解结构；树身份用根 species_id 足矣。
- **不把 trigger 留 godot**：违驱动 2；canon 拿不到进化设计权威，"数值平衡"这类设计数据散落 godot。

## 后果

- **`@inkmon/canon`**：`InkMonSchema` 去 `evolves_from/to` + 加 `species_id`；新 evolution-edge schema + `evolution_edges` 表（经 `@inkmon/canon/table` 单一源，见 adr/0007）+ `validateEvolutionEdge` / forest 校验；`godot-contract` 改投**边表**而非 per-unit `evolves_to`、unit id = `species_id`、display_name = `name_en`。
- **server**：`POST /inkmon` 接 edge + `species_id` 发号（`MAX+1`）+ species/edge 原子写 + 增量校验；`inkmons/<species_id>.json`、`images/inkmon/<species_id>/`。
- **asset 协议**：`inkmonasset://inkmon/<species_id>/...`。
- **recipe**：session 加 chain-mode（`new/evolve-from/pre-evolve-of`）+ 参考喂入 + 边 trigger 编辑。
- **bridge/preload/ipc**：chain-mode + edge 跨进程契约。
- **前端**：图鉴按 `species_id` 寻址、进化树展示（按边表渲染）、生成会话链模式 UI。
- **godot importer**：unit id ← `species_id`、display_name ← `name_en`；消费边表 + `trigger.level`；`condition` 按 `type` 评估；移除"阈值由 godot 持有"的注释 / stub。
- **破坏性**：schema break + 全量 re-key → 一次性**清库重建**（dev 无向后兼容，见 root CLAUDE.md「schema 破坏性变更」流程）。
- **前置依赖**：`condition {type:item}` 的引用完整性**依赖 item 先迁 server 同步**（CLAUDE.md 已知遗留 #1）才能真正校验；在此之前该引用悬空。
- 完整术语与解析规则细节见 `docs/plan/current/L2/CONTEXT.md`「进化树」「species_id」「进化 trigger」诸条。
