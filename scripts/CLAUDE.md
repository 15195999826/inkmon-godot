# Web / JS 桥接（scripts/）

`SimulationManager._setup_js_bridge()` 注册的 window 回调：
- `godot_greet` — 连通性测试
- `godot_run_battle` — 跑一场战斗
- `godot_test_runtime_script` — 动态加载脚本
- `godot_validate_skill` — 校验 AI 生成技能
- `godot_preview_skill` — 预览技能

只在 `OS.has_feature("web")` 下注册；本地跑会进 headless 测试分支。

录像 JSON 协议：桥接返回 v3 形状（`meta` + `world_snapshot{actors, map_config, position_formats}` + `timeline`，无 version 字段），事件 dict key 与 kind 字面量一律 snake_case（如 `actor_id` / `ability_activate`）。外部仓的 JS 解析器这两点都尚未同步，启用 web 发布时一并升级（`SimulationManager.run_battle` 注释在案）。
