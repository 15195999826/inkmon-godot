# Decisions - hex-grid-migration

## 迁移策略
- **决策**: 完全迁移，删除 FrontendHexGridConfig，统一使用 ultra-grid-map
- **理由**: 消除代码重复，统一坐标转换逻辑

## API 兼容性
- **决策**: 不需要保持向后兼容
- **理由**: 这是内部示例代码，可以自由重构

## Z 轴处理
- **决策**: 保持 Z=0（与旧实现一致）
- **理由**: 旧 FrontendHexGridConfig.hex_to_world() 返回 Vector3(x, 0, y)
