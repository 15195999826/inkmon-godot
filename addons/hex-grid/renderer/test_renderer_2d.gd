extends Node2D

## 2D 六边形网格渲染器测试场景
##
## 用于手动验证 HexGridRenderer2D 的功能。
## 提供简单的 UI 按钮来测试渲染、高亮、填充和清除功能。
##
## 场景结构要求：
## - HexGridRenderer2D 节点（命名为 HexGridRenderer2D）
## - Camera2D 节点（可选，用于居中显示）
## - UI 按钮（连接到对应的回调函数）

@onready var renderer: HexGridRenderer2D = $HexGridRenderer2D
var world: HexGridWorld


func _ready() -> void:
	# 创建 9x9 的六边形网格世界
	world = HexGridWorld.new({
		"rows": 9,
		"columns": 9,
		"hex_size": 50.0,
		"orientation": "flat",
	})
	
	# 设置渲染器的数据模型
	renderer.set_model(world)


## 渲染按钮回调：显示网格线框
func _on_render_button_pressed() -> void:
	renderer.render_grid()


## 高亮按钮回调：高亮中心 3x3 区域的格子
func _on_highlight_button_pressed() -> void:
	var coords: Array[Vector2i] = []
	
	# 中心 3x3 区域（axial 坐标系）
	for q in range(-1, 2):
		for r in range(-1, 2):
			coords.append(Vector2i(q, r))
	
	renderer.highlight_hexes(coords)


## 填充按钮回调：填充外围一圈格子
func _on_fill_button_pressed() -> void:
	var coords: Array[Vector2i] = []
	
	# 遍历所有格子，选择外围一圈（距离中心较远的格子）
	for coord in world.get_all_coords():
		if abs(coord.x) >= 3 or abs(coord.y) >= 3:
			coords.append(coord)
	
	renderer.fill_hexes(coords)


## 清除按钮回调：清除所有渲染效果
func _on_clear_button_pressed() -> void:
	renderer.clear_all()
