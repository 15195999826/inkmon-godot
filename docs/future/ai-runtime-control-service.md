# AI Runtime Control Service（未来实现）

> 本文记录一个**未来能力**：让外部 AI 通过专用 runtime service 像玩家一样操作主游戏，并获得逻辑正确的世界/界面观察。
> 当前不实现，等主游戏基础架构进一步稳定后再落地。本文只锁设计边界，避免后续把它误做成 DevAgent、UI 自动点击或第二套游戏逻辑。

---

## 0. 定位

AI Runtime Control Service 是主游戏的**专用控制面**，不是调试桥。

- 不复用 `DevAgentBridge`；DevAgent 仍只服务开发调试 / 截图 / inspection。
- 不模拟鼠标点击来驱动主游戏；AI 调正式玩家行为接口。
- 不在 Python / TypeScript / MCP 层重写游戏规则；Godot/GDScript 仍是游戏真相。
- 不进入 Web/WASM bridge 的 `Simulation.tscn`；目标是主游戏 `InkMonMain.tscn` / `InkMonWorldHost`。

运行形态：

```text
MCP client / AI
  -> thin MCP server (TS/Python)
    -> WebSocket text + JSON
      -> Godot: InkMonAiRuntimeServer.gd
        -> PlayerActionPort
          -> WorldAction / ViewAction / HostAction
```

MCP 层只是 adapter：声明工具、发送 WebSocket 请求、等待 Godot 返回结果。权威协议与完成判定都在 Godot 侧。

---

## 1. 通信协议

### 选择

- **Transport**：WebSocket
- **Payload**：JSON text
- **执行模型**：Godot 侧 FIFO queue + single active request；MCP v1 single-flight，同步等待响应。

选择理由：

- AI 操作频率低，JSON 成本可忽略。
- MCP 外层本身接近 JSON-RPC，继续用 JSON 可减少协议转换。
- WebSocket 自带 message framing；避免 raw TCP 的半包 / 粘包 / length-prefix 维护成本。
- 双工连接保留主动通知空间，但 v1 先以 request/response 为主。

暂不选 TCP binary / 自定义协议。只有在观察包很大、操作频率很高或 JSON 成为 profiler 热点时再考虑。

### 请求形状

```json
{
  "id": "req_001",
  "type": "act",
  "action": "move_to",
  "args": { "q": 2, "r": 0 }
}
```

观察请求：

```json
{
  "id": "req_002",
  "type": "observe"
}
```

### 响应形状

```json
{
  "id": "req_001",
  "ok": true,
  "ready_for_next_action": true,
  "result": {
    "action": "move_to",
    "final_coord": { "q": 2, "r": 0 }
  },
  "state": {},
  "screen": ""
}
```

`ready_for_next_action == true` 是 Godot 对外承诺：这个请求已经完成，AI 可以发下一个动作。

---

## 2. 队列与完成判定

Godot 侧必须维护自己的队列，不能只依赖 MCP 客户端“不要并发”的约定。

```text
incoming request
  -> append FIFO queue
  -> if no active request, start next
  -> execute until Godot says complete
  -> send response
  -> clear active
  -> start next
```

完成判定由 Godot runtime server 决定，不由 MCP / TS / Python 推测。

典型动作的完成语义：

| action | 完成条件 |
|---|---|
| `observe_world` | 当前 AI-visible projection 已生成 |
| `move_to(q,r)` | 玩家停止移动，或移动失败 |
| `interact_npc(npc_id, action_id)` | 对应 world command 已 drain，结果已回流 |
| `buy_item(config_id)` | buy command 已 drain，gold / bag 已刷新 |
| `open_panel(panel)` | view state 进入目标 panel，必要动画可选择等到结束 |
| `open_save_modal` | modal 可见，状态稳定 |
| `save_slot(slot)` | IO 完成 |
| `load_slot(slot)` | world 重建、presentation 重新绑定完成 |
| `start_training_battle` | 战斗与必要回放结束，回到可行动状态 |

如果未来允许 AI 中断动作（例如移动中改目标），要作为独立 action 语义设计；默认不通过并发请求实现中断。

---

## 3. PlayerActionPort

AI 不直接调用 UI node，也不直接改 `InkMonWorldGI`。AI 只能调用 `PlayerActionPort` 暴露的玩家行为。

`PlayerAction` 不是全等于 `InkMonWorldCommand`。主游戏现有规划已明确：纯 UI 态不算 world command，也不进存档。故分三类：

```text
PlayerAction
  ├─ WorldAction  -> submit(InkMonWorldCommand)
  ├─ ViewAction   -> Presentation 本地 UI 状态
  └─ HostAction   -> InkMonWorldHost 控制面
```

### WorldAction

改变游戏世界态，必须走现有 CQRS 写侧：

- `move_to(coord)` -> `submit(InkMonMoveCommand)`
- `buy_item(config_id)` -> `submit(InkMonBuyCommand)`
- `npc_action(npc_id, action_id)` -> `submit(InkMonNpcActionCommand)`

