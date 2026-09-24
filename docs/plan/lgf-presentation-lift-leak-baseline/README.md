# 泄漏直方图基线（LGF 表演管线上提，PL0 开工前烤制）

hex 前端冒烟 `addons/logic-game-framework/example/hex-atb-battle/tests/frontend/smoke_frontend_main.tscn`
（demo_frontend.tscn → core 战斗 → 录像 → Director / Scheduler / RenderWorld 播到排空）跑一次
`godot --headless --verbose`，按 `Leaked instance:` 行统计（脚本同核心计划 §2，只换场景）：

```bash
mkdir -p .claude/tmp/leak
godot --headless --verbose --path . addons/logic-game-framework/example/hex-atb-battle/tests/frontend/smoke_frontend_main.tscn > .claude/tmp/leak/hex-frontend.txt 2>&1
grep -o "Leaked instance: [A-Za-z0-9_]*" .claude/tmp/leak/hex-frontend.txt | sort | uniq -c | sort -rn > .claude/tmp/leak/hex-frontend.hist.txt
diff .claude/tmp/leak/hex-frontend.hist.txt docs/plan/lgf-presentation-lift-leak-baseline/hex-frontend.hist.txt
```

| 文件 | 场景 | 基线 |
|---|---|---|
| `hex-frontend.hist.txt` | `example/hex-atb-battle/tests/frontend/smoke_frontend_main.tscn` | **零泄漏，文件为空**（2026-09-24 PL0，Godot 4.7） |

格式约束：`Leaked instance:` 行只打原生类名（`RefCounted` / `Node` / `GDScript` / `WeakRef`），
不带脚本类名，所以直方图只能按原生类计数——表演框架件（Director 是 Node；State / Stepper / Registry /
Translator / VisualAction / Updater 全是 RefCounted）与 view 节点混在同一个桶里。基线是零，所以每阶段验收的
判据就是「仍为空」：出现任何一行都是本轮引入的泄漏，先按 D6 的 `_exit_tree` 断连 / 清引用排查。

**下降后要棘轮**：基线已是零，没有下降空间；若某阶段把别的场景也烤进本目录，同样以文件内容逐字节比对。
