# LomoLib - Godot 通用函数库

## 概述

LomoLib 是一个 Godot 4.x 通用工具库插件，提供常用的开发工具。

## 功能模块

### 1. InventoryKit - 库存框架系统

从 Unreal Engine 移植的专业库存管理框架，提供灵活的物品和容器管理。

**核心功能：**
- ✅ 权威数据源模式 - 物品系统统一管理所有物品位置
- ✅ 三种槽位管理策略 - 无序/固定槽位/网格容器
- ✅ 容器组件本地缓存 - 优化查询性能
- ✅ 灵活的配置系统 - 支持运行时配置容器类型
- ✅ 完整的信号通知 - 物品移动、添加、移除事件

**快速示例：**
```gdscript
# 创建背包容器（无序，30个格子）
var backpack := BaseContainer.create_unordered(&"Backpack", 30)
var backpack_id := ItemSystem.register_container(backpack)

# 创建装备栏（固定槽位）
var equipment := BaseContainer.create_fixed(&"Equipment", [
    &"Helmet", &"Armor", &"Weapon", &"Shield"
])
var equipment_id := ItemSystem.register_container(equipment)

# 创建物品
var sword_id := ItemSystem.create_item(backpack_id, -1, &"IronSword")

# 移动物品到装备栏
var weapon_slot := equipment.get_space_manager().get_slot_index_by_type(&"Weapon")
ItemSystem.move_item(sword_id, equipment_id, weapon_slot)

# 查询容器中的物品
var items := ItemSystem.get_items_in_container(backpack_id)
print("背包物品: ", items)
```

**文件结构：**
- `types.gd` - 核心类型定义（ItemLocation, ItemInstance, ContainerSpaceConfig）
- `item_system.gd` - 物品系统（AutoLoad 单例，权威数据源）
- `base_container.gd` - 基础容器组件
- `space_manager.gd` - 空间管理器（UnorderedSpaceManager, FixedSlotSpaceManager, GridSpaceManager）
- `void_container.gd` - 虚空容器（ContainerID=0，存放无容器的物品）

### 2. WaitGroup - 多任务同步工具

类似 Go 语言的 `sync.WaitGroup`，用于等待多个异步任务完成。

**核心功能：**
- ✅ 简单的 Add/Done 计数器机制
- ✅ 支持 `await` 协程等待
- ✅ 支持链式回调 `next()`
- ✅ 自动生命周期管理
- ✅ 调试日志支持

**快速示例：**
```gdscript
func load_resources() -> void:
    # 创建 WaitGroup
    var result = WaitGroupManager.create_wait_group(&"LoadResources")
    var wg: LomoWaitGroup = result[1]

    # 添加 3 个任务
    wg.add(3)

    load_texture(wg)
    load_audio(wg)
    load_scene(wg)

    # 等待所有任务完成
    await wg.wait()

    print("所有资源加载完成！")

func load_texture(wg: LomoWaitGroup) -> void:
    await get_tree().create_timer(1.0).timeout
    wg.done(&"LoadTexture")
```

**详细文档：** [WAIT_GROUP_USAGE.md](wait_group/WAIT_GROUP_USAGE.md)

**示例场景：** `res://addons/lomolib/wait_group/wait_group_demo.tscn`

## 安装

1. 将 `addons/lomolib` 文件夹复制到项目中
2. 打开 **项目 → 项目设置 → 插件**
3. 启用 **LomoLib** 插件

## 文件结构

```
addons/lomolib/
├── plugin.cfg                      # 插件配置
├── lomolib.gd                      # 插件主脚本
├── inventoryKit/                   # InventoryKit 模块目录
│   ├── types.gd                    # 核心类型定义
│   ├── item_system.gd              # 物品系统 (AutoLoad)
│   ├── base_container.gd           # 基础容器组件
│   ├── space_manager.gd            # 空间管理器
│   └── void_container.gd           # 虚空容器
├── wait_group/                     # WaitGroup 模块目录
│   ├── wait_group.gd               # WaitGroup 核心类
│   ├── wait_group_manager.gd       # WaitGroup 管理器 (AutoLoad)
│   ├── wait_group_demo.tscn        # 示例场景
│   ├── wait_group_demo.gd          # 示例脚本
│   └── WAIT_GROUP_USAGE.md         # WaitGroup 详细文档
└── README.md                       # 本文件
```

## AutoLoad 单例

启用插件后，会自动注册以下 AutoLoad：

| 名称 | 说明 |
|------|------|
| `ItemSystem` | 物品系统全局管理器（权威数据源） |
| `WaitGroupManager` | WaitGroup 全局管理器 |

## 版本历史

- **v0.2.0** - 新增 InventoryKit 库存框架
  - 从 UE C++ 移植到 GDScript
  - 支持无序/固定槽位/网格三种容器类型
  - 权威数据源模式 + 组件本地缓存
- **v0.1.0** - 初始版本
  - 实现 WaitGroup 多任务同步工具

## 许可证

MIT License

## 作者

lomo
