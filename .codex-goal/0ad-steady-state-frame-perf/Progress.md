# 0AD Lab Steady-State Frame Performance Progress

## 2026-05-09

### Baseline Handoff

- Short-path visibility 优化已完成并归档；旧目标不再作为当前入口。
- 当前用户实测稳定 `avg_step_usec` 约 `500-600us`，先视为可接受基线，但需要
  用 warm / percentile / idle / stage 数据验证，而不是只看 lifetime avg。
- 当前阶段只做诊断和数据支撑，不先推进 async worker / 多线程，也不通过运动参数
  或碰撞参数压平均值。

### Initial Implementation

- 新增 example-layer helper：
  `addons/sim-nav-map/examples/0ad-rts-pathfinding-lab/logic/zero_ad_rts_lab_perf_summary.gd`
- frontend export 开始记录：
  `warm_avg_step_usec`、`p95_step_usec`、`p99_step_usec`、`idle_avg_step_usec`、
  slow frame stage counts。
- exploration playthrough summary 开始记录同一组稳定指标，并为 slow frames
  输出 dominant stage / stage counts。
- export / exploration summary 增加 stage average：
  `stage_avg_usec`、`warm_stage_avg_usec`、`idle_stage_avg_usec`。
- README 当前入口已改为 `docs/steady-state-frame-performance-plan.md`，旧
  short-path 文档保留在 `docs/archive/`。

### Verification

- [x] `./tools/run_tests.ps1 zeroadlab/smoke simnav/smoke`
  - PASS 28 / FAIL 0 / TIMEOUT 0
- [x] 0AD lab exploration playthrough
  - Log: `.claude/tmp/0ad-steady-state-exploration.log`
- [x] 默认交互场景 export log
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/Inkmon/zero_ad_rts_lab_steady_state_default_export.json`
- [x] 将实测数据写回 steady-state plan
- [x] 给出下一阶段优化判断

### Recorded Data

Default export after 720 simulated frontend steps:

| Metric | Value |
|---|---:|
| `avg_step_usec` | 355.98 |
| `warm_avg_step_usec` | 263.17 |
| `p95_step_usec` | 762 |
| `p99_step_usec` | 820 |
| `idle_avg_step_usec` | 13.26 |
| `max_step_usec` | 6705 |
| `slow_frame_count` | 0 |

Selected exploration data:

| Phase | warm avg | p95 | p99 | max stage |
|---|---:|---:|---:|---|
| `0_idle_default_scene` | 12.17 | 13 | 54 | bookkeeping |
| `1_baseline_open_movement` | 675.29 | 780 | 809 | path_request |
| `4_fully_blocked_path` | 646.35 | 751 | 850 | path_request |
| `9_partial_wall_with_gap` | 615.99 | 726 | 828 | path_request |
| `8_rapid_obstacle_thrash` | 2572.91 | 4139 | 5362 | path_request |

### Decision

- 当前 `0.5-0.6ms` 稳定 avg 记录为可接受基线。
- 正常移动期 warm avg 主要由 movement loop 贡献，refresh 是下一层常驻成本；
  push / diagnostics 目前不是第一优先级。
- path request 仍主导 max frame，但没有主导 steady avg，也没有在最新 exploration
  形成 `8ms` slow frame。
- async / 多线程不进入下一阶段 immediate plan；只有当未来 p95/p99 或 slow frames
  明确被 path request 顶起来时再设计。
- dynamic blocker thrash 仍独立未解决，不能用本次 steady-state 诊断混称为完成。
