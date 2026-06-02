# InkMon Main - DevAgent Contract

## Scene Classification

Business/data-flow runtime validation plus real-input checks for the corrected
3D overworld, animated right-click hex movement, NPC drawer, player panels, and
save/load modal transitions.

## Launch

```powershell
$env:SESS_NAME = "inkmon-main-runtime"
$env:SESS_DIR = "$env:APPDATA\Godot\app_userdata\Inkmon\dev-agent\sessions\$env:SESS_NAME"
New-Item -ItemType Directory -Force -Path $env:SESS_DIR | Out-Null
godot --path . res://scenes/inkmon-main/InkMonMain.tscn -- --dev-agent --dev-agent-session=$env:SESS_NAME > "$env:SESS_DIR\godot.log" 2>&1
```

`InkMonMain.tscn` is the thin outer screen router; it boots the inner game
host (`ink_mon_game.tscn`, node name `WorldHost`) which installs the
DevAgent bridge + scene ops. The `WorldHost` (composition + lifecycle + flow +
tick) owns no UI directly — the UI subtree (3D overworld view, HUD, drawer,
modal) lives under its `Presentation` child (`InkMonWorldPresentation`). So the
runtime tree is `/root/InkMonMain/WorldHost/{Presentation/...,
InkMonMainAgentOps, DevAgentBridge}`. The scene ops + introspection still go
through `WorldHost` (it aggregates Presentation's UI debug surface). The scene
prints `inbox` and `outbox` global paths when DevAgent is enabled.

## Scene Ops

### Observation

| op | args | data |
| --- | --- | --- |
| `state` | none | `state`, `gold`, `roster_size`, `roster`, `progression`, `player_coord`, `player_moving`, `near_npc_id`, `active_npc_id`, `panel_open`, `drawer_open`, `drawer_mode`, `modal_open`, `ui_message`, `bag`, `overworld_3d`, `ui_animation`, `last_move_result`, `active_instance_id`, `last_battle_result`, `game_world`, `events` |
| `layout_state` | none | viewport and clickable rects for prompt, drawer close, NPC action buttons, Shop buy buttons, top-right tool buttons, drawer tabs, and save/load modal buttons |
| `tile_screen_position` | `{ "q": int, "r": int }` | screen coordinate for a 3D hex tile center, used with raw `click_at` + `button:"right"` |

### Action

| op | args | effect | verify with |
| --- | --- | --- | --- |
| `reset_session` | none | creates a fresh `InkMonGameSession`, resets ItemSystem and GameWorld runtime instances | `state.gold == 100`, `state.state == "OVERWORLD"` |
| `goto_tile` | `{ "q": int, "r": int }` | enqueues an async move command (same path right-click input takes); the 30Hz world tick advances the player cell-by-cell, emitting `actor_position_changed` which the view tweens per step | `state.player_coord` (logic occupant), `state.player_moving`, `state.overworld_3d.move_animation_active`, `state.overworld_3d.player_visual_coord` |
| `open_panel` | `{ "panel": "party"|"bag"|"journal" }` | opens player-owned right drawer tab with slide transition | `state.drawer_mode`, `state.ui_animation.drawer_transition_active` |
| `open_save_load` | none | opens the save/load modal with scale transition | `state.modal_open == true`, `state.ui_animation.modal_transition_active` |
| `run_training_battle` | `{ "max_ticks": int }` | starts a snapshot-backed training battle, ticks it to completion, applies gold reward, returns to overworld | `state.gold > 100`, `last_battle_result.winner_team == "left"`, `active_instance_id == ""` |
| `npc_action` | `{ "npc_id": string, "action_id": string }` | **enqueues** a system NPC handler action command (async, 方案 A); the mutation lands on the next world tick, and training's `start_battle` flow intent starts a deferred battle | poll `state` after a short `wait_frames`: action-specific fields in `state.progression`, `state.roster`, `state.bag`, or `gold` |
| `save_game` | `{ "path": string }` | writes `InkMonGameSession.to_dict()` JSON to `user://` path | `ok == true` |
| `load_game` | `{ "path": string }` | reads JSON, rebuilds session runtime containers, returns to `OVERWORLD` | restored `gold`, `roster`, `progression`, `bag` |

Player-facing UI paths must use raw real input:

- `scene tile_screen_position {"q":2,"r":0}` then raw `click_at` with `button:"right"` moves toward the occupied Shop tile, retargets to an adjacent free tile, starts `overworld_3d.move_animation_active`, and after the animation should set `near_npc_id == "shop"` with `player_visual_coord == player_coord`.
- `click_at` on `layout_state.prompt_button` opens the nearby NPC drawer.
- `click_at` on `layout_state.shop_buy_buttons.minor_rune` enqueues a Minor Rune buy command (方案 A); after a world tick drains it, gold reduces by 10 — poll `state` after a short `wait_frames`, do not assert synchronously.
- `click_at` on `layout_state.npc_action_buttons.start_training_battle` enqueues a training NPC action; the battle starts (deferred, off the drain tick) and completes after a few ticks — poll `state` for `active_instance_id == ""` and `last_battle_result.winner_team`.
- `click_at` on `layout_state.close_button` closes the side sheet.
- `click_at` on `layout_state.tool_buttons.party`, `.bag`, `.journal`, and `.menu` opens the player drawer tabs and save/load modal.

### Raw Bridge Ops

Generic DevAgent ops remain available:

- `capture`
- `inspect_tree`
- `inspect_controls`
- `dump_node`
- `click_at`
- `drag_at`
- `tap_key`
- `wait_frames`

## Expected Runtime Check

```jsonl
{"id":"01","op":"scene","name":"state"}
{"id":"02","op":"scene","name":"run_training_battle","args":{"max_ticks":8}}
{"id":"03","op":"scene","name":"state"}
{"id":"04","op":"inspect_tree","root":"/root/InkMonMain/WorldHost","max_depth":3}
{"id":"05","op":"scene","name":"npc_action","args":{"npc_id":"cultivation","action_id":"cultivate_lead"}}
{"id":"05b","op":"wait_frames","frames":6}
{"id":"06","op":"scene","name":"save_game","args":{"path":"user://inkmon_l2_devagent_save.json"}}
{"id":"07","op":"scene","name":"load_game","args":{"path":"user://inkmon_l2_devagent_save.json"}}
```

Pass criteria:

- command `01` returns `state == "OVERWORLD"` and `gold == 100`
- command `02` returns `ok == true`
- command `03` returns `gold > 100`, `active_instance_id == ""`, and `last_battle_result.winner_team == "left"`
- command `04` writes a node tree artifact

UI input check:

```jsonl
{"id":"10","op":"scene","name":"reset_session"}
{"id":"11","op":"scene","name":"tile_screen_position","args":{"q":2,"r":0}}
{"id":"12","op":"click_at","x":<tile x>,"y":<tile y>,"button":"right"}
{"id":"13","op":"scene","name":"state"}
{"id":"14","op":"wait_frames","frames":45}
{"id":"15","op":"scene","name":"state"}
{"id":"16","op":"scene","name":"layout_state"}
{"id":"17","op":"click_at","x":<prompt cx>,"y":<prompt cy>}
{"id":"18","op":"wait_frames","frames":12}
{"id":"19","op":"scene","name":"layout_state"}
{"id":"20","op":"click_at","x":<minor_rune buy cx>,"y":<minor_rune buy cy>}
{"id":"20b","op":"wait_frames","frames":6}
{"id":"21","op":"scene","name":"state"}
```

Pass criteria: command `13` shows `overworld_3d.move_animation_active == true`;
command `15` shows `near_npc_id == "shop"` and
`overworld_3d.player_visual_coord == player_coord`; the drawer opens through a
real prompt click, and after the buy command drains (`wait_frames` at `20b`,
方案 A 异步写) gold becomes `90` with a `minor_rune` item in `bag`.

Player-owned UI input check:

```jsonl
{"id":"30","op":"scene","name":"layout_state"}
{"id":"31","op":"click_at","x":<party tool cx>,"y":<party tool cy>}
{"id":"32","op":"scene","name":"state"}
{"id":"33","op":"wait_frames","frames":12}
{"id":"34","op":"scene","name":"state"}
{"id":"35","op":"click_at","x":<bag tool cx>,"y":<bag tool cy>}
{"id":"36","op":"scene","name":"state"}
{"id":"37","op":"click_at","x":<journal tool cx>,"y":<journal tool cy>}
{"id":"38","op":"scene","name":"state"}
{"id":"39","op":"click_at","x":<menu tool cx>,"y":<menu tool cy>}
{"id":"40","op":"scene","name":"state"}
{"id":"41","op":"wait_frames","frames":12}
{"id":"42","op":"scene","name":"state"}
```

Pass criteria: command `32` shows
`ui_animation.drawer_transition_active == true`, command `34` shows
`drawer_mode == "party"` and transition finished, `drawer_mode` changes through
`bag` and `journal`, command `40` shows `ui_animation.modal_transition_active ==
true`, and command `42` shows `modal_open == true` after the transition.
