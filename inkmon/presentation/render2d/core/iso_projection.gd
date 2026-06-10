class_name InkMonRender2DIsoProjection

## 等轴地面投影纯函数（adr/0002：无状态 → static 纯函数）。
##
## 相机模型：正交相机俯视地面，pitch = 仰角（绕屏幕 X 轴俯仰），yaw = 水平旋转（绕世界竖直轴）。
## 正交投影下，地面平面点的屏幕投影 = 一个 2×2 仿射：先平面旋转 yaw，再纵向压扁 sin(pitch)。
## pitch=90° 即纯俯视（squish=1）；yaw=0 即"正面向下看"（现行 overworld 的特例）。
##
## 字典：squish 0.5 ↔ pitch 30°（2:1 像素等轴）；squish 0.577 ↔ pitch 35.26°（真等轴）。


## hex 平面点 → 屏幕的基（拾取用 affine_inverse()）。
static func ground_basis(pitch_deg: float, yaw_deg: float) -> Transform2D:
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	return Transform2D(
		Vector2(cos(yaw), sin(yaw) * sin(pitch)),
		Vector2(-sin(yaw), cos(yaw) * sin(pitch)),
		Vector2.ZERO
	)


## 世界竖直高度（海拔 / billboard 抬升）→ 屏幕纵向偏移量（向上为正，调用方自行取负）。
static func height_to_screen(height: float, pitch_deg: float) -> float:
	return height * cos(deg_to_rad(pitch_deg))


## 该俯仰角对应的纵向压扁系数（readout / 与既有 ISO_SQUISH 对照用）。
static func squish_of(pitch_deg: float) -> float:
	return sin(deg_to_rad(pitch_deg))
