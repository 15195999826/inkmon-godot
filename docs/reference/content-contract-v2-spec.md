# 冻结接口 · Content Contract Bundle v2（lab ↔ server ↔ godot）

> **唯一接口源**。lab `@inkmon/canon/godot-contract.ts`（生产端）与 godot `ink_mon_l2_content_contract.gd`（消费/校验端）**都照本文写**。两边并行开发时以此为准，改本文 = 改接口、需双方同步。
> 依据 `adr/0010` + `CONTEXT.md`。相对现行 `inkmon.l2.content.v1` 的 **delta**：身份切 `species_id`、拓扑改根级 `evolution_edges`、阈值进 trigger。
> 性质：**v2 = 破坏性变更**，dev 无向后兼容，旧 v1 形状直接弃用、清库 + 清 `res://data/inkmon_content.json` 重建。
> **位置 / 归属**：本文件是 godot 仓的**消费端镜像**（住 `docs/reference/`，非 `docs/plan/` —— 它是冻结接口规范，不是开发计划）；**权威维护源在 lab 仓**，本仓副本仅供 godot 侧对照实现，改动须双仓同步。

## 0. Envelope（顶层）

```jsonc
{
  "schema": "inkmon.l2.content.v2",   // ← 从 v1 bump，标 break
  "version": 2,
  "source": "lab-canon-projection",   // lab 投影标记（godot stub 自建用别的值）
  "status": "ok",                      // 既有字段，保留
  "units": [ /* §1 */ ],
  "evolution_edges": [ /* §2 */ ],     // ← 新增根级数组（非 per-unit）
  "skill_pools": [],
  "skills": [ /* metadata-only, from godot→server; no .gd source */ ],
  "items": []
}
```

- 本 spec 只冻结 **`units`（creature 基底）** 与 **`evolution_edges`**。`skills` 只允许 metadata（`id` / `implementation_key` / `display_name` / `element` / `channel` / `icon_key?`），来源是 Godot editor tool `godot→server` 上传；server/contract 绝不承载 `.gd` 源码（另见 adr/0009）。`skill_pools` / `items` 不在本次改动面。

## 1. `units[]` — creature 基底

每个 unit：

| 字段 | 类型 | 必填 | 约束 / 说明 |
|---|---|---|---|
| `id` | string | ✓ | **= `species_id`**，格式 `^mon_\d+$`（如 `mon_0001`，零填充≥4）。**全局唯一身份键**。 |
| `display_name` | string | ✓ | **= `name_en`**（可改显示名，非 key）。非空。 |
| `stage` | string | ✓ | 枚举 `baby` \| `mature` \| `adult`。 |
| `elements` | string[] | ✓ | 1–2 个，取自 6 元素 `fire/water/wind/earth/light/dark`（godot 按 `InkMonElementChart` 校验）。 |
| `base_stats` | object | ✓ | 六维：`{ max_hp, ad, ap, armor, mr, speed }`（`hp`→`max_hp`）。`max_hp`/`speed` > 0，其余 ≥ 0。lab 侧 1–255 整数，godot 收 int↔float 阻抗。 |

**相对 v1 的变化**：
- ❌ **删 `species` 字段**（v1 里 godot 拿它当身份键）。身份统一走 `id`。
- ❌ **删 per-unit `evolves_to`**（拓扑搬到 §2）。
- ⚠️ **godot 现读 `unit.species` 当 key 必须改读 `unit.id`**（见两计划「关键纠偏」）。

## 2. `evolution_edges[]` — 进化森林（边表）

每条边 = 一条父→子有向边：

```jsonc
{
  "parent_species_id": "mon_0001",   // string, ^mon_\d+$, 必须是某 unit.id
  "child_species_id":  "mon_0007",   // string, ^mon_\d+$, 必须是某 unit.id
  "trigger": {
    "level": 16,                      // int, 必填, > 0 —— 进化等级阈值（设计数据，住 canon）
    "condition": {                    // object, 可选 —— 分支区分器
      "type": "item",                 // string, 非空
      "params": { "item_id": "firestone" }  // object
    }
  }
}
```

- 整个 `evolution_edges` = **一片森林**：N 棵树 = N 个连通分量，一棵树身份 = 根 `species_id`；**孤儿** = 不出现在任何边里的 unit。
- **分支** = 同一 `parent_species_id` 出现多行；**预进化补齐** = 新增一行（child 指向已存在的高阶）。
- `trigger.level` 必填；`trigger.condition` 可选（无 = 仅 level 门槛）。

### 2.1 `condition` —— 结构冻结 + v1 词汇约定

**结构（两边硬约定，canon 仅此层校验）**：`condition = { type: string(非空), params: object }`。

**语义所有权**：**godot 按 `type` 分派评估**（沿用 adr/0009「逻辑住 godot」）；**canon/contract 不校验 type 枚举、不抠 params 语义**。`type` 是**自由 string**——加新条件类型**不改 schema**。

