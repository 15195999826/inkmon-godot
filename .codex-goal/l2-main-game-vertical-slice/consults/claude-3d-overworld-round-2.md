Grounded. Current state confirmed:
- `InkMonAppRoot` at `scenes/inkmon-main/app_root.gd`; player coord round-trips via `_get_player_coord()/_set_player_coord()` (internal `Vector2i(q,r)` ↔ session dict). Your correction holds: real source is `session.player_state.overworld["player_coord"]` `{q,r}`.
- Current view `InkMonOverworldView` is a **2D `_draw` Control** (`HEX_SIZE=44`, `MAP_RADIUS=4`, `coord_to_screen`, `set_npcs`, `set_near_npc_id`). HUD/panel/prompt are already **separate CanvasLayers** off AppRoot, not children of the view.
- `move_player(delta_coord: Vector2i)` is delta-based; `_refresh_near_npc` + `_axial_distance` already do proximity.

---

# L2 3D Hex Overworld — Round 2 (final) 🗺️

## A. Chosen architecture

### A1. Move implementation = **lightweight two-phase controller, NOT LGF Ability/Action/Timeline** ✅
`OverworldMoveController.gd` emits `move_started`/`move_completed`, preserving the reserve→apply contract — but **no AbilitySet / Timeline / EventProcessor**.

**Why (decisive):** the full LGF Action stack (`InkMonOverworldStartMoveAction` etc.) only makes sense inside a `GameInstance` with an `EventProcessor`, `AbilitySet`, and a timeline scheduler — all of which exist **only in battle** (`InkMonBattleWorldGI`). The overworld has none of that and shouldn't grow one for a single grid hop. A controller reproduces the *observable* two-phase semantics (occupy-target → commit → release) at the coordinate layer for ~1% of the wiring cost. **Seam preserved for promotion:** controller exposes the same `started/applied/completed` ordering, so if overworld ever gets its own GI we swap the controller body for Actions without touching AppRoot or smokes.

### A2. Path move = **axial neighbor-graph BFS over the bounded hex map** ✅
Single-step / straight-line is **rejected as the primary path** (your correction). Right-click any reachable hex → BFS:
- Graph = the existing bounded map (`MAP_RADIUS=4`, ~61 hexes) minus occupied tiles.
- **Not** sim-nav-map / RTS A* / steering — a hand-rolled hex BFS on a 61-node graph, cost = neighbor table only.
- BFS yields an ordered coord list; **each step runs the full Move pipeline** (`reserve(next)`→`apply`→`release`), animated sequentially by the view. Block/occupancy re-checked per step (NPC could occupy mid-path in future multi-actor cases).
- If unreachable (fully walled), reject with `move blocked` and tile unchanged.

### A3. View = **`OverworldView3D` (Node3D) replacing the 2D Control**, same interface seam
Keep AppRoot↔view contract identical so AppRoot barely changes:
- `set_player_coord(Vector2i)`, `set_npcs(Dictionary)`, `set_near_npc_id(String)` — **unchanged signatures**.
- Add `coord_to_world(Vector2i)->Vector3` (replaces `coord_to_screen`) and `world_to_coord(Vector3)->Vector2i`.
- New signals: `tile_picked(coord: Vector2i)` (RMB raycast result), `move_step_finished(coord)` (animation done → controller advances).
- GridMap (KayKit hex tiles) + Camera3D + player/NPC anchors live in `OverworldView3D.tscn`.

### A4. NPC occupancy + adjacency retarget (precise) ✅
- Every NPC in `npc_defs` **registers its coord as a blocked occupant** in `OverworldGrid`.
- RMB → `world_to_coord`. **Target resolution:**
  1. If picked tile is free and reachable → goto it.
  2. If picked tile is an **NPC tile** (or any blocked tile) → retarget to the **free neighbor of that tile with minimum BFS distance from the player** (deterministic tie-break: lowest `(q,r)`). That neighbor becomes the BFS goal.
  3. No free reachable neighbor → reject, tile unchanged.
