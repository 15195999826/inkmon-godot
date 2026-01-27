# Hex ATB Battle Frontend (表演层)

## 项目背景

本项目是 **inkmon** 战斗系统的 **Godot 3D 表演层**实现，用于将逻辑层产生的战斗事件可视化为 3D 动画。

### 设计目标

1. **逻辑表演分离**：逻辑层 (`hex-atb-battle`) 只负责计算，表演层只负责渲染
2. **声明式动画**：通过 `VisualAction` 描述"做什么"，而非"怎么做"
3. **可回放**：支持战斗录像的加载、播放、暂停、重置
4. **跨平台一致**：与 Web 端 (`inkmon-web/lib/battle-replay`) 保持架构一致

### 相关项目

| 项目 | 路径 | 说明 |
|------|------|------|
| **逻辑层** | `addons/logic-game-framework/example/hex-atb-battle/` | 战斗逻辑计算、事件生成 |
| **Web 表演层** | `../inkmon-web/lib/battle-replay/` | TypeScript 实现的参考架构 |
| **本项目** | `hex-atb-battle-frontend/` | Godot 3D 表演层 |

---

## 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                        BattleDirector                           │
│  (Node, 主控制器, 驱动 _process)                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   Replay     │───▶│  Visualizer  │───▶│   Action     │      │
│  │   Data       │    │  Registry    │    │  Scheduler   │      │
│  │  (录像数据)   │    │ (事件翻译器)  │    │  (动作调度)   │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│                                                 │               │
│                                                 ▼               │
│                                          ┌──────────────┐      │
│                                          │   Render     │      │
│                                          │   World      │      │
│                                          │  (状态管理)   │      │
│                                          └──────────────┘      │
│                                                 │               │
│                                                 ▼               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  BattleReplayScene                        │  │
│  │  (Node3D, 3D 场景管理)                                     │  │
│  │  ├── UnitsRoot (单位容器)                                  │  │
│  │  │   └── UnitView (单位视图: 模型 + 血条 + 标签)            │  │
│  │  ├── EffectsRoot (特效容器)                                │  │
│  │  │   └── FloatingTextView (飘字)                          │  │
│  │  ├── CameraRig (相机)                                     │  │
│  │  └── Lighting (光照)                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 核心数据流

```
GameEvent (逻辑事件)
    │
    │  Visualizer.translate()
    ▼
VisualAction (声明式视觉动作)
    │
    │  ActionScheduler.enqueue()
    ▼
ActiveAction (带进度的运行时动作)
    │
    │  ActionScheduler.tick(delta)
    ▼
TickResult { active_actions, completed_this_tick }
    │
    │  RenderWorld.apply_actions()
    ▼
RenderState (渲染状态: 位置、HP、特效等)
    │
    │  BattleReplayScene 读取状态
    ▼
3D 可视化 (UnitView 更新位置/血条/动画)
```

---

## 目录结构

```
hex-atb-battle-frontend/
├── README.md                 # 本文档
├── main.gd                   # 入口脚本
├── main.tscn                 # 入口场景
│
├── core/                     # 核心框架
│   ├── battle_director.gd    # 主控制器 (Node)
│   ├── action_scheduler.gd   # 动作调度器
│   ├── render_world.gd       # 渲染状态管理
│   ├── visualizer_registry.gd # Visualizer 注册表
│   ├── visualizer_context.gd # 只读查询上下文
│   └── animation_config.gd   # 动画配置
│
├── actions/                  # 视觉动作定义
│   ├── visual_action.gd      # 基类 + ActionType 枚举
│   ├── move_action.gd        # 移动动作
│   ├── update_hp_action.gd   # 血条更新
│   ├── floating_text_action.gd # 飘字
│   ├── procedural_vfx_action.gd # 程序化特效
│   └── death_action.gd       # 死亡动画
│
├── visualizers/              # 事件翻译器
│   ├── base_visualizer.gd    # 抽象基类
│   ├── move_visualizer.gd    # 移动事件
│   ├── damage_visualizer.gd  # 伤害事件
│   ├── heal_visualizer.gd    # 治疗事件
│   ├── death_visualizer.gd   # 死亡事件
│   └── default_registry.gd   # 默认注册表工厂
│
├── scene/                    # 3D 场景组件
│   ├── battle_replay_scene.gd # 主场景管理
│   ├── unit_view.gd          # 单位视图
│   └── floating_text_view.gd # 飘字视图
│
├── grid/                     # 坐标系统
│
├── ui/                       # UI 组件
│   └── replay_controls.gd    # 播放控制面板
│
└── test_*.gd/tscn            # 测试脚本/场景
```

---

## 核心类说明

### 1. BattleDirector (`core/battle_director.gd`)

**职责**：整合所有组件，驱动回放流程

```gdscript
class_name FrontendBattleDirector
extends Node

# 信号
signal playback_state_changed(is_playing: bool)
signal frame_changed(current_frame: int, total_frames: int)
signal playback_ended()
signal actor_state_changed(actor_id: String, state: Dictionary)
signal floating_text_created(data: Dictionary)
signal actor_died(actor_id: String)

# 核心方法
func load_replay(replay_data: Dictionary) -> void
func play() -> void
func pause() -> void
func reset() -> void
func set_speed(speed: float) -> void
```

### 2. VisualizerRegistry (`core/visualizer_registry.gd`)

**职责**：管理 Visualizer，将 GameEvent 翻译为 VisualAction[]

```gdscript
class_name FrontendVisualizerRegistry
extends RefCounted

func register(visualizer: FrontendBaseVisualizer) -> void
func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array
```

### 3. ActionScheduler (`core/action_scheduler.gd`)

**职责**：管理动作的生命周期和进度

