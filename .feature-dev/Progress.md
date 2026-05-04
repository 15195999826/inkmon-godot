# Progress

**Status**: ⚠️ M7 archived 但 user demo 反馈 motion 设计仍有严重问题 — **等下次 session 重新评估 motion 整体方案**。

最近 archive:[`archive/2026-05-05-rts-m3-m7-unit-motion/`](archive/2026-05-05-rts-m3-m7-unit-motion/Summary.md)(M7 UnitMotion 双轨整合 cutover;rts/all 53/53 PASS;baseline P1 接受)

## 🔴 User demo 反馈(2026-05-05 第 2 会话末)

**测试场景**:demo_rts_pathfinding,8 unit 同时移动到 3 building 凹陷中心。

**用户反馈**:
1. 单位重叠极其严重(M7d.4 baseline)+ 穿越
2. M7d.5 整合 RtsUnitSteering 后**仍重叠**(截图看到只有 5 个红圈 ≠ 8 unit,多个完全重叠)
3. **远不如 M6 时期版本**(原 nav_agent + RtsUnitSteering + step 4 完整管线)

**已尝试的 fix**(都不够):
- M7d.5 commit `fabbd52`:motion.tick 拆 handle_path_update + _step,RtsMotionComponent.tick 在两步之间插 RtsUnitSteering.apply,procedure step 4g 传 spatial_hash。smoke_move_units_command pairwise 0 → 8.20 px(改善但 < 24 阈值)。
- 53/53 smoke PASS 不能反映 demo 真实多 unit 拥挤场景。

## 下次 session 候选方向

详见 [`Handoff-2026-05-05-m7-broken-recommend-m8.md`](Handoff-2026-05-05-m7-broken-recommend-m8.md)。

**我的判断 + 推荐:直接做 M8 push pass**(M3 Epic 最后 milestone)。理由:RtsUnitSteering 是 sep_force hack 不是真 push pass;反复 fix 都引入 trade-off 迟早被 M8 替换;M8 完成 = M3 Epic 收口。

备选(如果 user 不想等 M8):
1. **回退到 M7c 末态**:`git -C addons/logic-game-framework reset --hard 0646c31` + 主仓 reset 7a18670;重新设计 M7d
2. **Dual-wire 渐进式**:nav_agent + motion 并存
3. **回退 M7d 全部**:demo 用 nav_agent,主线 stuck

## M7d 末态 git 状态

- 主仓 HEAD = `b4cb679`(WIP M7d.5b bump submodule;motion._step 永不 snap)
- submodule HEAD = `533080b`(M7d.5b motion._step 永不 snap;-Required 12/12 PASS)
- archive 入口:`archive/2026-05-05-rts-m3-m7-unit-motion/Summary.md`(M7d.4 末态快照,Summary 补 M7d.5 + .5b 增量)
- Handoff:[`Handoff-2026-05-05-m7-broken-recommend-m8.md`](Handoff-2026-05-05-m7-broken-recommend-m8.md)
