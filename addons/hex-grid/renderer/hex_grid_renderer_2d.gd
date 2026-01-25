class_name HexGridRenderer2D
extends Node2D

## 2D 六边形网格渲染器
##
## 负责渲染六边形网格的线框、高亮和填充效果。
## 使用 Node2D 的 _draw() 方法进行渲染。

## 网格线框颜色
@export var grid_color: Color = Color.WHITE

## 高亮颜色
@export var highlight_color: Color = Color.YELLOW

## 填充颜色
@export var fill_color: Color = Color(0.2, 0.6, 1.0, 0.3)

## 线条宽度
@export var line_width: float = 2.0

# 内部状态
var _world: HexGridWorld = null
var _show_grid: bool = false
var _highlighted_hexes: Dictionary = {}  # Vector2i -> Color
var _filled_hexes: Dictionary = {}  # Vector2i -> Color


## 设置要渲染的网格世界
##
## @param world: HexGridWorld 实例，传入 null 会清空渲染器
func set_model(world: HexGridWorld) -> void:
	_world = world
	queue_redraw()


## 渲染网格线框
##
## 绘制所有六边形的边框线条
func render_grid() -> void:
	_show_grid = true
	queue_redraw()


## 高亮指定的六边形
##
## @param coords: 要高亮的六边形坐标数组
## @param color: 高亮颜色，默认使用 highlight_color
func highlight_hexes(coords: Array[Vector2i], color: Color = highlight_color) -> void:
	for coord in coords:
		_highlighted_hexes[coord] = color
	queue_redraw()


## 填充指定的六边形
##
## @param coords: 要填充的六边形坐标数组
## @param color: 填充颜色，默认使用 fill_color
func fill_hexes(coords: Array[Vector2i], color: Color = fill_color) -> void:
	for coord in coords:
		_filled_hexes[coord] = color
	queue_redraw()


## 清除所有高亮
func clear_highlights() -> void:
	_highlighted_hexes.clear()
	queue_redraw()


## 清除所有填充
func clear_fills() -> void:
	_filled_hexes.clear()
	queue_redraw()


## 清除所有渲染效果（网格、高亮、填充）
func clear_all() -> void:
	_show_grid = false
	_highlighted_hexes.clear()
	_filled_hexes.clear()
	queue_redraw()


## 核心渲染方法
func _draw() -> void:
	if _world == null:
		return
	
	# 绘制网格线框
	if _show_grid:
		for coord in _world.get_all_coords():
			var corners := _world._layout.hex_corners(coord)
			# 转换为 PackedVector2Array 并闭合
			var points := PackedVector2Array()
			for corner in corners:
				points.append(corner)
			points.append(corners[0])  # 闭合六边形
			draw_polyline(points, grid_color, line_width)
	
	# 绘制填充（在线框之前，避免遮挡）
	for coord in _filled_hexes.keys():
		var corners := _world._layout.hex_corners(coord)
		var points := PackedVector2Array(corners)
		var colors := PackedColorArray([_filled_hexes[coord]])
		draw_polygon(points, colors)
	
	# 绘制高亮（在最上层）
	for coord in _highlighted_hexes.keys():
		var corners := _world._layout.hex_corners(coord)
		var points := PackedVector2Array()
		for corner in corners:
			points.append(corner)
		points.append(corners[0])  # 闭合六边形
		draw_polyline(points, _highlighted_hexes[coord], line_width * 1.5)
