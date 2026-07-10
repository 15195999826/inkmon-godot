---
name: ui-interaction-smoke
description: UI 交互 smoke 测试约定——用 Viewport.push_input + InputEvent* 真注入鼠标/键盘事件模拟玩家，走完整 gui_input 派发链路。当你即将改动 main_menu / BuildPanel / 任何 Control 子树的交互逻辑、InputManager / 玩家命令链路（拖框选、右键移动、hotkey）、或 UI 切场景 / queue_free / signal 连接，并要写或跑 UI 交互 smoke 验证时使用。
---

# UI 交互 smoke（Claude 自己测 UI 不靠用户）

之前 "UI/场景改动需在编辑器中验证，不能仅靠 headless" 的根因 = 没有"模拟玩家"的手段。现在有了：**`Viewport.push_input` + `InputEvent*` 真注入鼠标/键盘事件**，走完整 `BaseButton.gui_input` / `_input` / `_gui_input` 派发链路，不是 `pressed.emit()` 信号捷径。

> ⚠ 参考 helper `input_helper.gd` 与模板 `smoke_ui_main_menu.gd` 原在 rts-auto-battle 示例内，已随该示例删除（git 历史可考）。技术本身是**引擎级**（`Viewport.push_input` + `InputEvent*` 真注入），任何新 example 需要 UI 交互 smoke 时按下述约定重建一个本地 `InputHelper`（`ensure_window_size` / `click_control` / `click_at` / `drag_at` / `tap_key` / `press_action`）即可。

**何时写 UI 交互 smoke**：
- 改 main_menu / BuildPanel / Minimap / 任何 Control 子树的交互逻辑
- 改 InputManager / 玩家命令链路（拖框选、右键移动、WASD pan、hotkey）
- 改 UI 切场景 / queue_free / signal 连接

**约定**：PASS 输出含 `(real mouse input)` 后缀做标记。

**关键约定**：
1. `_ready` 第一行 `InputHelper.ensure_window_size(self)` —— headless 默认 64×64，Control 锚点居中后 rect 全在 viewport 外，鼠标判定 "未击中任何 Control"
2. `instantiate UI` 后 `await get_tree().process_frame` × 2 让 Control layout pass 算出 `global_rect`
3. click 前缓存要 print 的 Control 元数据（如 `button.name`），切场景 `queue_free` 后 Control 立即 invalid
4. 入口 `_finish_fail` 必走 `quit(1)` —— SCRIPT ERROR 中断 `_ready` 不会自动退出，demo 会一直跑战斗循环假卡死
