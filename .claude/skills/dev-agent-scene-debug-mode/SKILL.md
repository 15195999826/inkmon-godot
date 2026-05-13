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

## Workflow

1. Run `git status -sb` and preserve unrelated dirty work.
2. Identify the real input path for the target scene:
   - UI: `Control`, `Button`, `_gui_input`, focus, modal state.
   - Gameplay: `_input`, `_unhandled_input`, raycast/controller methods.
   - Camera/viewport: root viewport vs `SubViewport` coordinates.
3. Decide operations:
   - Keep `click_at`, `drag_at`, `tap_key`, `capture`, `inspect_controls`, `inspect_tree`, and `dump_node` as raw generic bridge ops.
   - Add scene ops only for small named accelerators, such as `select_unit`, `dump_scene_state`, or `click_hex`.
   - If the goal is UI/player experience validation, scene ops must translate to real input or expose read-only state; do not call button callbacks or gameplay commands directly.
4. Add the smallest adapter:
   - Put reusable changes in `addons/lomolib/dev_agent/` only when they are generic.
   - Put scene-specific adapter code beside the target scene or in an example/adapter folder owned by that scene.
   - Extend `res://addons/lomolib/dev_agent/dev_agent_scene_ops.gd` or implement the same `get_supported_ops()` / `run_scene_op(op_name, args)` protocol.
   - Wire `DevAgentBridge` as an opt-in development node, not as production gameplay logic.
5. Document how to run the scene, where `inbox.jsonl` and `outbox.jsonl` are printed, and which scene ops are supported.
6. Validate with a live development session when possible:
   - Launch the scene in editor/windowed Godot.
   - Append JSONL commands to `inbox.jsonl`.
   - Confirm `outbox.jsonl` records structured results.
   - Confirm screenshots/dumps are under `user://dev-agent/sessions/<session-id>/`.

## Non-Goals

- Do not add DevAgent to `tools/run_tests.ps1`, CI, or required smoke groups.
- Do not turn DevAgent into deterministic PASS/FAIL regression infrastructure.
- Do not expose it as a production or player-facing feature.
- Do not put target-game policy into generic `addons/lomolib/dev_agent`.
- Do not bypass real UI/player input paths for UX validation.

## Completion Checklist

- The target scene remains runnable without DevAgent enabled.
- `capture`, `click_at` or `tap_key`, and `inspect_controls` work through JSONL.
- Any scene op is small, named, documented, and does not pollute the generic bridge.
- Artifacts are easy to open from globalized paths in `outbox.jsonl`.
- Targeted parse/smoke checks were run and recorded in the handoff or progress doc.
