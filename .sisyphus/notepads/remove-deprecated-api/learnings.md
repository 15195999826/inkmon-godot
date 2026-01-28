## [2026-01-29T09:10:00Z] Tasks 1-2 Complete

### 完成内容
- ✅ Task 1: 迁移 stage_cue_action.gd (1 处)
- ✅ Task 2: 迁移 recording_utils.gd (8 处)

### 迁移模式
所有旧 API 调用改为：
```gdscript
GameEvent.EventClass.create(...).to_dict()
```

### 特殊处理
- ActorSpawned.create() 需要 (actor_id, actor_data)，不能直接传 actor 对象
- 使用 `actor.to_dict()` 获取 actor_data

### 验证
- ✅ 编译通过
- ✅ 无 SCRIPT ERROR

### Commit
- `d8b20e2` refactor(stdlib): migrate to strongly-typed event API


## [2026-01-29T09:12:00Z] Task 3 Complete - ALL DEPRECATED CODE REMOVED

### 完成内容
- ✅ Task 3: 删除 game_event.gd 中所有 @deprecated 函数

### 删除统计
- 删除行数: 157 行 (第 388-544 行)
- 删除函数: 22 个
  - 11 个 create_xxx_event() 工厂函数
  - 11 个 is_xxx_event() 类型守卫函数
- 文件大小: 545 行 → 385 行 (-29%)

### 验证结果
- ✅ grep "@deprecated" 返回 0 结果
- ✅ 编译通过，无 SCRIPT ERROR
- ✅ 文件行数正确 (385 行)

### Commit
- `[hash]` refactor(core): remove all deprecated event factory functions

### BREAKING CHANGE
旧的工厂函数不再可用，必须使用强类型 API：
```gdscript
// ❌ 旧方式（已删除）
GameEvent.create_actor_spawned_event(actor)

// ✅ 新方式（唯一方式）
GameEvent.ActorSpawned.create(actor.id, actor.to_dict()).to_dict()
```

