# Progress

## Status

Complete.

## Log

- 2026-05-14 15:31 - goal setup - Created active Codex goal for Dota2 lab
  Phase B behavior baseline.
- 2026-05-14 15:37 - smoke implementation - Added
  `smoke_dota2_lab_behavior_baseline` and wired it into `dota2lab/smoke`.
- 2026-05-14 15:37 - smoke validation -
  `./tools/run_tests.ps1 dota2lab/smoke` passed:
  `PASS 3 / FAIL 0 / TIMEOUT 0`.
- 2026-05-14 15:39 - DevAgent verification - Ran
  `codex-dota2-phaseb-20260514-153930` against the Dota2 lab scene with
  rapid right-click target switching and exported final state.
- 2026-05-14 15:44 - submodule commit - Committed `addons` as
  `c0659db Add Dota2 lab Phase B behavior baseline`.

## Phase B Smoke Evidence

Source log:
`C:\GodotPorjects\inkmon-godot\.claude\tmp\test-runs\addons__sim-nav-map__examples__dota2-rts-pathfinding-lab__tests__smoke__smoke_dota2_lab_behavior_baseline.log`

- `default_group_move`: settled in 572 ticks; state counts `IDLE 1`,
  `FAILED 7`; all failed units ended with `max_retry_exceeded`;
  `pending_count=0`, `result_count=0`, `blocked_by_unit_count=47`.
- `narrow_gap_bounded_terminal`: settled in 89 ticks; state counts `FAILED 2`;
  both failures are accepted hard-block terminal `max_retry_exceeded`;
  `pending_count=0`, `result_count=0`, `blocked_by_unit_count=12`.
- `mixed_static_dynamic_obstacle`: settled in 115 ticks; state counts
  `FAILED 4`; all failures are accepted hard-block terminal
  `max_retry_exceeded`; `pending_count=0`, `result_count=0`,
  `blocked_by_unit_count=24`, static obstacle fixture count `2`.

## DevAgent Evidence

Session:
`C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\Inkmon\dev-agent\sessions\codex-dota2-phaseb-20260514-153930`

Artifacts:

- Initial screenshot:
  `C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\Inkmon\dev-agent\sessions\codex-dota2-phaseb-20260514-153930\screenshots\cmd-001-initial.png`
- Rapid-switch screenshot:
  `C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\Inkmon\dev-agent\sessions\codex-dota2-phaseb-20260514-153930\screenshots\cmd-031-after-rapid-switch.png`
- Final screenshot:
  `C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\Inkmon\dev-agent\sessions\codex-dota2-phaseb-20260514-153930\screenshots\cmd-035-final.png`
- Final export:
  `C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\Inkmon\dota2_rts_pathfinding_lab_logs\codex_phaseb_devagent_final_20260514_153930.json`

Final DevAgent metrics:

- `tick_count=2418`
- `state_counts={FAILED:7, IDLE:2, FOLLOWING:0, WAITING_LONG:0, WAITING_SHORT:0}`
- `pending_count=0`
- `result_count=0`
- `result_tickets=[]`
- `cancelled_count=12`
- `stale_result_count=12`
- `blocked_by_unit_count=82`
- `short_path_requests=82`
- Failed units: `blue_0`, `blue_1`, `blue_2`, `blue_3`, `blue_4`, `blue_5`,
  `blue_7`; each has `failure_reason=max_retry_exceeded`.

Interpretation:

- Phase A ticket lifecycle repair is still holding: rapid switching leaves no
  pending queue tickets or orphan result tickets. `stale_result_count=12`
  indicates cancelled old results were observed and discarded, not left in the
  live result queue.
- Remaining `FAILED` units are Phase B accepted hard-block terminal behavior
  under the current no-push/no-yield/no-destination-packing policy.

## Remaining

- None.
