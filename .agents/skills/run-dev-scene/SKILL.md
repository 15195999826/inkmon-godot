---
name: run-dev-scene
description: Drive a DevAgent-enabled Godot scene (e.g. skill_preview) autonomously to verify a feature, balance change, or bug. Trigger when the user asks to "use dev mode / DevAgent / dev session" to test, validate, or check game behaviour, or names a known dev scene (skill_preview, etc.) as the verification vehicle. The skill launches the scene, sends JSONL ops, reads outbox, and reports findings. Do NOT use this skill to ADD DevAgent to a new scene — that is `dev-agent-scene-debug-mode`'s job.
---

# Run Dev Scene

Use this skill when the user wants to **use** an existing DevAgent-enabled Godot scene to validate game behaviour autonomously, without manually clicking the editor.

Trigger phrases (any of):
- "用 dev 模式 / DevAgent / dev session 测试 / 验证 ..."
- "起 skill_preview dev session ..."
- "用 skill_preview 测试 / 验证 ..."
- "run DevAgent on / drive <scene> ..."
- Explicit mention of the scene name (e.g. `skill_preview`) as a verification vehicle.

## Step 1: Discover available dev scenes

The repo can hold multiple DevAgent-enabled scenes. Each one places a `DEV_AGENT.md` next to its `.tscn`. To discover them:

```
grep / glob: addons/**/DEV_AGENT.md
```

Each `DEV_AGENT.md` is the per-scene contract: launch command, op tables (action / setup / observation / raw input), scene-specific snapshot semantics, and known caveats. **Read the relevant `DEV_AGENT.md` before sending any op** — op names and snapshot field names are not portable across scenes.

If the user did not name a scene and only one `DEV_AGENT.md` exists, use it. If several exist, ask which one (one short question) or pick the one matching the user's domain words (e.g. "skill" → `skill_preview`).

## Step 2: Confirm intent in one short line, then go

State what you understood in one line so the user can correct you if wrong. Example:

> "Going to drive skill_preview, verify skill_fireball damage on 1 caster + 2 enemies. Will stop the scene when done."

Then proceed without further confirmation. Don't queue a checklist message — the user already knows the broad shape, they want the result.

## Step 3: Launch

```bash
SESS_NAME="<short-task-slug>"        # e.g. fireball-dmg-check, thorn-passive-verify
SESS_DIR="$APPDATA/Godot/app_userdata/Inkmon/dev-agent/sessions/$SESS_NAME"
rm -rf "$SESS_DIR" && mkdir -p "$SESS_DIR"
godot --path C:/GodotPorjects/inkmon-godot \
  res://<path/to/scene.tscn> \
  -- --dev-agent --dev-agent-session=$SESS_NAME \
  > "$SESS_DIR/godot.log" 2>&1
```

Always run in background (`run_in_background: true` on the Bash tool). Wait until `outbox.jsonl` exists before sending ops.

## Step 4: Discover op vocabulary (zero-cost)

Send ONE cheap scene op first (e.g. `{"op":"scene","name":"state"}` or whatever the scene's snapshot op is named per `DEV_AGENT.md`). Every response carries `data.supported_ops` — that's the complete op list for this scene. Cross-reference with `DEV_AGENT.md` for semantics.

Don't guess op names; don't loop sending speculative names. Read `supported_ops`.

## Step 5: Configure → trigger → observe loop

Generic loop (concrete op names vary per scene):

1. **Configure**: load_preset or set initial state via mutation ops. Verify with snapshot op.
2. **Pre-check**: send `setup_error` (or scene equivalent). If non-empty, fix and re-check before triggering action.
3. **Trigger**: send action op (`start_battle` / `play` / `tick` / whatever the scene calls it).
4. **Wait**: send `wait_for_idle` (or scene equivalent). Don't use `wait_frames` with a hardcoded count — frame rate is unreliable when the window is unfocused.
5. **Observe**: send snapshot op, world_state, timeline, console_log (per scene). Read the structured data first.
6. **Picture (last resort)**: `capture` only if the validation target is genuinely visual (VFX position, animation frame, layout). Default JPEG 960×540 is enough; only override format/width if you need pixel precision.

## Step 6: Handle failures explicitly

- Any op returns `ok: false`: read `data` and `message` carefully. Common causes and signals:
  - `setup_error` non-empty → fix config before triggering.
  - `actually_hovered` field on click_control failure → another Control is z-ordered above; the target is unreachable via click. Switch to the direct action op for this scene if its goal is logic validation, otherwise report to user.
  - `wait_for_idle` timeout → battle stuck or hang; dump console_log and report.
- Multiple ops in a row succeed but the resulting state contradicts the user's expectation → that IS the finding. Report it precisely (which field, expected vs actual).

## Step 7: Summarize + stop

Write a 3–6 line summary to the user:
- What was configured (1 line).
- What was triggered (1 line).
- The result, with numbers from outbox (2–3 lines: damage, hp, frame count, key events, anomalies).
- Verdict: matches expectation / doesn't match (specify why).

Default: stop the godot process (`TaskStop`) when done. Do NOT leave it running.

Exceptions to "stop by default":
- User said "leave the session for me" / "我自己看" / "保留 session".
- User asked for an iterative loop (multiple variants to compare).

## What the user needs to provide

Don't over-ask. Ask only the missing required pieces.

| Info | Required? | Default if omitted |
|---|---|---|
| Which scene (if >1 dev scene) | yes (only if ambiguous) | — |
| What skill / passive / mechanic | yes | — |
| What outcome to verify | yes | — |
| Actor setup | no | scene's first builtin preset |
| Stats (atk/hp/etc) | no | preset values |
| Evidence to collect | no | snapshot + timeline + console_log; capture only if visual |

One question is OK if a required field is missing. Don't enumerate optional fields — pick reasonable defaults and proceed.

## Anti-patterns

- **Sending JSONL before reading `DEV_AGENT.md`**. Op names are not portable; you will guess wrong.
- **Hardcoding `wait_frames: 300`**. Use `wait_for_idle` (or scene equivalent). If the scene lacks one, that is a gap to flag back to the user.
- **Defaulting to `capture` for state observation**. Structured ops cost 5–10× less in tokens and are machine-comparable. Pictures are tie-breakers.
- **Leaving the godot process running silently**. The user will not notice; resources leak. Always `TaskStop` after the summary unless told otherwise.
- **Editing files in `addons/`, `scripts/`, or `.claude/skills/` during a dev test run**. This skill is read-only on the codebase; if the test reveals a bug, report it and let the user decide on the fix.

## Cleanup

After many dev test runs `user://dev-agent/sessions/` accumulates. The cleanup helper lives in `.claude/skills/dev-agent-scene-debug-mode/cleanup-sessions.ps1`. Suggest running it if the user mentions disk usage; don't run it proactively.

## Quick reference: currently known dev scenes

Run `glob: addons/**/DEV_AGENT.md` at the start of each session — the list below is a snapshot at skill-write time.

| Scene | Path | Goal classification |
|---|---|---|
| `skill_preview` | `addons/logic-game-framework/example/hex-atb-battle/skill-preview/skill_preview.tscn` | Business / presentation — verify skill damage, animation, timeline, passives |
