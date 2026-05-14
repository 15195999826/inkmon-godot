---
name: run-dev-scene
description: Drive a DevAgent-enabled Godot scene (e.g. skill_preview) autonomously to verify a feature, balance change, or bug. Use this skill whenever the user wants to test/verify/validate/check any in-game behaviour (skill damage, animations, cooldowns, passives, balance numbers, reproductions) AND a DevAgent-enabled scene exists in the repo — even if they do not explicitly say "dev mode". Common phrasings: "用 dev 模式/DevAgent/dev session 测试 X", "用 skill_preview 验证 Y", "test the new fireball", "verify Z cooldown", or any prompt that names a known dev scene as the verification vehicle. The skill launches the scene, sends JSONL ops through DevAgent, reads outbox, reports findings, then stops the process. Do NOT use this skill to ADD DevAgent to a new scene — that is `dev-agent-scene-debug-mode`'s job.
---

# Run Dev Scene

Use this skill when the user wants to **use** an existing DevAgent-enabled Godot scene to validate game behaviour autonomously, without manually clicking the editor. The discovery, op vocabulary, and observation strategy below are scene-agnostic — every DevAgent scene drops a `DEV_AGENT.md` next to its `.tscn` describing its own ops, and this skill is the framework around using whichever one is relevant.

## Step 1: Discover available dev scenes

The repo can hold multiple DevAgent-enabled scenes. Each places a `DEV_AGENT.md` next to its `.tscn`. At the start of every session run:

```
glob: addons/**/DEV_AGENT.md
```

Each `DEV_AGENT.md` is the per-scene contract: launch path, op tables (action / setup / observation / raw input), scene-specific snapshot semantics, known caveats. **Read the relevant `DEV_AGENT.md` before sending any op** — op names and snapshot field names are not portable across scenes (one scene's `state` might be another's `dump_world`).

If only one `DEV_AGENT.md` exists, use it. If several exist and the user did not name one, pick the scene matching the user's domain words (e.g. "skill" → `skill_preview`) or ask one short question.

## Step 2: Confirm intent + launch

Restate what you understood in one short line so the user can course-correct early. Don't queue a checklist — proceed.

> "Going to drive skill_preview, verify skill_fireball damage on 1 caster + 2 enemies. Will stop the scene when done."

Then launch in background:

```bash
SESS_NAME="<short-task-slug>"        # e.g. fireball-dmg-check, thorn-passive-verify
SESS_DIR="$APPDATA/Godot/app_userdata/Inkmon/dev-agent/sessions/$SESS_NAME"
rm -rf "$SESS_DIR" && mkdir -p "$SESS_DIR"
godot --path C:/GodotPorjects/inkmon-godot \
  res://<path/to/scene.tscn> \
  -- --dev-agent --dev-agent-session=$SESS_NAME \
  > "$SESS_DIR/godot.log" 2>&1
```

Use the Bash tool with `run_in_background: true`. Wait until `outbox.jsonl` exists before sending the first op (typically 1–3 seconds after launch).

## Step 3: Discover op vocabulary (zero-cost)

Send ONE cheap scene op first — the scene's snapshot op (named per its `DEV_AGENT.md`, often `scene_state` / `state` / `dump_state`). Every response carries `data.supported_ops`, which is the complete op list for this scene. Cross-reference with `DEV_AGENT.md` for semantics.

Don't guess op names; don't speculatively loop. The first response gives you the whole vocabulary.

## Step 4: Configure → trigger → observe

The skeleton is the same across scenes; only op names vary.

1. **Configure**: load_preset and/or set initial state via mutation ops. Verify with the snapshot op before triggering.
2. **Pre-check**: send the scene's setup-error / validation op. If non-empty, fix the config and re-check before triggering.
3. **Trigger**: send the scene's action op (`start_battle` / `play` / `tick`, etc.).
4. **Wait**: send `wait_for_idle` (or scene equivalent). Don't use `wait_frames` with a hardcoded count — frame rate is unreliable when the window is unfocused, and the wait will either be too short (false negative) or wastefully long.
5. **Observe** structured data first: snapshot, world_state, timeline, console_log. The fields you need are usually direct (`damage`, `hp`, `frame`); read them, don't guess from screenshots.
6. **Capture** is the tie-breaker, not the default. Use it only when the validation target is genuinely visual: VFX position, animation frame, sprite swap, layout regression. The default 960×540 JPEG is plenty for the vision model; override `width` / `format: "png"` only when you need pixel precision.

## Step 5: Handle failures explicitly

When an op returns `ok: false`, read `data` and `message` — they are designed to tell you what to do next:

- `setup_error` non-empty → fix the config, re-run pre-check before triggering.
- `actually_hovered` field on a `click_control` failure → the target Control is z-ordered below another Control. If the test's goal is logic validation (not UX), switch to the scene's direct action op. If the goal IS UX, report the obstruction to the user; the input path needs fixing in the scene, not worked around here.
- `wait_for_idle` timeout → battle stuck or animator hung. Dump `console_log` and the last `timeline` events for clues, then report.

