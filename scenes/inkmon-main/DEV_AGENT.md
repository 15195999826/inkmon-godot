# InkMon Main - DevAgent Contract

## Scene Classification

Business/data-flow runtime validation plus real-input checks for the current
overworld/NPC side-sheet surface.

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
| `state` | none | `state`, `gold`, `roster_size`, `roster`, `progression`, `player_coord`, `near_npc_id`, `active_npc_id`, `panel_open`, `bag`, `active_instance_id`, `last_battle_result`, `game_world`, `events` |
| `layout_state` | none | viewport and clickable rects for prompt, panel close, generic NPC action buttons, Shop buy buttons, and Training CTA |

### Action

| op | args | effect | verify with |
| --- | --- | --- | --- |
| `reset_session` | none | creates a fresh `InkMonGameSession`, resets ItemSystem and GameWorld runtime instances | `state.gold == 100`, `state.state == "OVERWORLD"` |
| `run_training_battle` | `{ "max_ticks": int }` | starts a snapshot-backed training battle, ticks it to completion, applies gold reward, returns to overworld | `state.gold > 100`, `last_battle_result.winner_team == "left"`, `active_instance_id == ""` |
| `npc_action` | `{ "npc_id": string, "action_id": string }` | runs a system NPC handler action for smoke/data validation | action-specific fields in `state.progression`, `state.roster`, `state.bag`, or `gold` |
| `save_game` | `{ "path": string }` | writes `InkMonGameSession.to_dict()` JSON to `user://` path | `ok == true` |
| `load_game` | `{ "path": string }` | reads JSON, rebuilds session runtime containers, returns to `OVERWORLD` | restored `gold`, `roster`, `progression`, `bag` |

Player-facing UI paths must use raw real input:

- `tap_key {"key":"D"}` moves the player near the Shop and should set `near_npc_id == "shop"`.
- `click_at` on `layout_state.prompt_button` opens the nearby NPC panel.
- `click_at` on `layout_state.shop_buy_buttons.minor_rune` buys Minor Rune and should reduce gold by 10.
- `click_at` on `layout_state.npc_action_buttons.start_training_battle` starts and completes the Training battle.
- `click_at` on `layout_state.close_button` closes the side sheet.

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
{"id":"11","op":"tap_key","key":"D"}
{"id":"12","op":"scene","name":"layout_state"}
{"id":"13","op":"click_at","x":<prompt cx>,"y":<prompt cy>}
{"id":"14","op":"scene","name":"layout_state"}
{"id":"15","op":"click_at","x":<minor_rune buy cx>,"y":<minor_rune buy cy>}
{"id":"16","op":"scene","name":"state"}
```

Pass criteria: `near_npc_id == "shop"`, panel opens through a real click, and
gold becomes `90` with a `minor_rune` item in `bag`.
