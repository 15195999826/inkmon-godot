# InkMon L2 3D Overworld — 最终 Player UI 架构（M1-correction 落地版）🎮

复用现有 AppRoot 的三件套（HUD layer / prompt button / NPC side sheet），**不造 window manager**：一个右侧 drawer 复用为 NPC + 玩家面板的共享 slot，加一个可选的 save/load confirm modal。就这些。

---

## 1. Godot Control 层级（具体节点树）🌲

```
AppRoot
├─ World3DViewport            # 3D hex 场景（已有，占满）
│
├─ HUDLayer (CanvasLayer, layer=10)        # ← 复用现有 HUD layer
│  ├─ TopLeftCluster (VBoxContainer, anchor=top-left, margin 16)
│  │  ├─ StatusPill (PanelContainer)        # 头像 + rank badge + gold
│  │  │  └─ HBox: PortraitTexture | RankBadge(Label+icon) | GoldCounter(HBox: CoinIcon|Label)
│  │  └─ PartyStrip (HBoxContainer)         # 最多 6 槽
│  │     └─ PartySlot ×6 (PanelContainer): SpeciesIcon | LvLabel | HPBar(thin ProgressBar)
│  │
│  ├─ TopRightTools (HBoxContainer, anchor=top-right, margin 16)
│  │  └─ ToolButton ×4: Btn_Party(P) | Btn_Bag(B) | Btn_Journal(J) | Btn_Menu(Esc)
│  │     # 纯图标 Button，hover 显示 tooltip + 快捷键字母
│  │
│  ├─ HotbarHint (HBoxContainer, anchor=bottom-left)   # idle 3s 后 fade（已有 prompt 思路复用）
│  │
│  └─ ContextPrompt (existing prompt button, 改造)
│     # 不再是固定按钮 → 跟随世界点的 floating Label/Button："[E] Talk to {npc}"
│
├─ RightDrawer (CanvasLayer, layer=20)      # ← NPC side sheet 升级成共享 host
│  ├─ Scrim (ColorRect, anchor=full, color rgba 0,0,0,0.35, mouse_filter=STOP)
│  └─ DrawerPanel (PanelContainer, anchor=right, width=40%, off-screen 起始)
│     ├─ TabBar (HBoxContainer)             # Party | Bag | Journal —— NPC 模式下隐藏
│     ├─ DrawerContent (MarginContainer)    # 只挂一个当前 view
│     │  ├─ PartyView    (VBox: roster list → detail card)
│     │  ├─ BagView      (VBox: category filter + item GridContainer + detail)
│     │  ├─ JournalView  (VBox: rank/guild/cultivation/last_battle)
│     │  └─ NpcView      (existing 对话/选项内容迁入这里)
│     └─ CloseButton (×)
│
└─ ModalLayer (CanvasLayer, layer=30)       # 仅 save/load + settings 用
   └─ SaveLoadModal (CenterContainer, 默认 hidden)
      └─ Panel: 存档槽列表 | Save/Load/Settings/Quit | Confirm/Cancel
```

**关键实现约束**：
- `RightDrawer` 只有**一个** `DrawerContent`，四个 view 同一时间只 `visible` 一个 → 天然互斥，不需要 window manager。切换 = 隐藏旧 view + 显示新 view + 滑入动画（`Tween` 改 `DrawerPanel.position.x`）。
- NPC 模式：`TabBar.hide()`，显示 `NpcView`；玩家面板模式：`TabBar.show()`。同一 drawer，同一 scrim/滑动动画。
- `Scrim.mouse_filter = STOP` → drawer 开着时自动吞掉 field 的 right-click move（单一 focus owner，零额外代码拦截）。

---

## 2. 默认开关行为（状态机）⚙️

| 场景 | HUD cluster | RightDrawer | Modal | Field 输入 |
|---|---|---|---|---|
| **首次加载** | StatusPill + PartyStrip 显示；HotbarHint 显示 3s 后 fade | 关闭（off-screen） | 关闭 | 启用（right-click move） |
| **移动中** | 全部保持显示，不打断 | 关闭 | 关闭 | 启用 |
| **靠近 NPC** | 保持 | ContextPrompt 浮在 NPC 头上显示 `[E] Talk`；**不自动开 drawer** | 关闭 | 启用（走过去仍可移动） |
| **按 E / 点 NPC** | 保持 | 滑入 NpcView（TabBar 隐藏） | 关闭 | **Scrim 拦截**，field 暂停 |
| **战斗奖励后** | gold/party HP/exp 通过 state-changed signal 刷新（数字跳动）；**不强开 drawer** | 关闭（可选：Journal 角标提示有新 last_battle_result） | 关闭 | 启用 |
| **按 P/B/J 或点 tool button** | 保持 | 滑入对应 view（TabBar 显示） | 关闭 | Scrim 拦截 |
| **按 Esc** | 保持 | 若 drawer 开 → 先关 drawer | 若 drawer 已关 → 开 SaveLoadModal | Modal 拦截 |

