class_name InkMonRender2DIsoHexGrid
extends Node2D

## 共享等轴 2D hex 网格件（adr/0007）。battle 与 overworld 共用:GridMapModel(hex/pointy/radius)
## + GridMapRenderer2D 垂直压扁成 iso 菱形;tile 颜色由 caller paint。
##
## 坐标:coord_to_world(_f) 返回**已压扁**的像素(单位落点对齐压扁地面);world_to_coord_f 反压拾取。
## 网格渲染器 scale.y = ISO_SQUISH;单位本体不压扁(由 caller 放 units_root,直立站压扁格上)。

const ISO_SQUISH := 0.55

var _model: GridMapModel
var _renderer: GridMapRenderer2D


func setup(radius: int, pixel_size: float = 48.0, grid_color: Color = Color(0.12, 0.14, 0.20, 0.55), line_width: float = 2.0) -> void:
	var cfg := GridMapConfig.new()
	cfg.grid_type = GridMapConfig.GridType.HEX
	cfg.orientation = GridMapConfig.Orientation.POINTY
	cfg.draw_mode = GridMapConfig.DrawMode.RADIUS
	cfg.radius = radius
	cfg.size = pixel_size
	_model = GridMapModel.new()
	_model.initialize(cfg)
	if _renderer == null:
		_renderer = GridMapRenderer2D.new()
		_renderer.name = "GridRenderer2D"
		_renderer.scale = Vector2(1.0, ISO_SQUISH)
		add_child(_renderer)
	_renderer.set_model(_model)
	_renderer.grid_color = grid_color
	_renderer.line_width = line_width


## 给一批格子上色（caller 决定单色 / grass+road 等）。需 setup 后调用，最后 render()。
func paint_tiles(coords: Array[HexCoord], color: Color) -> void:
	if _renderer != null:
		_renderer.fill_tiles(coords, color)


func render() -> void:
	if _renderer != null:
		_renderer.render_grid()


func get_all_coords() -> Array[HexCoord]:
	return _model.get_all_coords() if _model != null else []


func has_coord(coord: Vector2i) -> bool:
	return _model != null and _model.has_tile(HexCoord.new(coord.x, coord.y))


## 整数 axial → 压扁像素
func coord_to_world(q: int, r: int) -> Vector2:
	if _model == null:
		return Vector2.ZERO
	var pixel := _model.coord_to_world(HexCoord.new(q, r))
	return Vector2(pixel.x, pixel.y * ISO_SQUISH)


## 分数 axial → 压扁像素（移动插值用，仿射双线性精确）
func coord_to_world_f(qf: float, rf: float) -> Vector2:
	if _model == null:
		return Vector2.ZERO
	var q0 := floori(qf)
	var r0 := floori(rf)
	var fq := qf - float(q0)
	var fr := rf - float(r0)
	var p00 := coord_to_world(q0, r0)
	var p10 := coord_to_world(q0 + 1, r0)
	var p01 := coord_to_world(q0, r0 + 1)
	return p00 + (p10 - p00) * fq + (p01 - p00) * fr


## 压扁像素 → axial：先反压(/ISO_SQUISH)还原 hex 平面再查格。屏幕拾取往返自洽靠这步。
func world_to_coord_f(world2d: Vector2) -> Vector2i:
	if _model == null:
		return Vector2i(-999999, -999999)
	return _model.world_to_coord(Vector2(world2d.x, world2d.y / ISO_SQUISH)).to_axial()
