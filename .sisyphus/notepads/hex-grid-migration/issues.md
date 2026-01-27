# Issues - hex-grid-migration

## 已知问题
（暂无）

## Task 1 遗留问题

### 1. as_context() 方法暂时禁用
- **文件**: render_world.gd:370
- **原因**: VisualizerContext 构造函数仍需要 FrontendHexGridConfig，但 RenderWorld 已改用 GridLayout
- **影响**: battle_director.gd:272 调用 _world.as_context() 会失败
- **解决方案**: 需要同步修改 visualizer_context.gd（Task 2）
- **临时措施**: as_context() 返回 null 并打印错误

### 2. 单文件修改的局限性
- **问题**: render_world.gd 和 visualizer_context.gd 紧密耦合，无法真正单文件修改
- **建议**: 后续任务应将两者作为一个原子单元处理


## Task 1 遗留问题 - 已解决 ✅

### 1. as_context() 方法已恢复
- **修复**: visualizer_context.gd 已迁移到 GridLayout
- **状态**: render_world.gd:370 的 as_context() 已恢复正常
- **验证**: 两个文件编译通过

### 2. 接口变更影响
- **变更**: `get_hex_config()` → `get_layout()`
- **影响范围**: 无其他文件调用（grep 验证）
- **结论**: 接口变更安全