**Esc 单层回退**：drawer 开 → 关 drawer；drawer 关 → 开系统 menu；menu 开 → 关 menu。一次只退一层。

**战斗奖励后不抢镜**：奖励只触发 HUD 数字刷新 + Journal 可选角标，玩家回到干净 field，要看详情自己开 Journal。

---

## 3. 数据绑定（signal-driven，实现时核对真实 accessor）🔌

> ⚠️ 按项目惯例：wire 之前用 LSP/grep 读真实定义，别凭下表字段名假设 `get_*` vs 裸 dict。

| UI 元素 | 数据源（待核对） | 刷新时机 |
|---|---|---|
| GoldCounter | `InkMonPlayerState.gold` | state-changed signal |
| RankBadge / Journal | `progression["trainer_rank"/"guild_joined"/"cultivation_points"]` | state-changed signal |
| PartyStrip + PartyView | roster: `species/role/elements/level/exp/stats/learned_skill_id/equipment_container/medals` | roster-changed signal |
| BagView grid | `ItemSystem` 自身 inventory 查询 | **绑 ItemSystem 自己的 change signal，不 snapshot** |
| JournalView last battle | `last_battle_result` | battle-end signal |
| SaveLoadModal | session save/load API | 打开时拉槽位列表 |

**禁止**：per-frame 轮询、DevAgent state dump 当玩家面板。全部走 `InkMonPlayerState` + `ItemSystem` public accessor。

---

## 4. Reject（实现红线）🚫

- ❌ 居中 / 下方常驻 dense dashboard
- ❌ 同时两个 side sheet（NPC + Party 并存）
- ❌ 可拖动 / 可堆叠浮窗 → **不要 window manager**
- ❌ Save/Load 当快捷 tab → 必须 confirm modal
- ❌ 战斗奖励强开面板抢镜
- ❌ HUD per-frame 轮询 state/ItemSystem
- ❌ 虚拟移动按钮 / left-click 移动歧义（left-click 留给 UI，right-click 移动）

---

## 5. ImageGen Mockup Prompt 🖼️

```
A clean game UI mockup for a 3D hex-grid creature-trainer overworld, desktop 16:9.

SCENE: An isometric-ish 3D overworld of stylized hexagonal tiles (grass, path, water),
a small player avatar standing on a hex, a friendly NPC nearby with a floating diegetic
prompt label "[E] Talk" above their head. Soft daylight, painterly low-poly style.
The 3D field dominates the whole screen and stays unobstructed in the center.

HUD (corners only, thin and glanceable):
- TOP-LEFT: a compact status pill — round avatar portrait, a small "Rank" badge,
  and a gold counter with a coin icon. Directly below it, a single horizontal row of
  6 small party slots, each a tiny creature icon + level number + a thin HP bar;
  the lead slot subtly highlighted.
- TOP-RIGHT: a row of 4 small square icon buttons (Party / Bag / Journal / Menu),
  flat icons with tiny key-letter hints.
- BOTTOM-LEFT: a faint, tiny hotkey hint row (P B J Esc), low opacity.

RIGHT DRAWER (one panel, slid in from the right edge, ~40% width):
showing a "Party" tab open — a vertical roster list on the left of the drawer and a
selected creature detail card on the right (portrait, level/exp bar, a small stats grid,
element icons, equipment slots). The drawer has a semi-opaque dark panel background and
casts a 35% dark scrim over the rest of the 3D field so the field dims but stays visible.
A small tab bar at the drawer top (Party | Bag | Journal) and a close "×".

STYLE: cohesive game UI, rounded panels, readable icons + text labels together,
warm but legible palette, gentle drop shadows, diegetic and game-like.

AVOID: dense always-on dashboard; any UI in the screen center or bottom-center;
generic corporate SaaS cards / charts / data tables; multiple floating draggable windows;
two side panels at once; flat web dashboard look; cluttered toolbars; tiny unreadable text.
```

---

需要的话，告诉我 3D overworld example 的文件夹名，我就用 LSP 把 `InkMonPlayerState` / `ItemSystem` 的真实 accessor 签名核一遍，再进 mockup→实现。要不要现在核字段？
