## InkMonBattle2DActionScheduler - 动作调度器
##
## 管理 VisualAction 的生命周期和进度更新（并行执行 + delay）。平移自 hex frontend
## （见 docs/adr/0006）。RenderWorld 管"状态"，本调度器管"时序"。
class_name InkMonBattle2DActionScheduler
extends RefCounted


# ========== 活跃动作数据结构 ==========

class ActiveAction:
	var id: String
	var action: InkMonBattle2DVisualAction
	var elapsed: float
	var progress: float
	var is_delaying: bool

	func _init(p_id: String, p_action: InkMonBattle2DVisualAction) -> void:
		id = p_id
		action = p_action
		elapsed = 0.0
		progress = 0.0
		is_delaying = p_action.delay > 0.0


# ========== Tick 结果数据结构 ==========

class TickResult:
	var active_actions: Array[ActiveAction] = []
	var completed_this_tick: Array[ActiveAction] = []
	var has_changes: bool = false


# ========== 属性 ==========

var _active: Dictionary = {}
var _next_id: int = 0


# ========== 公共方法 ==========

## 添加动作（立即并行执行，考虑 delay）
func enqueue(actions: Array[InkMonBattle2DVisualAction]) -> void:
	for visual_action: InkMonBattle2DVisualAction in actions:
		var id := "action_%d" % _next_id
		_next_id += 1
		_active[id] = ActiveAction.new(id, visual_action)


## 每帧更新所有活跃动作进度，清理已完成
func tick(delta_ms: float) -> TickResult:
	var result := TickResult.new()
	var completed_ids: Array[String] = []

	for id in _active.keys():
		var active_action: ActiveAction = _active[id]
		var action := active_action.action
		var delay := action.delay

		active_action.elapsed += delta_ms

		if active_action.elapsed < delay:
			active_action.is_delaying = true
			active_action.progress = 0.0
			result.has_changes = true
			continue

		active_action.is_delaying = false
		var effective_elapsed := active_action.elapsed - delay

		if action.duration > 0.0:
			active_action.progress = minf(1.0, effective_elapsed / action.duration)
		else:
			active_action.progress = 1.0

		result.has_changes = true

		if effective_elapsed >= action.duration:
			active_action.progress = 1.0
			result.completed_this_tick.append(active_action)
			completed_ids.append(id)

	for id in completed_ids:
		_active.erase(id)

	for id in _active.keys():
		result.active_actions.append(_active[id])

	result.has_changes = result.has_changes or result.completed_this_tick.size() > 0
	return result


func get_active_actions() -> Array[ActiveAction]:
	var actions: Array[ActiveAction] = []
	for id: String in _active.keys():
		actions.append(_active[id] as ActiveAction)
	return actions


## 取消所有动作（重置播放器状态）
func cancel_all() -> void:
	_active.clear()


func get_action_count() -> int:
	return _active.size()
