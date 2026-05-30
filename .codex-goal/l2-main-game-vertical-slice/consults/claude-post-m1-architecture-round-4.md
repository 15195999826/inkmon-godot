## 1. 签字结论

✅ **签字同意**，作为 handoff 共识。

第 3 轮的 battle injection blocker 已经被正确收口，关键点都对上了：

- **并行而非静默替换** — snapshot 路径与 unit_key 路径共存，`_setup_teams` snapshot-first + fallback，`inkmon/m1` 保持绿，这正是第 3 轮我卡的那条边界。
- **stats 来源切干净** — snapshot 分支显式 bypass `InkMonUnitConfig`，且 `from_battle_snapshot` / `setup_from_snapshot` 的具体 GDScript 形态留作实现细节是合理的，handoff 层不需要钉死方法签名。
- **`hp = max_hp` at battle start 不入 snapshot** — 把"战斗内血量"和"持久化属性"分层，给未来 carry-over health 留了口子又不污染当前契约，正确。
- **双向 acceptance** — non-default stat smoke（证明属性来自 snapshot）+ M1 default fallback 回归，覆盖了两条路径，符合 [[reference_main_repo_tests]] 的 namespace 约定。
- **不碰 hex-atb-battle example 类** — 与三层依赖方向一致。

Round 2 共识七条原样保留，无回退。

## 2. 剩余 blocker

无 blocker。🟢

> 仅一条非阻塞备注（不影响签字、落地时顺手即可）：snapshot dict 缺字段时的降级行为（如某个 `battle_stats` key 缺失）建议在实现期决定是"crash-fast"还是"补 config 默认值"——这是实现细节，不进 handoff 契约。
