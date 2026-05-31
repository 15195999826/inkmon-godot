I can't list directories with only LSP, and path-guessing is burning probes. The prompt already specifies the exact data surfaces, and this is a design-time consult (mockup/implementation comes later). I'll anchor to the surfaces you named and flag field names to verify at implementation time.

---

# InkMon L2 3D Overworld — Player UI Information Architecture

## Design principle
**Movement-first, summon-on-demand.** The 3D hex field owns the screen. Persistent UI lives only in the corners as thin status glyphs; everything dense is a player-summoned overlay that pauses nothing but visually dims the field. One hotkey row, one corner cluster, no center/lower-middle chrome.

---

## 1. Persistent HUD (always-on, corner-only)

| Slot | Placement | Content | Footprint |
|---|---|---|---|
| **Status pill** | top-left | avatar portrait + `trainer_rank` badge + `gold` counter (coin icon) | single row, ~280×48 |
| **Party strip** | top-left, under pill | up to 6 roster slots: species icon + level + thin HP bar; lead is highlighted | one icon row |
| **Hotbar hint** | bottom-left (small, fades after 3s idle) | key glyphs: `P`arty `B`ag `J`ournal `Esc`menu | tiny |
| **Context prompt** | floats above target, NOT screen-center | "Right-click to move" / "[E] Talk to {npc}" | diegetic, anchored to world point |

Everything else (center, lower-middle, right side during movement) stays empty. The party strip is the only "dashboard-ish" element and it's deliberately glanceable, not interactive-dense.

---

## 2. Panels / drawers / tabs

One **right-side drawer** (slide-in from right edge, ~40% width, dims field with a 35% scrim). A single drawer host with a tab bar so only one panel is ever open — avoids stacking windows over the 3D scene.

- **Tab: Party** — roster list → click entry expands detail card (species/role/elements, level/exp bar, stats grid, `learned_skill_id`, equipment slots from `equipment_container`, medals row). Reorder = set lead.
- **Tab: Bag** — category filter (consumable/material/equipment) + scrollable item grid bound to ItemSystem; item detail on select; "use"/"equip" actions where applicable.
- **Tab: Journal/Progress** — `trainer_rank`, `guild_joined` status, `cultivation_points`, last_battle_result summary.
- **System menu (Esc)** — separate centered modal (not the drawer): Save / Load slots, Settings, Quit. Save/load is intentionally *not* a tab — it's a deliberate, low-frequency action that deserves a confirm modal, not a quick drawer flick.

Opening any tab while moving cancels nothing; closing returns to clean field.

---

## 3. NPC side sheet relationship

The existing NPC side sheet should **become the same right-drawer host**, occupying it as a transient "NPC" context rather than a parallel UI system. Rules:
- NPC interaction = drawer opens to a dedicated NPC view (dialogue/options), tab bar hidden or showing only "Close."
- Player-owned tabs (Party/Bag/Journal) and NPC sheet are **mutually exclusive in the same slot** — opening Party while talking closes/suspends the NPC view. This prevents two side sheets fighting for the right edge.
- Shared slide/scrim animation and width so it reads as one surface with different contents.

---

## 4. Controls / movement & prompt affordances

- **Right-click = move** stays primary; show a brief ground decal/ring at the clicked hex (confirmation feedback) — this is the only center-screen element, and it's transient.
- **Hover prompt**: hovering an NPC/interactable shows the diegetic `[E] Talk` floating label; clicking or `E` opens the NPC drawer.
- **Left-click** reserved for UI; on the field, left-click selects/inspects (hover-to-prompt), never moves — keeps move intent unambiguous.
- Hotbar glyphs (`P/B/J/Esc`) are discoverable but auto-fade; `Esc` closes any open drawer first, then opens system menu.
- No on-screen virtual buttons for movement (desktop mouse target).

---

## 5. Data bindings (verify exact names at implementation)

Bind read-only to session state; refresh on a state-changed signal, not per-frame.

| UI element | Source |
|---|---|
| gold counter | `InkMonPlayerState.gold` |
| rank badge / guild / cultivation | `progression["trainer_rank"]`, `["guild_joined"]`, `["cultivation_points"]` |
| party strip + Party tab | roster entries: `species, role, elements, level, exp, stats, learned_skill_id, equipment_container, medals` |
| Bag grid | global `ItemSystem` inventory query (counts/stacks) — bind to ItemSystem's own change signal, don't snapshot |
| Journal last battle | `last_battle_result` |
| Save/Load modal | session save/load APIs |

**Explicitly: no DevAgent state dump.** All reads go through `InkMonPlayerState` + `ItemSystem` public accessors. Since I couldn't open the source files in this read-only consult, treat the field names above as your prompt's contract and confirm the exact accessor signatures (`get_*` vs raw dict) before wiring — per project convention, read the real definitions before use.

---

## 6. Accessibility / readability (desktop viewport)

- Min body text 14px, panel titles ≥18px; never rely on color alone for elements (icon + text label).
- Drawer scrim ≥30% so panel text has contrast over arbitrary 3D backgrounds; panels get an opaque-enough background, not full glass.
- HUD corner clusters anchored to corners (anchor presets), scale-safe at 1280×720 → 1920×1080; keep a safe margin so nothing clips.
- Single focus owner: when drawer/modal open, field input is suppressed (no accidental right-click move under the panel).
- Keyboard-navigable tabs and list entries (focus ring), Esc always escapes one layer.

---

## 7. Reject

- ❌ Always-on dense dashboard / center or lower-middle persistent HUD.
- ❌ Multiple simultaneous side sheets (NPC + Party both docked) — one right-slot host only.
- ❌ Free-floating draggable/stackable windows over the 3D scene.
- ❌ Save/Load as a casual quick-tab — keep it a confirm modal.
- ❌ DevAgent/debug state dump as a player surface.
- ❌ Per-frame polling of state/ItemSystem for HUD values — signal-driven refresh only.
- ❌ Virtual movement buttons / left-click-to-move ambiguity.

---

Want me to verify the exact `InkMonPlayerState`/`ItemSystem` accessor names against the source before the mockup step? If so, tell me the example folder name (my path probes for `3d-overworld`/`overworld`/etc. all missed) and I'll confirm field bindings via LSP.
