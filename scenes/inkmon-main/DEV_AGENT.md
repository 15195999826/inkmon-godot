# InkMon Main - DevAgent Contract

## Scene Classification

Business/data-flow runtime validation plus real-input checks for the corrected
3D overworld, right-click hex movement, NPC drawer, player panels, and
save/load modal.

## Launch

```powershell
$env:SESS_NAME = "inkmon-main-runtime"
$env:SESS_DIR = "$env:APPDATA\Godot\app_userdata\Inkmon\dev-agent\sessions\$env:SESS_NAME"
New-Item -ItemType Directory -Force -Path $env:SESS_DIR | Out-Null
godot --path . res://scenes/inkmon-main/InkMonMain.tscn -- --dev-agent --dev-agent-session=$env:SESS_NAME > "$env:SESS_DIR\godot.log" 2>&1
```

The scene prints `inbox` and `outbox` global paths when DevAgent is enabled.

## Scene Ops

### Observation

| op | args | data |
| --- | --- | --- |
| `state` | none | `state`, `gold`, `roster_size`, `roster`, `progression`, `player_coord`, `near_npc_id`, `active_npc_id`, `drawer_open`, `drawer_mode`, `modal_open`, `bag`, `overworld_3d`, `last_move_result`, `active_instance_id`, `last_battle_result`, `game_world`, `events` |
| `layout_state` | none | viewport and clickable rects for prompt, drawer close, NPC action buttons, Shop buy buttons, top-right tool buttons, drawer tabs, and save/load modal buttons |
| `tile_screen_position` | `{ "q": int, "r": int }` | screen coordinate for a 3D hex tile center, used with raw `click_at` + `button:"right"` |

### Action

| op | args | effect | verify with |
| --- | --- | --- | --- |
| `reset_session` | none | creates a fresh `InkMonGameSession`, resets ItemSystem and GameWorld runtime instances | `state.gold == 100`, `state.state == "OVERWORLD"` |
| `goto_tile` | `{ "q": int, "r": int }` | direct business/data move through the same `InkMonOverworldMoveController` used by right-click input | `state.player_coord`, `state.last_move_result.data.move_events` |
| `open_panel` | `{ "panel": "party"|"bag"|"journal" }` | opens player-owned right drawer tab | `state.drawer_mode` |
| `open_save_load` | none | opens the save/load modal | `state.modal_open == true` |
| `run_training_battle` | `{ "max_ticks": int }` | starts a snapshot-backed training battle, ticks it to completion, applies gold reward, returns to overworld | `state.gold > 100`, `last_battle_result.winner_team == "left"`, `active_instance_id == ""` |
| `npc_action` | `{ "npc_id": string, "action_id": string }` | runs a system NPC handler action for smoke/data validation | action-specific fields in `state.progression`, `state.roster`, `state.bag`, or `gold` |
| `save_game` | `{ "path": string }` | writes `InkMonGameSession.to_dict()` JSON to `user://` path | `ok == true` |
| `load_game` | `{ "path": string }` | reads JSON, rebuilds session runtime containers, returns to `OVERWORLD` | restored `gold`, `roster`, `progression`, `bag` |

Player-facing UI paths must use raw real input:

- `scene tile_screen_position {"q":2,"r":0}` then raw `click_at` with `button:"right"` moves toward the occupied Shop tile, retargets to an adjacent free tile, and should set `near_npc_id == "shop"`.
- `click_at` on `layout_state.prompt_button` opens the nearby NPC drawer.
- `click_at` on `layout_state.shop_buy_buttons.minor_rune` buys Minor Rune and should reduce gold by 10.
- `click_at` on `layout_state.npc_action_buttons.start_training_battle` starts and completes the Training battle.
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
{"id":"04","op":"inspect_tree","root":"/root/InkMonMain","max_depth":3}
{"id":"05","op":"scene","name":"npc_action","args":{"npc_id":"cultivation","action_id":"cultivate_lead"}}
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
{"id":"14","op":"scene","name":"layout_state"}
{"id":"15","op":"click_at","x":<prompt cx>,"y":<prompt cy>}
{"id":"16","op":"scene","name":"layout_state"}
{"id":"17","op":"click_at","x":<minor_rune buy cx>,"y":<minor_rune buy cy>}
{"id":"18","op":"scene","name":"state"}
```

Pass criteria: the real right-click path retargets next to Shop, `near_npc_id == "shop"`,
the drawer opens through a real prompt click, and gold becomes `90` with a
`minor_rune` item in `bag`.

Player-owned UI input check:

```jsonl
{"id":"20","op":"scene","name":"layout_state"}
{"id":"21","op":"click_at","x":<party tool cx>,"y":<party tool cy>}
{"id":"22","op":"scene","name":"state"}
{"id":"23","op":"click_at","x":<bag tool cx>,"y":<bag tool cy>}
{"id":"24","op":"scene","name":"state"}
{"id":"25","op":"click_at","x":<journal tool cx>,"y":<journal tool cy>}
{"id":"26","op":"scene","name":"state"}
{"id":"27","op":"click_at","x":<menu tool cx>,"y":<menu tool cy>}
{"id":"28","op":"scene","name":"state"}
```

Pass criteria: `drawer_mode` changes through `party`, `bag`, and `journal`,
then `modal_open == true` after the Menu click.