If a sequence of ops all succeed but the resulting state contradicts the user's expectation, **that is the finding**. Report it precisely: which field, expected value, actual value, location in `timeline` or `world_state`.

## Step 6: Summarize + stop

Write a 3–6 line summary to the user:

- **Config** (1 line): what setup you used.
- **Action** (1 line): what you triggered.
- **Result** (2–3 lines): the numbers that mattered, cited from outbox (damage, hp, frame count, key events, anomalies).
- **Verdict** (1 line): matches expectation, or doesn't — and why.

Then `TaskStop` the godot process by default. Leave it running only if the user said "leave the session" / "我自己看" / "保留 session", or asked for iterative variant comparisons.

## What the user needs to provide

Don't over-ask. Only request missing required pieces; pick reasonable defaults for the rest and proceed.

| Info | Required? | Default if omitted |
|---|---|---|
| Which scene (only if >1 dev scene exists and request is ambiguous) | situational | match user's domain words |
| What skill / passive / mechanic | yes | — |
| What outcome to verify | yes | — |
| Actor setup | no | scene's first builtin preset |
| Stats (atk/hp/etc) | no | preset values |
| Evidence to collect | no | snapshot + timeline + console_log; capture only if visual |

One short question is fine when a required field is missing. Don't enumerate the optional fields back to the user.

## Anti-patterns

- **Sending JSONL before reading `DEV_AGENT.md`.** Op names and snapshot field names are scene-specific; guessing leads to wasted ops and confusion. Read the doc first.
- **Hardcoding `wait_frames: 300`.** Use `wait_for_idle` (or scene equivalent). If the scene lacks one, flag the gap to the user — don't paper over it with a longer hardcoded wait.
- **Defaulting to `capture` for state observation.** Structured ops cost ~5× less in vision tokens than a screenshot conveying the same scene, and they're machine-comparable across runs. Pictures break ties; they don't lead.
- **Leaving the godot process running silently after the summary.** Process keeps an OS window and GPU resources alive; the user won't always notice. Call `TaskStop` unless explicitly told to leave it.
- **Editing files in `addons/`, `scripts/`, or `.claude/skills/` during a dev test run.** The running Godot has loaded scripts at process start; mid-run edits don't take effect until restart. Observations would mix old code's runtime behaviour with new code's expected behaviour — confusing and wrong. Report the bug, let the user decide the fix, restart to verify.

## Cleanup

`user://dev-agent/sessions/` is never auto-cleaned. The cleanup helper lives at `.claude/skills/dev-agent-scene-debug-mode/cleanup-sessions.ps1`. Don't run it proactively — suggest it only if the user mentions disk usage or you notice many old session directories.

## Worked example

A complete trace, so the steps above have a concrete shape.

**User says:**
> "用 dev 模式验证 skill_thorn passive，看 caster atk=80 时反弹 30% 是否正确"

**Step 1 — Discover.** `glob: addons/**/DEV_AGENT.md` → only `skill_preview` exists. Read its `DEV_AGENT.md`; note ops `load_preset`, `set_actor_atk`, `set_actor_passives`, `setup_error`, `start_battle`, `wait_for_idle`, `scene_state`, `world_state`, `timeline`, `console_log`.

**Step 2 — Confirm + launch.**
> "Driving skill_preview, will verify skill_thorn reflects 30% of caster atk=80. Stopping when done."

Launch godot in background with `--dev-agent --dev-agent-session=thorn-30pct-check`.

**Step 3 — Op vocabulary.** Send `{"op":"scene","name":"scene_state"}`. Response's `data.supported_ops` confirms the op list matches what `DEV_AGENT.md` listed. Proceed.

**Step 4 — Configure → trigger → observe.**

```jsonl
{"id":"01","op":"scene","name":"load_preset","args":{"name":"[builtin] 03_thorns_reflect"}}
{"id":"02","op":"scene","name":"set_actor_atk","args":{"idx":0,"atk":80}}
{"id":"03","op":"scene","name":"setup_error"}
{"id":"04","op":"scene","name":"start_battle"}
{"id":"05","op":"scene","name":"wait_for_idle","args":{"timeout_frames":600}}
{"id":"06","op":"scene","name":"timeline","args":{"max_events":30}}
{"id":"07","op":"scene","name":"world_state"}
```

`outbox` shows: `03` returns `error: ""` (ok to trigger); `05` returns `idle after 134 frames`; `06`'s events contain an enemy→caster `damage` event of 80, then a caster→enemy reflect `damage` of 24; `07` confirms enemy `hp: 76, max_hp: 100`.

**Step 5 — Failures.** None this run.

**Step 6 — Summarize.**
> "Configured: caster atk=80, skill_thorn passive, 1 enemy (preset 03). Triggered `start_battle`, idle after 134 frames. Result: enemy dealt 80 dmg to caster; thorn reflected 24 (= 80×0.30) back. Enemy hp 100→76. ✅ Matches expected 30% reflect."

Then `TaskStop` the godot process.