### ViewAction

只改变玩家可见界面，不改世界真相：

- `open_panel("party"|"bag"|"journal")`
- `close_drawer()`
- `open_save_modal()`
- `close_modal()`
- 未来可能包括 camera / tab / tooltip 类行为

这些继续住 Presentation / UI 子场景脚本，不塞进 `InkMonWorldCommand`。

### HostAction

控制世界生命周期或 flow，不属于 world command：

- `save_slot(slot)`
- `load_slot(slot)`
- `new_game()`
- 未来的 session 选择 / reset

这类动作由 `InkMonWorldHost` 仲裁。

---

## 4. AI Observation Projection

AI 需要“看见游戏”，但不应另写一套 ASCII UI 逻辑。正确做法是构造一个 AI-visible projection：

```text
World state + Presentation state
  -> InkMonAiObservationProjector
    -> structured state
    -> ascii screen
    -> available actions
```

同一份真相输出两种视图：

- `state`：结构化字段，供 AI 精确读取。
- `screen`：ASCII 文本，让 AI 获得类似玩家视角的空间/界面上下文。

示例：

```text
== OVERWORLD ==
Gold: 100
Party: [Flameling Lv3 HP 42/42] [Mosslet Lv2 HP 31/35]

      .   .   .
    .   @   S
      .   C   .
    T   .   .

@ Player
S Shop
C Cultivation
T Trainer

Panel: closed
Near NPC: shop
Available actions:
- move_to(q,r)
- interact_npc("shop", action_id)
- open_panel("party"|"bag"|"journal")
```

ASCII projection 的纪律：

- 不判断规则，不改状态。
- 不成为第二套 UI 状态。
- 不从视觉节点反推游戏真相。
- 世界信息来自 `IWorldQuery` / world snapshot。
- 界面信息来自 Presentation view state。
- 可用动作来自 `PlayerActionPort` 的同一套 action registry。

第一版只覆盖 overworld + drawer/modal 文本即可。battle replay / inventory 细节后续按需要扩展。

---

## 5. MCP 层边界

MCP server 只做薄 adapter：

- 暴露明确 tool schema：如 `observe_world`、`act_move_to`、`act_interact_npc`。
- 把 tool call 转成 Godot WebSocket request。
- 等 Godot 返回 `ready_for_next_action`。
- 返回 Godot 的 `result/state/screen`。

MCP server 不做：

- 不计算路径。
- 不判断 NPC 是否可互动。
- 不修改存档。
- 不缓存世界真相。
- 不复制 GDScript 校验逻辑。

可以保留一个 `send_raw_request` 作为开发期 escape hatch，但正式 AI workflow 应使用具名工具。

---

## 6. 与现有架构的关系

- 继承现有 CQRS：WorldAction 仍通过 `IWorldQuery.submit(InkMonWorldCommand)` 进入 tick drain。
- 保留 UI 本地态边界：ViewAction 不进 `InkMonWorldCommand`，不进存档。
- 保留 Host 控制面边界：save/load/new-game 仍由 `InkMonWorldHost` 负责。
- 保留 DevAgent 边界：DevAgent 是调试能力，不是玩家/AI runtime 协议。
- 保留 Web bridge 边界：`Simulation.tscn` 是 Web/WASM 技能验证桥，不是主游戏 AI 控制面。

---

## 7. 未来实现顺序

等主游戏基础架构更稳定后再做，建议顺序：

1. 新增 `PlayerActionPort`，先包现有玩家可执行行为，不引入网络。
   - **（2026-07-02 记）做这一步时顺带收编 Presentation root 的输入路由**：root（`ink_mon_world_presentation.gd`）里的人类输入处理（`_input` 热键 / 右键移动 / prompt 点击 / tool 按钮）与 AI 指令应路由到**同一个** PlayerActionPort——人类键鼠和 AI 都是"玩家动作"的两个来源。这样输入路由重构只做一遍（单独先拆再为 AI 拆是两遍税），也是 §6 下放的最后一块（modal/drawer 已于同日下放完毕）。
2. 新增 `InkMonAiObservationProjector`，输出 `state + screen + available_actions`。
3. 新增 `InkMonAiRuntimeServer.gd`，实现 WebSocket + FIFO + single active request。
4. 新增薄 MCP server，把 tool call 透传到 Godot runtime protocol。
5. 写主游戏 runtime smoke：启动主场景，AI 执行 observe -> move -> interact -> observe，验证顺序和状态。

---

## 8. Open Questions

- ViewAction 是否等待 UI 动画结束，还是状态进入目标值即可返回？
- `available_actions` 是只列当前可执行动作，还是同时列禁用动作与原因？
- battle replay 对 AI 是完整播放、可跳过，还是返回战斗摘要 + 可选 ASCII replay？
- 是否允许 AI 中断移动并改目标？如果允许，应设计为明确 action，而不是并发请求。
- 该 service 是只在 editor/dev build 启用，还是未来也允许随本地桌面版开启？
