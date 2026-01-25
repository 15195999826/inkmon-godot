# Learnings - Godot + Web Battle Integration

## Conventions

## Patterns

## Gotchas

## SimulationManager JS Bridge Implementation

### JS Bridge Registration Pattern (SimulationManager.gd:21-39)
- 使用 `JavaScriptBridge.get_interface("window")` 获取 window 对象
- 使用 `JavaScriptBridge.create_callback()` 创建 GDScript 回调函数
- 通过 `_js_window.godot_xxx = callback` 注册到 JS
- 备用方案：通过 `_js_window.godot_xxx_result` 全局变量传递返回值

### Callback Function Pattern (SimulationManager.gd:42-62)
- 接收 `args: Array` 参数（参数可以是空数组）
- 调用实际业务方法
- 使用 `substr(0, 100)` 截断长字符串用于日志
- 同时返回结果并写入全局变量 `_js_window.godot_xxx_result`

### HexBattle Integration Pattern (SimulationManager.gd:69-94)
```gdscript
var battle := HexBattle.new()
battle.start({})  # 默认配置
while battle.tick_count < battle.MAX_TICKS and not battle._ended:
    battle.tick(dt)
var replay_data := battle.get_replay_data()
var json_str := JSON.stringify(replay_data)
```
- HexBattle.MAX_TICKS = 100
- 使用 `battle._ended` 标志检测战斗结束
- `get_replay_data()` 返回字典，需要用 `JSON.stringify()` 转换

### Local Testing
在非 Web 环境中，可以直接调用 `run_battle()` 方法：
```gdscript
if not OS.has_feature("web"):
    var result = run_battle()
    print("[Godot] Local test result: ", result.substr(0, 200))
```
