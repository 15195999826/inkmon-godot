## InkMonRender2DActorRenderState - Actor 渲染状态
##
## RenderWorld 持有的每 actor 可视状态（编译期类型检查，替代裸 Dictionary）。
## 平移自 hex frontend（见 docs/adr/0006）：position 存逻辑 hex（像素转换在 view 边界），
## bump/facing/buffs/shields 为 dormant 字段、保留以保持 state 形状完整。
class_name InkMonRender2DActorRenderState
extends RefCounted


# ========== 基础信息 ==========

var id: String = ""
var type: String = ""
var config_id: String = ""
var display_name: String = ""
var team: int = 0


# ========== 位置（逻辑 hex） ==========

var position: HexCoord = HexCoord.zero()


# ========== 战斗状态 ==========

## 当前视觉 HP(每 tick 朝 target_hp 收敛 lerp,见 RenderWorld.tick_hp_lerp)
var visual_hp: float = 0.0

## 目标 HP(damage / heal apply 后立即累到这里;visual_hp 异步追赶)
var target_hp: float = 0.0

## 最大 HP
var max_hp: float = 100.0

## 是否存活
var is_alive: bool = true


# ========== 视觉效果 ==========

## 受击闪白进度（0.0 = 无闪白，1.0 = 全白）
var flash_progress: float = 0.0

## 染色颜色
var tint_color: Color = Color.WHITE

## 死亡动画进度（0.0 = 开始，1.0 = 完成）
var death_progress: float = 0.0

## bump 临时位移（dormant：撞墙/撞单位时叠在 view 像素上，不动 hex 逻辑位置）
var bump_offset: Vector2 = Vector2.ZERO

## bump 临时挤压（dormant：Vector2 scale;Vector2.ONE = 无形变）
var bump_squish: Vector2 = Vector2.ONE

## 逻辑朝向 (HexFacing.DIR_* 0..5)（dormant：facing 机制落地前恒 0）
var facing_direction: int = 0


# ========== Buff / 护盾状态（dormant） ==========

var buffs: Array[InkMonRender2DBuffSummary] = []
var shields: Array[InkMonRender2DShieldSummary] = []


# ========== 工具方法 ==========

## 创建深拷贝
func duplicate() -> InkMonRender2DActorRenderState:
	var copy := InkMonRender2DActorRenderState.new()
	copy.id = id
	copy.type = type
	copy.config_id = config_id
	copy.display_name = display_name
	copy.team = team
	copy.position = HexCoord.new(position.q, position.r)
	copy.visual_hp = visual_hp
	copy.target_hp = target_hp
	copy.max_hp = max_hp
	copy.is_alive = is_alive
	copy.flash_progress = flash_progress
	copy.tint_color = tint_color
	copy.death_progress = death_progress
	copy.bump_offset = bump_offset
	copy.bump_squish = bump_squish
	copy.facing_direction = facing_direction
	for b in buffs:
		copy.buffs.append(b.duplicate())
	for s in shields:
		copy.shields.append(s.duplicate())
	return copy
