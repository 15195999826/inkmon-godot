class_name HexGridRenderer3D
extends Node3D

## 3D 六边形网格渲染器
##
## 负责渲染六边形网格的线框、高亮和填充效果。
## 使用 ImmediateMesh + MeshInstance3D 进行渲染。

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

# 渲染组件
var _grid_mesh_instance: MeshInstance3D = null
var _fill_mesh_instance: MeshInstance3D = null
var _grid_mesh: ImmediateMesh = null
var _fill_mesh: ImmediateMesh = null


func _ready() -> void:
	# 创建网格线框 MeshInstance3D
	_grid_mesh = ImmediateMesh.new()
	_grid_mesh_instance = MeshInstance3D.new()
	_grid_mesh_instance.mesh = _grid_mesh
	add_child(_grid_mesh_instance)
	
	var grid_mat := StandardMaterial3D.new()
	grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_mat.vertex_color_use_as_albedo = true
	_grid_mesh_instance.material_override = grid_mat
	
	# 创建填充 MeshInstance3D
	_fill_mesh = ImmediateMesh.new()
	_fill_mesh_instance = MeshInstance3D.new()
	_fill_mesh_instance.mesh = _fill_mesh
	add_child(_fill_mesh_instance)
	
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.vertex_color_use_as_albedo = true
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_mesh_instance.material_override = fill_mat


## 设置要渲染的网格世界
##
## @param world: HexGridWorld 实例，传入 null 会清空渲染器
func set_model(world: HexGridWorld) -> void:
	_world = world
	_render()


## 渲染网格线框
##
## 绘制所有六边形的边框线条
func render_grid() -> void:
	_show_grid = true
	_render()


## 高亮指定的六边形
##
## @param coords: 要高亮的六边形坐标数组
## @param color: 高亮颜色，默认使用 highlight_color
func highlight_hexes(coords: Array[Vector2i], color: Color = highlight_color) -> void:
	for coord in coords:
		_highlighted_hexes[coord] = color
	_render()


## 填充指定的六边形
##
## @param coords: 要填充的六边形坐标数组
## @param color: 填充颜色，默认使用 fill_color
func fill_hexes(coords: Array[Vector2i], color: Color = fill_color) -> void:
	for coord in coords:
		_filled_hexes[coord] = color
	_render()


## 清除所有高亮
func clear_highlights() -> void:
	_highlighted_hexes.clear()
	_render()


## 清除所有填充
func clear_fills() -> void:
	_filled_hexes.clear()
	_render()


## 清除所有渲染效果（网格、高亮、填充）
func clear_all() -> void:
	_show_grid = false
	_highlighted_hexes.clear()
	_filled_hexes.clear()
	_render()


## 核心渲染方法
func _render() -> void:
	if _world == null:
		return
	
	# 清空旧几何体
	_grid_mesh.clear_surfaces()
	_fill_mesh.clear_surfaces()
	
	# 绘制填充
	if not _filled_hexes.is_empty():
		_fill_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for coord in _filled_hexes.keys():
			var corners := _world._layout.hex_corners(coord)
			var center := _world._layout.hex_to_pixel(coord)
			var center_3d := Vector3(center.x, 0, center.y)
			var color: Color = _filled_hexes[coord]
			
			# 三角形扇形填充
			for i in range(6):
				var p1 := Vector3(corners[i].x, 0, corners[i].y)
				var p2 := Vector3(corners[(i + 1) % 6].x, 0, corners[(i + 1) % 6].y)
				
				_fill_mesh.surface_set_color(color)
				_fill_mesh.surface_add_vertex(center_3d)
				_fill_mesh.surface_set_color(color)
				_fill_mesh.surface_add_vertex(p1)
				_fill_mesh.surface_set_color(color)
				_fill_mesh.surface_add_vertex(p2)
		_fill_mesh.surface_end()
	
	# 检查是否需要绘制网格线框或高亮
	var has_grid_content := _show_grid or not _highlighted_hexes.is_empty()
	
	if has_grid_content:
		_grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		
		# 绘制网格线框
		if _show_grid:
			for coord in _world.get_all_coords():
				var corners := _world._layout.hex_corners(coord)
				for i in range(6):
					var p1 := Vector3(corners[i].x, 0, corners[i].y)
					var p2 := Vector3(corners[(i + 1) % 6].x, 0, corners[(i + 1) % 6].y)
					
					_grid_mesh.surface_set_color(grid_color)
					_grid_mesh.surface_add_vertex(p1)
					_grid_mesh.surface_set_color(grid_color)
					_grid_mesh.surface_add_vertex(p2)
		
		# 绘制高亮（在最上层）
		for coord in _highlighted_hexes.keys():
			var corners := _world._layout.hex_corners(coord)
			var color: Color = _highlighted_hexes[coord]
			for i in range(6):
				var p1 := Vector3(corners[i].x, 0, corners[i].y)
				var p2 := Vector3(corners[(i + 1) % 6].x, 0, corners[(i + 1) % 6].y)
				
				_grid_mesh.surface_set_color(color)
				_grid_mesh.surface_add_vertex(p1)
				_grid_mesh.surface_set_color(color)
				_grid_mesh.surface_add_vertex(p2)
		
		_grid_mesh.surface_end()
