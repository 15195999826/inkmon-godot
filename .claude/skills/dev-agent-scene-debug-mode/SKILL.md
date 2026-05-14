---
name: dev-agent-scene-debug-mode
description: Add DevAgent Debug Mode to a Godot scene by wiring a small scene-specific adapter to addons/lomolib/dev_agent. Use when the user asks to make a scene controllable/debuggable through JSONL commands, screenshots, real input injection, inspect_controls, inspect_tree, dump_node, or scene-specific DevAgent operations. Do not use for CI, regression testing, production/player automation, or bypassing real UI input paths.
---

# DevAgent Scene Debug Mode

Use this skill to add a minimal development-only DevAgent adapter to one Godot scene.

## Required Reads

Before editing, read:

1. `addons/lomolib/docs/dev-agent-debug-mode-spec.md`
2. `addons/lomolib/dev_agent/example/README.md`
3. `addons/lomolib/dev_agent/example/dev_agent_demo.gd`
4. `addons/lomolib/dev_agent/example/demo_scene_agent_ops.gd`
5. The target scene `.tscn` and its main script/input handler.

If the target touches LGF/gameplay classes, also use the repo `gdscript-coding` and `enforcing-lgf` skills.

## Step 0: Classify the dev scene's goal

Before designing scene ops, decide what the AI agent will be asked to **validate** with this scene. This decides whether each op pushes real input or directly calls a function.

| Goal of the dev scene | Examples | Op style |
|---|---|---|
| **Business logic / data flow / presentation** | "Validate new skill's damage and animation timing", "preview battle result given setup", "verify replay determinism" | **Direct function call** |
| **UI operation → UI update loop** | "Click X button, panel Y must rebuild", "right-click hex → popup with correct entries", "drag keyframe → ruler reflects new time" | Direct call **if** the function fully reproduces the UI update chain; otherwise **real input** |
| **UX itself** | "Button position is reachable", "disabled state visual is correct", "modal layer captures input as expected" | **Real input** (the validation target) |

State the classification in the adapter's doc comment so future readers know why a given op is one or the other.

## Step 1: Real input vs direct call — decision tree

```
For each scene op, ask:

What does this op validate?

├─ Business logic / data / animation
│   → Direct function call.
│      The internal guards (is_playing, disabled flags, setup errors) are
│      already in those functions; reuse them. Don't push input just for purity.
│
├─ UI update chain after an interaction
│   ├─ Does the underlying function trigger the *same* UI side effects as a
│   │  real click? (hover styles, focus, popup hit-testing, modal layer,
│   │  clip rects, _gui_input event consumption, gui_get_hovered_control)
│   │
│   ├─ Yes → Direct call. Saves coordinates, removes z-order risk.
│   └─ No  → Real input via Viewport.push_input.
│           Do NOT downgrade to direct call to "avoid bugs" in the input path.
│           Fix the real-input path instead (see "Anti-pattern" below).
│
└─ UX correctness itself
    → Real input. This is the thing being checked, so faking it defeats the test.
```

## Step 2: Anti-pattern — don't bypass real-input bugs with direct calls

When the goal genuinely requires real input (UI loop validation) and `push_input` hits a problem — overlapping `global_rect`, modal layer eating events, `SubViewport` coordinate mismatch — the **wrong** answer is "switch to direct function call". That hides the bug from the AI and from any future human reviewer.

The **right** answers, in order:

1. Pre-click hit-test in the adapter: walk the Control tree and confirm the topmost Control at the click point is the intended target. If not, return `ok=false` with the actually-hit Control's path so the AI sees the obstruction.
2. Adjust the scene's layout / `mouse_filter` / z-order so the target Control is reachable. Document the layout decision.
3. As a last resort, add a `dev_agent_*` API on the scene that exposes the *visible state change*, and have the adapter call it after the real click — so the validation still measures what happened, even if the click itself needed an unusual route.

What you must **not** do: silently route `click_X` to `function_X()` because the click was unreliable. That makes the op name a lie.

## Step 3: Observation strategy — structured ops first, screenshots last

A future AI session driving this scene starts cold. It does NOT know which state fields matter, which op name returns what, or where to look. Make discovery cheap and bias toward structured data — pictures cost ~5× the vision tokens a JSON dump does for the same scene context, and accumulate on disk fast.

### Adapter author obligations

- Expose at least one **state snapshot op** (suggested names: `state`, `scene_state`, `dump_state`). Its return Dictionary should cover:
  - every field the agent might want to mutate later (so it can verify its own edits took effect),
  - every observable runtime field needed to validate the scene's purpose (battle outcome, animation step, UI mode, etc.),
  - stable identifiers (idx, role_id, actor_id, button names) the agent can quote in mutation ops.
- For each action op, write one line in the adapter README naming **which snapshot fields change after success**. The agent should be able to pick the next observation op from that line alone.
- Group ops in DEV_AGENT.md (or equivalent) into:
  1. **Action / mutation** — changes state, returns `ok` + minimal data.
  2. **Observation** — read-only, returns Dictionary, no side effects.
  3. **Raw real-input escape hatch** — `click_at` / `click_control` / `drag_at` / `tap_key`.
