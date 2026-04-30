# known-issues/

跨 feature 周期、跨 commit 仍存在的"已识别但未修"问题文档。

每个文件命名 `YYYY-MM-DD-<slug>.md`，独立成篇，包含：现象 / 关键报错 / 直接定位的代码事实 / 推断根因（标注是否确证）/ 影响范围 / 修复候选方案 / follow-up 清单。

与 `archive/<slug>/Summary.md` 里的"残余风险"段的区别：archive 是**单个 feature 完成时的快照**，仅在那个 feature 上下文有意义；known-issues 是**长期问题**，独立于任何 feature，可能在多次 feature 推进中被反复触碰，需要单独立项处理。

## 当前列表

- [2026-04-30-hex-demo-shutdown-segfault.md](2026-04-30-hex-demo-shutdown-segfault.md) — hex-atb-battle headless demo 战斗结束后 signal 11 段错误（exit 139），未确证根因。AC5 半通过来源
