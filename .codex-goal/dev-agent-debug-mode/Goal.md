# DevAgent Debug Mode

## Objective

Implement the DevAgent Debug Mode described in `addons/lomolib/docs/dev-agent-debug-mode-spec.md`: a development-only bridge that lets Codex drive a real running Godot scene through dynamic commands, real input injection, screenshots, and runtime inspection.

## Deliverables

- `addons/lomolib/dev_agent/` generic bridge, input driver, screenshot helper, inspector, and scene-op adapter base.
- `addons/lomolib/dev_agent/example/` demo scene and README showing a live session with raw input, capture, inspection, and one scene-specific operation.
- Repo-local skill for adding DevAgent Debug Mode to future scenes, referencing the spec and example.
- Minimal documentation updates so future sessions know this is a development debug tool, not a regression test framework.

## Non-Goals

- Do not add DevAgent to CI, `tools/run_tests.ps1 -Required`, or required smoke flows.
- Do not make it a production/player-facing automation feature.
- Do not bypass real UI/player input paths when the goal is UI or user-experience validation.
- Do not attach scene-specific game policy to the generic `lomolib/dev_agent` layer.

## Validation

- Run the demo scene in editor/windowed Godot with DevAgent enabled.
- Send JSONL commands for `capture`, `click_at`, `tap_key`, and `inspect_controls` while the scene stays alive.
- Confirm `outbox.jsonl` contains structured results and artifact paths.
- Confirm screenshots and dumps are written under one `user://dev-agent/sessions/<session-id>/` directory.
- Run targeted GDScript parse/smoke checks available for the created demo; do not treat this as a required regression suite.

## Completion Gate

- A future Codex session can read the spec, run the `lomolib` example, inspect generated artifacts, and use the repo-local skill to add a small DevAgent adapter to a new scene without re-deriving the architecture.

