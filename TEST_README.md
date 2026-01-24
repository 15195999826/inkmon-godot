# 测试说明

## AutoLoad 配置

由于 Godot 4.6 的 AutoLoad 机制，运行测试前需要先在编辑器中正确配置。

### 步骤

1. **打开 Godot 编辑器**
   ```bash
   cd D:/GodotProjects/inkmon/inkmon-godot
   godot
   ```

2. **进入项目设置**
   - 点击 `项目` 菜单
   - 选择 `项目设置`

3. **配置 AutoLoad**
   - 左侧选择 `AutoLoad` 标签
   - 添加以下 4 个单例：

| 名称 | 路径 |
|------|------|
| `Log` | `res://addons/logic-game-framework/core/utils/Logger.gd` |
| `IdGenerator` | `res://addons/logic-game-framework/core/utils/IdGenerator.gd` |
| `GameWorld` | `res://addons/logic-game-framework/core/world/GameWorld.gd` |
| `TimelineRegistry` | `res://addons/logic-game-framework/core/timeline/Timeline.gd` |

4. **保存并重启编辑器**
   - 点击 `关闭` 保存设置
   - 重启 Godot 编辑器

## 运行测试

### 方法 1：在编辑器中运行

1. 打开 `addons/logic-game-framework/tests/run_tests.gd`
2. 点击 `运行当前场景`（F6）

### 方法 2：命令行运行（编辑器配置后）

```bash
cd D:/GodotProjects/inkmon/inkmon-godot
godot --headless --path . --script res://addons/logic-game-framework/tests/run_tests.gd
```

## 注意事项

- AutoLoad 必须继承自 `Node`
- AutoLoad 类不需要声明 `class_name`
- 配置后必须在编辑器中重启项目