- Every scene-op response automatically carries `data.supported_ops`. After a single call the agent has the complete op vocabulary — no separate "list ops" call needed.

### Agent runtime strategy

When driving an unfamiliar dev scene:

1. Send any cheap scene op (e.g. `{"op":"scene","name":"state"}`) once. Read `data.supported_ops` from the response — that's the full op list. Cross-reference against the adapter's DEV_AGENT.md for semantics.
2. After each mutation, send the relevant structured observation op (`state` / `world_state` / `dump_X`). Verify the change against the returned Dictionary, not by looking at a screenshot.
3. Send `capture` ONLY when the validation target is genuinely visual:
   - VFX, animation frame, particle spawn position, sprite swap.
   - Layout regression where Control rects matter and `inspect_controls` is insufficient.
   - A hand-off snapshot for a human reviewer.
4. When in doubt — if a question could be answered by either an op or a screenshot — pick the op. Pictures are tie-breakers, not the default channel.

### Screenshot defaults

The generic `capture` op defaults to **960 px wide JPEG q=80** (~25–40 KB). It accepts:

```json
{"op":"capture","label":"after_battle","width":960,"format":"jpeg","quality":80}
```

- `width: 0` keeps original viewport size; otherwise the longest edge is scaled while preserving aspect.
- `format: "png"` for lossless / pixel-precise regression (file size jumps ~5×).
- Only raise the defaults when you have a concrete reason (small font readability, exact pixel diff). Anthropic vision processes both 1920×1080 and 960×540 by tiling — bigger ≠ more information for the model.

### Cleanup

DevAgent does not auto-clean `user://dev-agent/sessions/`. Sessions accumulate on disk. When they get large, run the bundled cleanup helper:

```powershell
pwsh .claude/skills/dev-agent-scene-debug-mode/cleanup-sessions.ps1
# defaults: delete sessions older than 7 days under %APPDATA%\Godot\app_userdata\Inkmon\dev-agent\sessions
# add -DryRun to preview, -Days N to change the cutoff
```

## Workflow

1. Run `git status -sb` and preserve unrelated dirty work.
2. Apply Step 0 — write down the scene's classification in one line.
3. Identify the real input path for the target scene:
   - UI: `Control`, `Button`, `_gui_input`, focus, modal state.
   - Gameplay: `_input`, `_unhandled_input`, raycast/controller methods.
   - Camera/viewport: root viewport vs `SubViewport` coordinates.
4. Decide operations using the decision tree in Step 1:
   - Always keep `click_at`, `drag_at`, `tap_key`, `capture`, `inspect_controls`, `inspect_tree`, `dump_node` as raw generic bridge ops — these are the escape hatch for UI-loop validation.
   - Scene ops are named accelerators. For business/logic scenes, name them after the action (`start_battle`, `add_enemy`) and implement via direct calls. For UI-loop scenes, name them after the input (`click_save_button`) and implement via real input.
5. Add the smallest adapter:
   - Put reusable changes in `addons/lomolib/dev_agent/` only when they are generic.
   - Put scene-specific adapter code beside the target scene or in an example/adapter folder owned by that scene.
   - Extend `res://addons/lomolib/dev_agent/dev_agent_scene_ops.gd` or implement the same `get_supported_ops()` / `run_scene_op(op_name, args)` protocol.
   - Wire `DevAgentBridge` as an opt-in development node, not as production gameplay logic.
6. Document how to run the scene, where `inbox.jsonl` and `outbox.jsonl` are printed, which scene ops are supported, and what each op's classification is (direct call vs real input).
7. Validate with a live development session when possible:
   - Launch the scene in editor/windowed Godot.
   - Append JSONL commands to `inbox.jsonl`.
   - Confirm `outbox.jsonl` records structured results.
   - Confirm screenshots/dumps are under `user://dev-agent/sessions/<session-id>/`.

## Non-Goals

- Do not add DevAgent to `tools/run_tests.ps1`, CI, or required smoke groups.
- Do not turn DevAgent into deterministic PASS/FAIL regression infrastructure.
- Do not expose it as a production or player-facing feature.
- Do not put target-game policy into generic `addons/lomolib/dev_agent`.
- Do not bypass real-input issues with a direct-call workaround when the validation target is UI behaviour. Fix the real-input path; see Step 2.

## Completion Checklist

- The target scene remains runnable without DevAgent enabled.
- The adapter's doc comment states the scene's classification (Step 0) in one line.
- Each scene op's chosen style (direct call vs real input) matches the decision tree.
- `capture`, `click_at` or `tap_key`, and `inspect_controls` work through JSONL.
- Any scene op is small, named, documented, and does not pollute the generic bridge.
- Artifacts are easy to open from globalized paths in `outbox.jsonl`.
- Targeted parse/smoke checks were run and recorded in the handoff or progress doc.
