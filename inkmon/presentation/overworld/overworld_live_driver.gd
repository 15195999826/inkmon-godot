class_name InkMonOverworldLiveDriver
extends Node

## 主世界 live 表演 driver（adr/0007）。
##
## 与 battle 的 InkMonBattle2DAnimator 同构（持共享 RenderWorld + ActionScheduler +
## VisualizerRegistry，逐事件 translate → scheduler → apply → 投影到共享 avatar），
## 但事件源是 **live WorldGI 信号**而非冻结 replay 时间线：无帧图 / 无 total_frames /
## 无 playback_ended，每帧 pump 一次。坐标全用逻辑 axial，本类是唯一 hex→像素边界。
##
## avatar 的 style（player/npc 配色）由 caller seed 时给（view 概念），driver 缓存按需懒建。
## NPC 高亮缩放是 view-local，不走这里（view 拿 avatar 自己缩）。

const OVERWORLD_MOVE_DURATION := 220.0
## axial 位移 → 六向编号（契约六向,母版向 3 = (-1,+1);与 InkMonMapLoader
## PATCH_WALL_NEIGHBOR 同表反查——smoke_overworld_unit_walk 覆盖口径）。
const DIRECTION_OF_DELTA := {
	Vector2i(1, -1): 0, Vector2i(0, -1): 1, Vector2i(-1, 0): 2,
	Vector2i(-1, 1): 3, Vector2i(0, 1): 4, Vector2i(1, 0): 5,
}

signal avatar_spawned(actor_id: String, avatar: InkMonRender2DAvatar)

var _grid: InkMonRender2DBakedHexMap = null
var _units_root: Node2D = null
var _fx_root: Node2D = null

var _render_world: InkMonRender2DRenderWorld = null
var _scheduler: InkMonRender2DActionScheduler = null
var _registry: InkMonRender2DVisualizerRegistry = null

var _avatars: Dictionary = {}   # actor_id -> InkMonRender2DAvatar
var _styles: Dictionary = {}    # actor_id -> InkMonRender2DAvatar.Style
var _pending: Array[Dictionary] = []
var _live := false              # _process 是否 pump（测试走 step()，不开 live）
## T7 M4 走格动画:actor 最近一步的六向（enqueue_move 时按 axial 位移查表）。
var _move_dirs: Dictionary = {}


func setup(grid: InkMonRender2DBakedHexMap, units_root: Node2D, fx_root: Node2D) -> void:
	_grid = grid
	_units_root = units_root
	_fx_root = fx_root
	_rebuild_world()


func _rebuild_world() -> void:
	var cfg := InkMonRender2DAnimationConfig.new()
	cfg.move_duration = OVERWORLD_MOVE_DURATION
	_render_world = InkMonRender2DRenderWorld.new(cfg)
	_scheduler = InkMonRender2DActionScheduler.new()
	_registry = InkMonOverworldRegistry.create()
	_render_world.actor_state_changed.connect(_on_actor_state_changed)
	_render_world.actor_despawned.connect(_on_actor_despawned)


# ========== live 控制 ==========

func start_live() -> void:
	_live = true


func stop_live() -> void:
	_live = false


# ========== seed / 移动 / 快照 ==========

## seed 一个 actor（caller 给 overworld avatar style）。hp 缺省 → dormant。
func seed_actor(actor_id: String, display_name: String, hex: HexCoord, style: InkMonRender2DAvatar.Style) -> void:
	_styles[actor_id] = style
	_render_world.seed_actor(actor_id, display_name, hex)


## 入队一步移动（逐格,由 actor_position_changed 驱动）。latest-wins：先 cancel 该 actor 在途移动。
func enqueue_move(actor_id: String, from_hex: HexCoord, to_hex: HexCoord) -> void:
	if _scheduler != null:
		_scheduler.cancel_for_actor(actor_id)
	# 六向朝向（单位动画用;非相邻位移(跨格 snap 类)保持上一朝向）。
	var delta := Vector2i(to_hex.q - from_hex.q, to_hex.r - from_hex.r)
	if DIRECTION_OF_DELTA.has(delta):
		_move_dirs[actor_id] = int(DIRECTION_OF_DELTA[delta])
	_pending.append({
		"kind": "inkmon_move_start",
		"actor_id": actor_id,
		"from_hex": {"q": from_hex.q, "r": from_hex.r},
		"to_hex": {"q": to_hex.q, "r": to_hex.r},
	})


## 无动画直接定位（set_player_coord idle 路径）
func set_actor_position(actor_id: String, hex: HexCoord) -> void:
	if _render_world != null:
		_render_world.set_actor_position(actor_id, hex)
	_sync_one(actor_id)


## snap：取消在途移动 + 直接定位（snap_player_coord）
func snap_actor(actor_id: String, hex: HexCoord) -> void:
	if _scheduler != null:
		_scheduler.cancel_for_actor(actor_id)
	set_actor_position(actor_id, hex)


