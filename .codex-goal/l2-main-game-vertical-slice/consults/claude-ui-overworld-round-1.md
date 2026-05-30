Write 工具在当前上下文不可用，我直接把完整设计交付在这里（你本来也只要讨论，不改文件）。

---

# 🎨 InkMon L2 v1 Overworld + NPC Shell — Mockup 设计

## 1. Visual Direction

- **基调**：水墨 + 羊皮纸（ink-wash on parchment）。playfield 是暖色羊皮纸 hex 世界地图；chrome 用低饱和墨黑、半透明 —— **不是 flat material dashboard**。
- **Palette**：
  - playfield base：warm parchment `#E8DCC0 → #D8C8A0`
  - UI chrome：ink charcoal `#2A2620` @ 70–85% alpha
  - 货币 gold：amber `#E0A93B`
  - 5 元素 accent（roster element dot / NPC 风格）：light `#F2C84B` · dark `#6E4FA3` · fire `#D9522B` · water `#2FA3A3` · wind `#6FA85C`
- **Typography**：标题 / NPC 名 / panel title 用半衬线 fantasy display；数值 / 标签用 clean sans。字号克制。
- **Motion**：常驻 HUD 静止；near-NPC prompt 用 subtle float/pulse；panel slide-up + fade 150–200ms（不弹跳）；playfield 上 player/NPC idle 微动。

## 2. Layout（16:9，1920×1080；可收缩移动端）

中心 hex overworld 永远是第一视觉主体，三态都不被完全遮盖。

**State A — Normal Overworld HUD**（chrome < 15%，全在四角）
- 🔸 左上 compact cluster（贴边半透明 ink panel）：gold(amber 币+数字) / trainer rank(`R1` + chevron) / 4 个 roster portrait chip 横排（每 chip = role icon + element dot + level 角标）。
- 🔸 右上：单个 settings cog icon。
- 🔸 中心：player token 居中偏下；6 个 NPC marker 散布带头顶小 label，**Shop / Trainer marker 更大 + 微光**，其余 4 个统一低调。
- 🔸 底部：几乎无 chrome，仅留一条极淡 contextual hint 行的位置。

**State B — Near-NPC Prompt**
- player 进入 NPC 邻接 hex → NPC 旁浮出 compact bubble：NPC 名 + 类型 icon + `Enter ▸`。
- **不开 panel、不暗化 playfield**，其它 HUD 不动；底部 hint 行同步一行极短字。

**State C — NPC Panel Opened**（`AppState.NPC_MENU`）
- 右侧 slide-in side sheet 占屏宽 ~1/3；playfield **仅 dim ~25%（非全黑）**，上下文可见。
- header：NPC 名 + 类型 + close。body 单层 list/row，**不套 card-in-card**：
  - **Shop**：item row（icon + name + price）× 少量；gold 常驻 panel 顶；`Buy`。
  - **Trainer**：roster 选择 + 上场预览 + 主 CTA `Start Training Battle`。
  - 其余 4 NPC：共用同一 panel 框架，body 放 placeholder entry（证明可扩展）。

## 3. 常驻 vs 折叠

| 常驻（A/B/C 都在） | 临时 / 折叠 |
|---|---|
| gold · 4 roster chip · trainer rank | NPC prompt bubble（仅 near-NPC）|
| | NPC panel body（仅 opened）|
| | roster 详情 stats/skill/equip（chip 默认折叠，点开展开）|
| | progression 细节 cultivation/guild（折进对应 NPC panel，**不上 HUD**）|
| | contextual hint 行（按状态出现）|

## 4. Godot Implementation Notes

**分层**
- `WorldLayer`（Node2D / SubViewport）：hex grid + player token + NPC markers，永远在底（复用 `UGridMap` / hex 渲染）。
- `HUDLayer`（CanvasLayer + Control）：四角 cluster，常驻。
- `PromptLayer`（Control，按 NPC world→screen 投影定位）：near-NPC bubble。
- `PanelLayer`（CanvasLayer，最上）：NPC side sheet + dim overlay（ColorRect alpha）。

**对齐现有状态机** —— `app_root.gd` 已有 `AppState {OVERWORLD, BATTLE, NPC_MENU}`，HUD 按 app_state 切 Prompt/Panel 可见性，`NPC_MENU` = panel opened。数据只读 `session.player_state`；Shop buy → `session.create_bag_item` + 扣 gold；Trainer CTA → 现成 `start_training_battle()`。

**DevAgent 验证边界**
- ✅ **可继续 direct scene op**：`state` / `reset_session` / `run_training_battle` 这类无 UI 路径的数据流验证（`ink_mon_main_agent_ops.gd` 已注明）。
- ⚠️ **必须 real-input（`Viewport.push_input` + `input_helper.gd`）**：所有 player-facing Control —— Shop Buy、Trainer CTA、roster chip 展开、panel close，以及 overworld 移动触发 prompt。仿 `smoke_ui_main_menu.gd` 模板，禁 `pressed.emit()` 捷径。

## 5. Imagegen Mockup Prompt

> 单帧主图 = State C（Shop 打开），同帧带 HUD + playfield + 另一 NPC 的 prompt bubble，一张图覆盖三态要素。仅少量短 label。

```
A single 16:9 desktop game UI reference mockup for a fantasy hex-grid overworld.
The dominant center is a top-down ink-wash hex map on warm parchment tones, with a
player token near center and several stylized NPC markers spread across the hex tiles;
two NPC markers (a shop tent and a training dojo banner) are larger with a soft glow.
A small floating prompt bubble sits beside one NPC showing a short label "Enter".
Top-left: a compact semi-transparent ink panel with an amber gold coin reading "100",
a small rank chevron "R1", and a row of four small monster portrait chips, each with a
tiny colored element dot (gold, violet, ember-red, teal, sage) and a level number.
Top-right: a single settings cog icon.
A right-side slide-in panel (about one third width) titled "Shop" lists two simple item
rows: a sword icon labeled "Sword  30" and a rune icon labeled "Rune  10", with a small
"Buy" button; the rest of the playfield is only slightly dimmed and still visible.
Style: clean low-chrome fantasy UI, ink-and-parchment palette, simple shapes and flat
icons (Control-first, not detailed illustration), minimal readable labels only, no
paragraphs, no lorem text, no marketing copy. Subtle, uncluttered, playfield-first.
```

## 6. 我会拒绝的 Anti-patterns

- ❌ 满宽 top nav / 底部 toolbar 吃掉 playfield
- ❌ card-in-card 套娃；满屏 dashboard 卡片网格（generic SaaS look）
- ❌ 中心 modal 全黑遮罩盖死 overworld
- ❌ 6 个 NPC 各一套不同 panel（应共用 shell）
- ❌ HUD 常驻铺全部 6 stat + skill 描述（信息过载）
- ❌ 教学文案 / 快捷键说明铺屏
- ❌ lorem / 假长段落撑界面

---

定性：这是一份可直接喂 imagegen 的 mockup spec，三态、配色、分层、验证边界都落在了真实的 `app_root.gd` / `player_state` / `item_catalog` 上。要不要我据此**进入下一步生成 imagegen mockup**，还是先调整某个状态（比如把主图换成 Trainer 打开、或改成左侧 panel）？
