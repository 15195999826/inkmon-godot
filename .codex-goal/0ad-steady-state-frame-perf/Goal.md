# 0AD Lab Steady-State Frame Performance Goal

## Objective

接替已经完成的 0AD lab short-path visibility 优化，建立稳定运行期的 frame
performance 诊断。

当前目标不是继续用单个 cumulative `avg_step_usec` 判断性能，而是把启动期、
稳定期、空闲期、慢帧和 `world.step()` 内各阶段成本拆开。用真实 export /
exploration 数据判断当前 `0.5-0.6ms` 稳定 avg 是否健康，并决定下一阶段应该
优化 refresh、push、diagnostics、path request 调度，还是暂时不进入 async /
多线程。

## Deliverables

- 归档旧入口：
  `addons/sim-nav-map/examples/0ad-rts-pathfinding-lab/docs/short-path-visibility-optimization-goals.md`
  不再作为当前任务入口。
- 建立当前入口：
  `addons/sim-nav-map/examples/0ad-rts-pathfinding-lab/docs/steady-state-frame-performance-plan.md`
- 为 0AD lab export / exploration summary 增加稳定性能指标：
  - `warm_avg_step_usec`
  - `p95_step_usec`
  - `p99_step_usec`
  - `idle_avg_step_usec`
  - slow frame stage classification
- 记录默认交互场景和 exploration playthrough 的稳定性能数据。
- 基于数据给出下一阶段优化判断：refresh / push / diagnostics / path request /
  async 是否值得进入下一轮。

## Non-Goals

- 不把 async worker / 多线程作为第一阶段方案。
- 不靠 motion 参数、cooldown、缩小 search range、降低碰撞半径来压 avg。
- 不让 long path 引入密集动态单位作为全局路径阻挡。
- 不把 dynamic blocker thrash 混称为已经解决。
- 不继续把已完成的 short-path visibility 文档当当前任务入口。

## Required Verification

- `./tools/run_tests.ps1 zeroadlab/smoke simnav/smoke`
- 运行 0AD lab exploration playthrough，记录新增稳定性能指标。
- 导出默认交互场景 log，确认 export 能直接回答稳定 avg、p95、p99、idle avg
  和 slow frame 主要阶段。

## Completion Gate

- 当前文档入口清晰：旧 short-path 文档归档，新 steady-state plan 成为当前入口。
- export / exploration 不再只能看 cumulative avg，而能区分启动期和稳定期。
- 当前 `0.5-0.6ms` 稳定 avg 被记录为可接受基线。
- 下一步优化方向有数据支撑，而不是基于单个 avg 或偶发 max frame 猜测。
- async / 多线程是否进入后续阶段有明确判断依据。