```gdscript
class_name FrontendActionScheduler
extends RefCounted

func enqueue(action: FrontendVisualAction) -> void
func tick(delta_ms: float) -> TickResult
func clear() -> void
```

### 4. RenderWorld (`core/render_world.gd`)

**职责**：管理渲染状态，应用动作到状态

```gdscript
class_name FrontendRenderWorld
extends RefCounted

signal actor_state_changed(actor_id: String, state: Dictionary)
signal floating_text_created(data: Dictionary)
signal actor_died(actor_id: String)

func initialize_from_replay(replay_data: Dictionary) -> void
func apply_actions(tick_result: FrontendActionScheduler.TickResult) -> void
func get_actor_state(actor_id: String) -> Dictionary
func reset() -> void
```

### 5. VisualAction (`actions/visual_action.gd`)

**职责**：声明式描述视觉效果

```gdscript
class_name FrontendVisualAction
extends RefCounted

enum ActionType { MOVE, UPDATE_HP, FLOATING_TEXT, MELEE_STRIKE, PROCEDURAL_VFX, DEATH }
enum EasingType { LINEAR, EASE_IN, EASE_OUT, EASE_IN_OUT, ... }

var type: ActionType
var actor_id: String
var duration: int      # 毫秒
var delay: int         # 延迟毫秒
var easing: EasingType
```

---

## 事件类型 (来自逻辑层)

| 事件类型 | 字段 | 说明 |
|---------|------|------|
| `move_start` | `actor_id`, `from_hex`, `to_hex` | 单位开始移动 |
| `damage` | `target_actor_id`, `damage`, `source_actor_id`, `is_critical` | 造成伤害 |
| `heal` | `target_actor_id`, `heal_amount`, `source_actor_id` | 治疗 |
| `death` | `actor_id`, `killer_actor_id` | 单位死亡 |

---

## 录像数据格式

```json
{
  "version": "2.0",
  "meta": {
    "battleId": "battle_001",
    "recordedAt": 1706000000,
    "tickInterval": 100,
    "totalFrames": 50,
    "result": "victory"
  },
  "configs": {},
  "initialActors": [
    {
      "id": "actor_1",
      "configId": "warrior",
      "displayName": "Warrior",
      "team": 0,
      "position": { "hex": { "q": -2, "r": 0 } },
      "attributes": { "hp": 100.0, "maxHp": 100.0 },
      "abilities": [],
      "tags": {}
    }
  ],
  "timeline": [
    {
      "frame": 5,
      "events": [
        {
          "kind": "move_start",
          "actor_id": "actor_1",
          "from_hex": { "q": -2, "r": 0 },
          "to_hex": { "q": -1, "r": 0 }
        }
      ]
    }
  ]
}
```

---

## 使用方法

### 基本使用

```gdscript
# 1. 创建回放场景
var replay_scene = FrontendBattleReplayScene.new()
add_child(replay_scene)

# 2. 加载录像
var replay_data = load_replay_json("user://Replays/battle.json")
replay_scene.load_replay(replay_data)

# 3. 控制播放
replay_scene.play()
replay_scene.pause()
replay_scene.reset()
replay_scene.set_speed(2.0)

# 4. 监听信号
var director = replay_scene.get_director()
director.playback_ended.connect(_on_playback_ended)
director.frame_changed.connect(_on_frame_changed)
```

### 添加自定义 Visualizer

```gdscript
# 1. 继承 FrontendBaseVisualizer
class_name MyCustomVisualizer
extends FrontendBaseVisualizer

func can_handle(event: Dictionary) -> bool:
    return event.get("kind") == "my_custom_event"

func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array:
    var action = FrontendFloatingTextAction.new()
    action.actor_id = event.get("actor_id", "")
    action.text = "Custom!"
    action.color = Color.YELLOW
    return [action]

# 2. 注册到 Registry
var registry = FrontendDefaultRegistry.create()
registry.register(MyCustomVisualizer.new())
```

---

## 与 Web 端的对应关系

| Web 端 (TypeScript) | Godot 端 (GDScript) |
|---------------------|---------------------|
| `BattleDirector` (hook) | `FrontendBattleDirector` (Node) |
| `ActionScheduler` | `FrontendActionScheduler` |
| `RenderWorld` | `FrontendRenderWorld` |
| `VisualizerRegistry` | `FrontendVisualizerRegistry` |
| `IVisualizer` | `FrontendBaseVisualizer` |
| `VisualAction` | `FrontendVisualAction` |
| `AnimationConfig` | `FrontendAnimationConfig` |

---

## 已知问题

> 以下问题需要在后续对话中逐一修复

1. **内存泄漏**：退出时有 `ObjectDB instances leaked` 警告
2. **资源未释放**：退出时有 `resources still in use` 错误
3. **单位名称**：UnitView 显示为 `@Node3D@2` 而非实际名称
4. **actor_state_changed 频繁触发**：每帧都在触发，可能需要优化
5. **HP 信息缺失**：actor_state_changed 信号中没有 HP 数据
6. **移动动画**：actor_1 的移动事件似乎没有正确更新位置状态

---

## 测试

```bash
# 编译测试
godot --headless addons/logic-game-framework/tests/frontend/test_compilation.tscn

# 回放流程测试
godot --headless addons/logic-game-framework/tests/frontend/test_replay_flow.tscn

# 3D 可视化测试
godot --headless addons/logic-game-framework/tests/frontend/test_3d_visualization.tscn
```

---

## 下一步计划

1. 修复已知问题
2. 添加更多 Visualizer（skill、stageCue）
3. 增强 3D 特效（粒子、投射物轨迹）
4. 实现镜头跟随
5. 添加音效支持
6. 性能优化（减少不必要的信号触发）
