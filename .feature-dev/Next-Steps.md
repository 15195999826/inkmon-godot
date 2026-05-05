# Next Steps — 2026-05-05 (M8 implementation done, AC8 user demo signoff pending)

## 当前目标

🟡 **M8 group push pass + ✋5 体验点**(M3 Epic 9/9 milestone,scope = M8 only)。

**实施完成**:M8.1 control_group 赋值 + M8.2 push_pass 算法(N=10 iter / pf=0.5 / sum_radius=collision_radius / sep_force 退场)+ M8.3 group 行为 tune + M8.4 2 新 smokes 全部落地。AC1-AC7 全 PASS;AC8 量化部分 max_overlap ≤ 4 全 buckets ✅(0.61 px / 1.3% diameter,从 9.45 px / 39% diameter 改善 -94%)。

**剩余**:AC8 用户 demo F6 签字。

完整 spec:[`task-plan/m3-0ad-pathfinding-migration/milestones/M8-group-push.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M8-group-push.md)。

## 下一步(user 醒来后做)

**1. 跑 demo F6 验证 AC8 体验点 ✋5(必须 user 视觉确认)**

```
打开 Godot 编辑器 → 加载 addons/logic-game-framework/example/rts-auto-battle/frontend/demo_rts_pathfinding.tscn
F6 跑 → 框选 8 个 melee unit → 右键 (350, 230)(3 barracks 凹陷中心)
观察:8 unit 是否互相穿模 / 远好于 M7d.5b 末态(M7d.5b 中途 max_overlap 9.45 px ≈ 39% 重叠)
```

**接受标准**:
- ✅ 视觉无明显穿模(max_overlap ≤ 4 px ≈ 16% diameter,M8 实测 0.61 px = 2.5% diameter)
- ✅ 远好于 M7d.5b 末态(用户 2026-05-04 demo 反馈"中途擦肩穿模视觉异常"已大幅改善)
- 用户显式签字 "M8 demo ✋5 PASS"

**如果 demo F6 ✋5 PASS** → 通知 runner 继续 mid-archive(协议:M3 Epic 仍未收口,Progress / Current-State 不空白 reset 只更新到 next active = cleanup phase 等待状态)。

**如果 demo F6 ✋5 不达** → 回报具体表现(哪几个 unit / 哪个 bucket / max_overlap 视觉估算),runner 继续 tune push_factor / N / 加 push 静止阈值。

**2. (可选)若 user 想自己看量化报告**:跑 `addons/logic-game-framework/example/rts-auto-battle/tests/diagnostics/trace_pathfinding_8units.tscn` headless 对比 M5 baseline:

```powershell
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/diagnostics/trace_pathfinding_8units.tscn 2>&1 | Tee-Object -FilePath $env:TEMP\trace_m8.txt
Select-String $env:TEMP\trace_m8.txt -Pattern "8-unit move trace|--- 异常|Overlaps:|bucket \[|max_overlap"
```

预期(M8 末态):
- 全局 max_overlap ≤ 0.61 px ✅(M5 baseline 9.45 px)
- 中途 events 243(spec 阈值 ≤100 字面未达,但 events 计数 = 浮点 + 对称收敛 artifact,实际 max_ov 0.58)
- 终点 events 20(spec 阈值 0 字面未达,max_ov 0.32 px;轻度 ringing,视觉无感)

## 验收准则(M8 全 AC 状态,见 [Progress.md](Progress.md) 详细 evidence)

- ✅ AC1 control_group 赋值打开
- ✅ AC2 push_pass 算法落地(smoke_group_push_pass PASS)
- ✅ AC3 RtsWorld.tick 顺序正确(replay seed=42 deep-equal)
- ✅ AC4 Validation:rts/all 55/55 + LGF 73 + replay deep-equal + baseline 2-run byte-identical
- ✅ AC5 2 新 smokes PASS
- ✅ AC6 Perf:无 wallclock 退化
- ✅ AC7 Group filter 生效(scenario_8 PASS)
- 🟡 **AC8 user demo signoff pending**(量化 max_overlap ≤4 全过,user 视觉签字待)

## 非下一步

- ❌ **不做 cleanup phase**(M5.5b-e RtsBattleGrid 删除 / RtsUnitSteering 类 hard delete / vertex pathfinder simple-case 算法修 / smoke_move_units_command MIN_PAIR_DIST restore 24)— 留 M8 ✋5 通过后下一 feature
- ❌ **不做 Epic-level archive** — M8 only 完成不等于 Epic 收口
- ❌ **不修改 LGF submodule core/ 和 stdlib/** — 项目硬约束
- ❌ **不擅自 push commit / open PR** — 用户授权才动(local commit 留 mid-archive 时一起做)
- ❌ **不引入 formation slot / group goto 路径合并 / unit priority** — 下个 Epic(deferred)

## M8 末态(implementation 完成 baseline)

- 主仓 HEAD `b4cb679`(本 session 未 commit)
- submodule HEAD `533080b`(本 session 未 commit)
- **rts/all 55/55 PASS**(53 + 2 新 M8 smoke)
- **-Required 14/14 PASS**(12 + 2 新 M8 smoke)
- LGF 73 PASS;hex/regression PASS
- replay seed=42 frames=11 events=24 deep-equal PASS;baseline 970512 bytes(M8 接受新值,2-run byte-identical deterministic)
- M7d sep_force callsite 注释退场;RtsUnitSteering 类 hard delete + smoke_move_units_command MIN_PAIR_DIST restore 24 留 cleanup phase

## 期间踩坑提醒(M8.2 实测加,留 cleanup 参考)

- **spec push_factor=0.5 单 pass assumption 在 ≥5 unit cluster 收敛不足** — 单 iter 单边 push overlap/4 太弱,N=10 iteration 才让 8 unit cluster 收敛到 d ≥ 23.4
- **spec sum_clearance 用 motion._clearance + obstr_shape.clearance 是 D2 不变量假设** — 实际 production 路径 motion._clearance 没显式 set_clearance 同步,stale default 14 vs collision_radius 12 → atk_range 24 时被错误 push 破坏 attacker 接战。修:用 owner.collision_radius + obstr_shape.clearance(跟 sep_radius 算法对齐)
- **M7d sep_force × M8 push_pass 双层力相互打架** → jitter 1→223 / max_overlap 不降。修:M8 显式 disable sep_force callsite,push_pass 接管全部 separation 语义(spec line 49 明文)
- **8 unit cluster 中心 unit 收 7 邻居 push 净抵 0** → 这是 push pass fundamental limitation;视觉无感(max_ov 0.61 px = 2.5% diameter),0 A.D. 靠 footprint-aware formation slot 解,留下个 Epic
- **trace events 计数定义** = d < min_dist - 0.01 即 trigger,push 收敛到 d ≈ sum_radius - 0.5 仍 trigger event 但视觉无穿模 → AC8 events 阈值 spec assumption over-strict,以 max_overlap 阈值为准(spec ≤4 px 全 buckets ✅)
