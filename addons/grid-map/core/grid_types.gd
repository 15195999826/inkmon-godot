## GridMap 核心类型定义
##
## 定义网格系统的核心枚举和配置类
## - GridType: 网格类型（六边形、矩形、正方形等）
## - Orientation: 网格方向（平顶、尖顶、水平、垂直）
## - DrawMode: 绘制模式（行列、半径）
## - GridMapConfig: 网格配置资源类

class_name GridMapConfig
extends Resource


# ========== 枚举定义 ==========

## 网格类型
enum GridType {
	HEX,            ## 标准六边形，6 个邻居
	RECT_SIX_DIR,   ## 六方向矩形，6 个邻居（交错）
	SQUARE,         ## 标准正方形，4 个邻居
	RECT,           ## 标准矩形，4 个邻居
}

## 网格方向
enum Orientation {
	FLAT,       ## 平顶（六边形）
	POINTY,     ## 尖顶（六边形）
	HORIZONTAL, ## 水平（矩形）
	VERTICAL,   ## 垂直（矩形）
}

## 绘制模式
enum DrawMode {
	ROW_COLUMN,  ## 基于行列（矩形地图）
	RADIUS,      ## 基于半径（六边形地图）
}


# ========== 配置属性 ==========

## 网格类型
@export var grid_type: GridMapConfig.GridType = GridMapConfig.GridType.HEX

## 网格方向
@export var orientation: GridMapConfig.Orientation = GridMapConfig.Orientation.POINTY

## 绘制模式
@export var draw_mode: GridMapConfig.DrawMode = GridMapConfig.DrawMode.ROW_COLUMN

## 网格单元大小（用于六边形）
@export var size: float = 32.0

## 瓦片大小（用于矩形/正方形）
@export var tile_size: Vector2 = Vector2(32.0, 32.0)

## 网格原点
@export var origin: Vector2 = Vector2.ZERO

## 行数（用于 ROW_COLUMN 模式）
@export var rows: int = 10

## 列数（用于 ROW_COLUMN 模式）
@export var columns: int = 10

## 半径（用于 RADIUS 模式）
@export var radius: int = 5


func _init() -> void:
	# 默认值已在 @export 声明中设置
	pass
