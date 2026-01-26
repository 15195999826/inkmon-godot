extends Node2D

## 2D 六边形网格渲染器测试场景
##
## 用于手动验证 HexGridRenderer2D 的功能。
## 提供 UI 控件来测试不同绘制模式和参数。
##
## 场景结构要求：
## - HexGridRenderer2D 节点
## - Camera2D 节点
## - UI 控件（下拉框、输入框、按钮）

@onready var renderer: HexGridRenderer2D = $HexGridRenderer2D

# UI 控件引用
@onready var draw_mode_option: OptionButton = $UI/VBoxContainer/DrawModeOption
@onready var rows_container: HBoxContainer = $UI/VBoxContainer/RowsContainer
@onready var columns_container: HBoxContainer = $UI/VBoxContainer/ColumnsContainer
@onready var radius_container: HBoxContainer = $UI/VBoxContainer/RadiusContainer
@onready var rows_input: SpinBox = $UI/VBoxContainer/RowsContainer/RowsInput
@onready var columns_input: SpinBox = $UI/VBoxContainer/ColumnsContainer/ColumnsInput
@onready var radius_input: SpinBox = $UI/VBoxContainer/RadiusContainer/RadiusInput
@onready var hex_size_input: SpinBox = $UI/VBoxContainer/HexSizeContainer/HexSizeInput

var world: HexGridWorld


func _ready() -> void:
	# 初始化下拉框选项
	draw_mode_option.add_item("Row/Column", 0)
	draw_mode_option.add_item("Radius", 1)
	draw_mode_option.selected = 0
	
	# 初始化输入框默认值
	rows_input.value = 9
	columns_input.value = 9
	radius_input.value = 4
	hex_size_input.value = 50
	
	# 初始显示/隐藏对应的输入框
	_update_input_visibility()
	
	# 创建初始网格
	_recreate_world()


## 根据当前选择的模式更新输入框可见性
func _update_input_visibility() -> void:
	var is_row_column := draw_mode_option.selected == 0
	rows_container.visible = is_row_column
	columns_container.visible = is_row_column
	radius_container.visible = not is_row_column


## 根据当前参数重新创建世界
func _recreate_world() -> void:
	var config: Dictionary
	
	var current_hex_size := hex_size_input.value
	
	if draw_mode_option.selected == 0:
		# Row/Column 模式
		config = {
			"draw_mode": "row_column",
			"rows": int(rows_input.value),
			"columns": int(columns_input.value),
			"hex_size": current_hex_size,
			"orientation": "flat",
		}
	else:
		# Radius 模式
		config = {
			"draw_mode": "radius",
			"radius": int(radius_input.value),
			"hex_size": current_hex_size,
			"orientation": "flat",
		}
	
	world = HexGridWorld.new(config)
	renderer.set_model(world)
	renderer.clear_all()


## 绘制模式下拉框变化回调
func _on_draw_mode_option_item_selected(_index: int) -> void:
	_update_input_visibility()
	_recreate_world()


## 行数输入变化回调
func _on_rows_input_value_changed(_value: float) -> void:
	_recreate_world()


## 列数输入变化回调
func _on_columns_input_value_changed(_value: float) -> void:
	_recreate_world()


## 半径输入变化回调
func _on_radius_input_value_changed(_value: float) -> void:
	_recreate_world()


## 六边形大小输入变化回调
func _on_hex_size_input_value_changed(_value: float) -> void:
	_recreate_world()


## 渲染按钮回调：显示网格线框
func _on_render_button_pressed() -> void:
	renderer.render_grid()


## 高亮按钮回调：高亮中心区域的格子
func _on_highlight_button_pressed() -> void:
	var coords: Array[Vector2i] = []
	
	# 高亮中心 7 格（半径 1）
	coords = HexMath.axial_range(Vector2i.ZERO, 1)
	
	renderer.highlight_hexes(coords)


## 填充按钮回调：填充外围一圈格子
func _on_fill_button_pressed() -> void:
	var coords: Array[Vector2i] = []
	
	# 遍历所有格子，选择外围一圈（距离中心较远的格子）
	var all_coords := world.get_all_coords()
	if all_coords.is_empty():
		return
	
	# 计算最大距离
	var max_dist := 0
	for coord in all_coords:
		var dist := HexMath.axial_distance(Vector2i.ZERO, coord)
		if dist > max_dist:
			max_dist = dist
	
	# 选择最外圈
	for coord in all_coords:
		var dist := HexMath.axial_distance(Vector2i.ZERO, coord)
		if dist >= max_dist - 1:
			coords.append(coord)
	
	renderer.fill_hexes(coords)


## 清除按钮回调：清除所有渲染效果
func _on_clear_button_pressed() -> void:
	renderer.clear_all()
