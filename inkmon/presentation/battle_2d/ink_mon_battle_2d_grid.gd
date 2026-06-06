class_name InkMonBattle2DGrid
extends Node2D

## 战斗回放占位网格(2D，adr/0005）。自建 GridMapModel(hex/pointy/radius)+ GridMapRenderer2D 画线框+填充。
## 仅供回放定位:axial(q,r) → 2D 像素。像素 size 自定(与逻辑战斗 grid size 无关——回放只需坐标自洽)。

const PIXEL_SIZE := 48.0
## 等轴垂直压扁(与 overworld 一致):地面 hex 压成 iso 菱形,单位直立站其上。
const ISO_SQUISH := 0.55

var _model: GridMapModel
var _renderer: GridMapRenderer2D


func setup(radius: int) -> void:
	var cfg := GridMapConfig.new()
	cfg.grid_type = GridMapConfig.GridType.HEX
	cfg.orientation = GridMapConfig.Orientation.POINTY
	cfg.draw_mode = GridMapConfig.DrawMode.RADIUS
	cfg.radius = radius
	cfg.size = PIXEL_SIZE
	_model = GridMapModel.new()
	_model.initialize(cfg)
	if _renderer == null:
		_renderer = GridMapRenderer2D.new()
		_renderer.name = "GridRenderer2D"
		_renderer.scale = Vector2(1.0, ISO_SQUISH)
		add_child(_renderer)
	_renderer.set_model(_model)
	_renderer.grid_color = Color(0.12, 0.14, 0.20, 0.55)
	_renderer.line_width = 2.0
	_renderer.fill_tiles(_model.get_all_coords(), Color(0.16, 0.18, 0.24, 1.0))
	_renderer.render_grid()


func coord_to_world(q: int, r: int) -> Vector2:
	if _model == null:
		return Vector2.ZERO
	var pixel := _model.coord_to_world(HexCoord.new(q, r))
	return Vector2(pixel.x, pixel.y * ISO_SQUISH)


## 分数 axial → 像素（移动插值用）。hex→pixel + ISO 都是仿射变换，对整数三角点做
## 双线性插值即精确。供 animator 把 RenderWorld 的 in-flight 逻辑坐标转像素。
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