**v1 已知 type + params 约定**（共享词汇表，便于 lab 生成端产出 godot 能认的值；godot 认这些、遇未知 type 视为「永不满足」fail-safe）：

| `type` | `params` 形状 | godot 评估语义 | 状态 |
|---|---|---|---|
| `item` | `{ item_id: string }` | entry 当前是否持有该 item | ⛔ **BLOCKED**：item 域未迁 server，godot 先 stub（返回 false / 软警告），勿假进化 |
| `stat` | `{ stat: "hp"\|"ad"\|"ap"\|"armor"\|"mr"\|"speed", cmp: ">="\|">"\|"<="\|"<"\|"=="\|"!=", value: number }` | 比较 entry 某属性与常量（stat-vs-stat 形态留后） | 可做 |
| `element` | `{ primary: <element> }` | entry 主元素是否匹配 | 可做 |

> 加 type 只需：godot 加一个分派分支 + lab 生成 UI 加一种产出；**本 spec 的 §2.1 表追加一行即可，不动 envelope/schema 版本**。

## 3. 校验责任分工（防漂）

| 不变量 | lab canon `validateEvolutionEdge` | server POST（权威·硬拒 4xx） | godot contract 校验（防御性） |
|---|---|---|---|
| `id` / `parent` / `child` 为 `^mon_\d+$` | ✓ | ✓ | ✓ |
| 引用存在（边两端是真 unit.id） | ✓ | ✓（对全库增量） | ✓（对 bundle 内 units） |
| **单亲**（child 在边表中 ≤1 个父） | ✓ | ✓ | 可选 |
| **无环** | ✓ | ✓（增量上溯） | 可选 |
| **阶段单调** `stage(parent) < stage(child)`（允许跳阶、拒逆序/同阶） | ✓ | ✓ | 可选 |
| `trigger.level` 必填正整数 | ✓ | ✓ | ✓ |
| `condition` 结构 `{type 非空, params object}` | ✓（仅结构） | ✓（仅结构） | ✓（仅结构） |
| `condition` 语义 / 分支互斥确定性 | ✗（语义盲） | ✗ | **godot 负责**（评估 + 同 level 多枝软警告） |

- **权威 = server POST**：违反任一硬不变量 → HTTP 4xx、species+edge 整笔不写。lab 生成期用同一 `validateEvolutionEdge` 预检（好 UX）。
- godot 收的是**已被 server 硬拒过的数据**，其 contract 校验是**防御性**（结构 + 引用足矣，树不变量可选复检）。

## 4. 完整示例（分支 + 孤儿）

```jsonc
{
  "schema": "inkmon.l2.content.v2", "version": 2, "source": "lab-canon-projection", "status": "ok",
  "units": [
    { "id": "mon_0001", "display_name": "Sprout",    "stage": "baby",   "elements": ["earth"],         "base_stats": { "max_hp": 60, "ad": 30, "ap": 20, "armor": 25, "mr": 20, "speed": 45 } },
    { "id": "mon_0007", "display_name": "Emberling",  "stage": "mature", "elements": ["earth","fire"],  "base_stats": { "max_hp": 90, "ad": 55, "ap": 30, "armor": 35, "mr": 30, "speed": 60 } },
    { "id": "mon_0009", "display_name": "Aquling",    "stage": "mature", "elements": ["earth","water"], "base_stats": { "max_hp": 95, "ad": 35, "ap": 55, "armor": 30, "mr": 40, "speed": 55 } },
    { "id": "mon_0042", "display_name": "Lonewisp",   "stage": "baby",   "elements": ["light"],         "base_stats": { "max_hp": 50, "ad": 25, "ap": 35, "armor": 20, "mr": 30, "speed": 70 } }
  ],
  "evolution_edges": [
    { "parent_species_id": "mon_0001", "child_species_id": "mon_0007", "trigger": { "level": 16, "condition": { "type": "item", "params": { "item_id": "firestone" } } } },
    { "parent_species_id": "mon_0001", "child_species_id": "mon_0009", "trigger": { "level": 16 } }
  ],
  "skill_pools": [], "skills": [], "items": []
}
```

- `mon_0001` 在 L16 分支：持火石 → `mon_0007`（fire），否则默认枝 → `mon_0009`（water）。
- `mon_0042` 是**孤儿**（无边），合法。

## 5. 引用方

- **生产端（lab）**：`@inkmon/canon/godot-contract.ts` + server 投影端点（实现计划在 lab 仓）。
- **消费端（godot）= 已落地**：`ink_mon_l2_content_contract.gd`（校验）+ `ink_mon_content_loader.gd`（规范化）+ `ink_mon_species_catalog.gd`（edge-list 森林消费）+ `inkmon/tests/fixtures/`（fixture）。
- 两边可并行开发，各自对着本 spec + 本地 fixture 自测；**端到端**需 lab+server 发出 v2 投影后联调，破坏性上线同步清库重建。