- On arrival, AppRoot's existing `_refresh_near_npc` runs (now event-triggered off `move_completed`, not `_process` delta): if `_axial_distance(player, npc) == 1` → mark `_near_npc_id` + show prompt (current `open_near_npc_menu` flow unchanged). **AppRoot is the only orchestrator; view never calls handlers.**

### A5. UI integration seam (architecture-only; visuals deferred to UI/imagegen round) ✅
- `_hud_layer` / `_panel_layer` / `_prompt_layer` **stay AppRoot-built CanvasLayers**, reading `session` + `ItemSystem`. **They never read `OverworldView3D`.**
- 3D view emits picks + plays move animation; it does not own panels, gold, roster, or shop state.
- Seam contract: `AppRoot → (session, ItemSystem) → CanvasLayer panels` and `AppRoot ↔ view` only via the A3 signatures/signals. The later UI round restyles panels with zero controller changes.

---

## B. Rejected alternatives ❌
- ❌ **LGF Action/Timeline fork for overworld move** — needs a GI/EventProcessor that overworld lacks; over-engineered for one hop. (A1)
- ❌ **Single-step / straight-line as primary** — fails "right-click a tile and path there" requirement. Only allowed as an explicitly-documented temp fallback, which we are *not* taking. (A2)
- ❌ **sim-nav-map / RTS A* / steering / nav grid** — banned per [[feedback_no_unitai_layer]]; BFS on 61 hexes needs none of it.
- ❌ **`preload`/`extends` any `example/hex-atb-battle/**`** — grid/event/view all forked into `scenes/inkmon-main/overworld/`.
- ❌ **Reusing battle `InkMonMove`** — bound to battle GI.
- ❌ **View calling NPC handlers / a UnitAI middle layer** — AppRoot stays sole orchestrator.
- ❌ **Keeping `move_player(delta)` as primary** — demote to hidden debug/DevAgent path only.

---

## C. Exact acceptance checks
New group `scenes/inkmon-main/tests/test_groups.json`, namespace `main`; run `./tools/run_tests.ps1 main/overworld`.

| smoke | assertion |
|---|---|
| `smoke_overworld_move.tscn` | `request_move(adjacent)` → grid occupant migrates, `session.player_state.overworld["player_coord"]` updates to new `{q,r}`, `move_started`+`move_completed` each fire once, reservation set empty after. |
| `smoke_overworld_path.tscn` | RMB-equivalent `goto(target 3+ hexes away)` → BFS path length ≥3, **Move pipeline runs once per step** (started/applied/completed count == step count), final coord == target. |
| `smoke_overworld_blocked.tscn` | Target tile occupied by NPC → **retarget to min-distance free adjacent tile**; final `_axial_distance(player, npc)==1`; if NPC fully walled → reject, coord unchanged. |
| `smoke_overworld_npc_trigger.tscn` | Arrive adjacent to NPC → AppRoot sets `_near_npc_id` and mock handler receives the open call (handler unaware of view). |
| `smoke_overworld_pick.tscn` (UI interaction) | `InputHelper` + `Viewport.push_input` RMB → `OverworldView3D.world_to_coord` returns the correct axial; `tile_picked` emits that coord. (uses `ensure_window_size` template.) |
| `smoke_overworld_save_load.tscn` | move → `save_game` → `load_game` → `player_coord` restored; confirms session/save spine untouched. |
| `smoke_overworld_devagent_parity.tscn` | DevAgent `goto_tile(axial)` drives the **same** `OverworldMoveController` as the UI pick — assert identical resulting coord + same event sequence (no second move impl). |

**Hard invariants every smoke upholds** (per [[feedback_lab_test_categories]]): no reservation leak; occupant count conserved; player never lands on a blocked tile; `player_coord` dict and view position never diverge.

---

⚠️ Before coding I still must read the bodies of: `_get/_set_player_coord` + `_get_player_coord_dict` (dict↔Vector2i exact keys), `_refresh_near_npc` (proximity threshold), `npc_defs` entry shape (coord key name), and a KayKit GridMap coord-conversion reference for `coord_to_world`. Per [[feedback_verify_field_names_before_use]] I won't lock the API names until then.

Want me to read those four bodies and produce the final method-signature-level spec (the actual `OverworldMoveController` / `OverworldGrid` / `OverworldView3D` public API)?
