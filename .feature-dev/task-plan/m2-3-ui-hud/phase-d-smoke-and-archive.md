# Phase D — smoke_ui_main_menu + 全套 validation + 收口 + archive

> 父 plan: [`README.md`](README.md)
>
> Status: 🔄 active (Phase C 收口后落)

---

## Scope

为 main_menu → demo apply_preset 链路加 1 个 headless smoke; 跑全套 14 + 1 = 15 项 validation 0 漂移; 整体收口主仓 + 入口文档; archive M2.3 + M2 milestone.

---

## 子任务 (D.1 → D.5)

### D.1 — smoke_ui_main_menu.{gd,tscn}
- 新文件 `tests/frontend/smoke_ui_main_menu.{gd,tscn}`
- 实例化 main_menu.tscn → add_child → await frame → 找第一个 Button → emit pressed → await frame → 验 parent 内有 demo 节点 + demo._preset != null + main_menu freed
- 输出 `SMOKE_TEST_RESULT: PASS|FAIL`

### D.2 — Validation 全套 14 + 1 = 15 项
- 14 baseline 项 + smoke_ui_main_menu = 15 项, 0 漂移

### D.3 — 主仓 + 入口文档 sweep
- `.feature-dev/Current-State.md` → 更新到 M2.3 末态 (BuildPanel + minimap + main_menu 全落)
- `task-plan/m2-roadmap.md` M2.3 status ✅ done; M2 整体加完成节点
- 主仓 `CLAUDE.md` 测试入口表加 smoke_ui_main_menu
- LGF addon `CLAUDE.md` 视情况同步 (无新 architecture, 不必动)

### D.4 — archive 快照
- `archive/2026-05-03-rts-m2-3-ui-hud/` 包含:
  - Summary.md (M2.3 + M2 milestone 收口)
  - Current-State.md / Next-Steps.md / Progress.md 当前快照
  - task-plan/ 完整快照 (含 phase-a/b/c/d 全四个 .md)

### D.5 — Next-Steps + task-plan/README 切回 waiting + final commit
- Next-Steps.md → "已完成 M2.3 系统功能验收, 等待用户确认下一个 feature"
- task-plan/README.md → 切回 waiting/index 状态 (像 M2.2 archive 后的样子)
- final commit (主仓 + submodule)

---

## 验收准则 (5 AC)

### AC1 — smoke_ui_main_menu PASS 🔒 pending
- 新 smoke_ui_main_menu.tscn headless exit 0 + SMOKE_TEST_RESULT: PASS
- 验证: main_menu instantiate → button emit pressed → demo 加 child + demo._preset 字段 set

### AC2 — Validation 全套 15 项 0 漂移 🔒 pending
- 14 baseline + 1 新 smoke 全过

### AC3 — archive 完整 🔒 pending
- `archive/2026-05-03-rts-m2-3-ui-hud/Summary.md` 概括 M2.3 + M2 milestone (含 M2.1 + M2.2 + M2.3 总结)
- task-plan 全快照 (4 个 phase doc + README)

### AC4 — m2-roadmap M2.3 标 done 🔒 pending
- `task-plan/m2-roadmap.md` M2.3 行 status ✅; M2 milestone 整体加完成节点

### AC5 — Next-Steps + task-plan/README 切回 waiting 🔒 pending
- `Next-Steps.md` 当前目标 = "等待下一个 feature"
- `task-plan/README.md` 切回 waiting/index 状态 (M2.2 archive 后的样子作模板)

---

## 子任务进度 (D.1-D.5)

- [ ] **D.1 — smoke_ui_main_menu.{gd,tscn}** 🔒 pending
- [ ] **D.2 — 全套 15 项 validation** 🔒 pending
- [ ] **D.3 — 主仓 + 入口文档 sweep** 🔒 pending
- [ ] **D.4 — archive 快照** 🔒 pending
- [ ] **D.5 — Next-Steps + task-plan/README 切回 waiting + final commit** 🔒 pending