func is_actor_moving(actor_id: String) -> bool:
	return _scheduler != null and _scheduler.has_actor_action(actor_id)


func get_actor_pixel(actor_id: String) -> Vector2:
	if _render_world == null:
		return Vector2.ZERO
	return _axial_to_pixel(_render_world.get_actor_axial(actor_id))


func get_actor_axial(actor_id: String) -> Vector2:
	return _render_world.get_actor_axial(actor_id) if _render_world != null else Vector2.ZERO


func get_avatar(actor_id: String) -> InkMonRender2DAvatar:
	return _avatars.get(actor_id, null) as InkMonRender2DAvatar


## 清空（world rebind / reset）：free avatars + 全新 render_world/scheduler，caller 再 re-seed。
func clear() -> void:
	for value in _avatars.values():
		var node := value as Node
		if node != null:
			node.queue_free()
	_avatars.clear()
	_styles.clear()
	_pending.clear()
	_move_dirs.clear()
	_rebuild_world()


# ========== pump ==========

func _process(delta: float) -> void:
	if _live:
		_pump(delta * 1000.0)


## 确定性步进（测试用）
func step(delta_ms: float) -> void:
	_pump(delta_ms)


func _pump(delta_ms: float) -> void:
	if _render_world == null:
		return
	if not _pending.is_empty():
		for e in _pending:
			_render_world.apply_event_side_effects(e)
			_scheduler.enqueue(_registry.translate(e, _render_world.as_context()))
		_pending.clear()
	_render_world.advance_time(int(delta_ms))
	var result := _scheduler.tick(delta_ms)
	if result.has_changes:
		_render_world.apply_actions(result.active_actions)
		_render_world.apply_actions(result.completed_this_tick)
		_render_world.cleanup(_render_world.get_world_time())
	_render_world.tick_hp_lerp(delta_ms)
	_render_world.flush_dirty_actors()
	_sync_positions()


# ========== RenderWorld 信号 → 共享 avatar ==========

func _on_actor_state_changed(actor_id: String, state: InkMonRender2DActorRenderState) -> void:
	var avatar := _avatars.get(actor_id, null) as InkMonRender2DAvatar
	if avatar == null:
		if _units_root == null:
			return
		var style := _styles.get(actor_id, null) as InkMonRender2DAvatar.Style
		if style == null:
			style = InkMonRender2DAvatar.Style.overworld_npc(Color(0.6, 0.6, 0.6))
		avatar = InkMonRender2DAvatar.new()
		avatar.name = "Avatar_%s" % actor_id
		_units_root.add_child(avatar)
		avatar.initialize(actor_id, state.display_name, state.max_hp, style)
		avatar.set_world_pos(_axial_to_pixel(_render_world.get_actor_axial(actor_id)))
		_avatars[actor_id] = avatar
		avatar_spawned.emit(actor_id, avatar)
	avatar.update_from_state(state)


func _on_actor_despawned(actor_id: String) -> void:
	var avatar := _avatars.get(actor_id, null) as Node
	if avatar != null:
		avatar.queue_free()
	_avatars.erase(actor_id)
	_styles.erase(actor_id)
	_move_dirs.erase(actor_id)


# ========== 坐标 / 同步（唯一 hex→像素边界） ==========

func _axial_to_pixel(axial: Vector2) -> Vector2:
	if _grid == null:
		return Vector2.ZERO
	return _grid.coord_to_world_f(axial.x, axial.y)


func _sync_positions() -> void:
	for actor_id in _avatars.keys():
		_sync_one(actor_id)


func _sync_one(actor_id: String) -> void:
	var avatar := _avatars.get(actor_id, null) as InkMonRender2DAvatar
	if avatar == null or _render_world == null:
		return
	avatar.set_world_pos(_axial_to_pixel(_render_world.get_actor_axial(actor_id)))
	# T7 M4 走格动画状态（idle ↔ walk + 朝向 + 速度绑定）。物理事实（在不在
	# 移动/朝向/走速 world/s）归 driver,表演策略（speed_scale 封顶）归 avatar。
	if avatar.has_unit_visual():
		avatar.sync_unit_locomotion(
			is_actor_moving(actor_id),
			int(_move_dirs.get(actor_id, 3)),
			_walk_speed_world())


## 走格线速度（world units/s）= 相邻格心距 / 补间时长。格心距用 world 平面值
## √3 × hex_edge_world（契约 axial 六向恒等距;不能用 coord_to_world 的投影后
## 屏幕距离——squish/海拔 lift 会让六向"不等距"——codex M4 review medium）。
func _walk_speed_world() -> float:
	return sqrt(3.0) / (OVERWORLD_MOVE_DURATION / 1000.0)
