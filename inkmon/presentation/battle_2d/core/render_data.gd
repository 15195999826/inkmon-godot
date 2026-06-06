## InkMonBattle2DRenderData - RenderWorld 信号 payload 数据类
##
## 平移自 hex frontend（见 docs/adr/0006）。首版只保留 active 路径用到的 payload：
## FloatingText / ProceduralEffect / ScreenShake。dormant 的 AttackVfx / Projectile /
## ConeDebugOverlay 待对应机制落地再 JIT 补。位置全用逻辑 axial（Vector2 = q,r）。
class_name InkMonBattle2DRenderData


## 飘字创建数据
class FloatingText extends RefCounted:
	## 动作 ID
	var id: String = ""
	## 关联的 Actor ID
	var actor_id: String = ""
	## 显示文本
	var text: String = ""
	## 文本颜色
	var color: Color = Color.WHITE
	## 逻辑 axial 位置（q,r），由 animator 转像素后再 spawn
	var position: Vector2 = Vector2.ZERO
	## 创建时的世界时间（毫秒）
	var start_time: int = 0
	## 持续时间（毫秒）
	var duration: float = 0.0
	## 文本样式
	var style: int = 0


## 程序化特效数据
class ProceduralEffect extends RefCounted:
	## 特效 ID
	var id: String = ""
	## 特效类型（InkMonBattle2DProceduralVFXAction.EffectType）
	var effect: int = 0
	## 关联的 Actor ID
	var actor_id: String = ""
	## 创建时的世界时间（毫秒）
	var start_time: int = 0
	## 持续时间（毫秒）
	var duration: float = 0.0
	## 强度
	var intensity: float = 1.0
	## 颜色
	var color: Color = Color.WHITE


## 震屏状态数据
class ScreenShake extends RefCounted:
	## X 轴偏移
	var offset_x: float = 0.0
	## Y 轴偏移
	var offset_y: float = 0.0

	## 转换为 Vector2
	func to_vector2() -> Vector2:
		return Vector2(offset_x, offset_y)

	## 是否有效（非零偏移）
	func is_active() -> bool:
		return offset_x != 0.0 or offset_y != 0.0
