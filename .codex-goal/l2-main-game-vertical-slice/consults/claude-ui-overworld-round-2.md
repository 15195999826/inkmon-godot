核实完毕，第 1 轮 spec 挂靠的代码锚点基本属实（`app_state` enum、`session.player_state.gold/roster/progression`、`create_bag_item`、`start_training_battle`、agent_ops 三个 op 全对上）。但抓到两处与真实数据的偏差，影响 prompt 收敛。下面是 final review。

## 1️⃣ 第一张图选 Shop opened —— ✅ 同意

理由比"Shop 更典型"更硬：

- **Shop = 通用 shell 模板本身**。它的 body 就是裸 row-list（icon + name + price + Buy），正好压测你列的反模式守卫（单层 list、no card-in-card、low-chrome side sheet）。这套 list 框架其余 4 个 NPC 直接复用。
- **Trainer 是定制布局**（roster 选择 + 上场预览 + 主 CTA），第一张先验证"可复用 shell"比先验证"定制页"更划算。Trainer 留第二张图，用来证明"同 shell 换 body"。

## 2️⃣ Godot v1 必须可见元素（压到 10 项）

| # | 元素 | 数据源（只读真实字段） |
|---|---|---|
| 1 | WorldLayer：hex 地图 + player token（居中偏下） | `player_state.overworld.player_coord` |
| 2 | 2 个功能 NPC marker（Shop + Trainer，带微光）；其余 4 个 v1 可省 | 静态布局即可 |
| 3 | 左上 gold（amber 币 + 数字） | `player_state.gold`（默认 100）|
| 4 | trainer rank chevron `R1` | `player_state.progression.trainer_rank`（=1）|
| 5 | roster chip 横排（role icon + element dot + level） | `player_state.roster`（**数量绑 `roster.size()`，别写死 4**）|
| 6 | 右上 settings cog（纯静态占位即可） | — |
| 7 | near-NPC `Enter ▸` bubble（PromptLayer） | NPC 邻接判定 |
| 8 | NPC side sheet shell（header: 名 + type + close）+ dim 25% overlay | `app_state == NPC_MENU` |
| 9 | Shop item rows（icon + name + price + `Buy`） | 真实 catalog：**Training Sword / Minor Rune** |
| 10 | Trainer 主 CTA `Start Training Battle`（复用同 shell） | `start_training_battle()` |

## 3️⃣ real-input vs direct scene op

**⚠️ 必须 real-input（`Viewport.push_input` + `input_helper.gd`，仿 `smoke_ui_main_menu.gd`）：**
- overworld 移动 → 触发 near-NPC prompt
- `Enter ▸` 开 panel（**`OVERWORLD → NPC_MENU` 这条状态转换当前代码里零触达，全新路径，必须真注入**）
- Shop `Buy` 点击、Trainer CTA 点击、panel close、roster chip 展开

**✅ 仍可 direct scene op（现有 `ink_mon_main_agent_ops.gd` 三个 op，纯数据流无 UI）：**
- `state` / `reset_session` / `run_training_battle`
- Buy 之后的**结果断言**（gold 扣减、bag 多一个 item）可 direct 读 `get_dev_agent_state()`；但**触发 Buy 的那一下点击必须 real-input**。点击≠信号捷径。

## 4️⃣ 最终 imagegen prompt（修正版）

两处必改：① catalog 里没有 `price` 字段，"30/10"是占位；② display name 是 `Training Sword` / `Minor Rune` 不是 Sword/Rune。其余沿用第 1 轮。

```
A single 16:9 desktop game UI reference mockup for a fantasy hex-grid overworld.
The dominant center is a top-down ink-wash hex map on warm parchment tones, with a
player token near center and a few stylized NPC markers on the hex tiles; two markers
(a shop tent and a training dojo banner) are larger with a soft glow.
A small floating prompt bubble sits beside one NPC showing a short label "Enter".
Top-left: a compact semi-transparent ink panel with an amber gold coin reading "100",
a small rank chevron "R1", and a row of small monster portrait chips, each with a tiny
colored element dot (gold, violet, ember-red, teal, sage) and a level number.
Top-right: a single settings cog icon.
A right-side slide-in panel (about one third width) titled "Shop" lists two simple item
rows: a sword icon labeled "Training Sword  30" and a rune icon labeled "Minor Rune  10",
each with a small "Buy" button; the rest of the playfield is only slightly dimmed (~25%)
and still clearly visible.
Style: clean low-chrome fantasy UI, ink-and-parchment palette, simple flat shapes and
icons (Control-first, not detailed illustration), minimal readable labels only, no
paragraphs, no lorem text, no marketing copy. Subtle, uncluttered, playfield-first.
```

## 5️⃣ Blocker

**出图无 blocker。**

实现前需敲定 **1 项数据源**（不挡出图）：Shop 价格——`InkMonItemCatalog` 现无 `price` 字段，`Training Sword`/`Minor Rune` 只有 `stat_mods`/`item_tags`。Buy 流程要么在 catalog 加 `price`，要么在 Shop NPC config 里单独定价。出图阶段当占位数字即可，进 Godot 实现时定。

---

📌 一句话定性：**方向收敛完成，Shop-first 出图无 blocker，可直接喂 imagegen**；交付给 Codef 时把"价格是占位、roster chip 数量绑真实 size"两条提醒带上即可。

（本轮纯讨论，未触碰任何文件。）
