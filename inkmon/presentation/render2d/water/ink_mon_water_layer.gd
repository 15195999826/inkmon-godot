class_name InkMonRender2DWaterLayer

## water_bodies（map doc 的 shader 水面表演层数据）→ 水面 ShaderMaterial 表 + 落差瀑布面几何。
## 消费端 = InkMonRender2DBakedHexMap：water 格出 shader 水面 Polygon2D 时按格查 materials；
## faces 由消费端换算投影/海拔抬升后出竖直瀑布面（water_face.gdshader）。
##
## 纯 static + flat-top 平面几何（与 baked_hex_map 的 _plane_center / _hex_corner 同公式）：
##   - 岸线段 = body cell 的边中，邻居不属于**任何** water_body 的那些（两片水贴一起 → 连续无岸沫）；
##   - 瀑布 = 相邻两个 body 的 elevation 差自动推导（loader 校验 body 内同海拔，不需要显式字段）：
##     上位侧朝镜头（edge 0/1/2）的落差边出 face 段；下位 body 的水面材质注入 fall 段
##     （落水基线白色翻涌）。背对镜头的落差边不可见，出 push_warning 提示改地图；
##   - 高位水（elevation>0）的朝镜头边若贴着更低的陆地/图外 → 侧壁露洞，push_warning
##     （地图守则：高位水道两翼垫同高河岸，落差只朝下屏开给瀑布）；
##   - flow = body 的 flow 向量（缺省/零 → 默认 -x）；flow_span = 各格中心沿 flow 的投影范围。
##
## 未被任何 body 收录的 water 格不进本表 → baked_hex_map 回退画 baked 水 tile（合法 fallback）。

const SQRT3 := sqrt(3.0)
const MAX_SEGMENTS := 96
const MAX_FALL_SEGMENTS := 8 # 与 water_surface.gdshader 的 fall_a/fall_b 数组同长

const WATER_SURFACE_SHADER := preload("res://inkmon/presentation/render2d/water/water_surface.gdshader")

## 边 i = corner(i)→corner(i+1)，边中点朝向 60i+30°，对应 flat-top 轴向邻居方位
## （与探索期 art_tile_map_base 同表，岸线几何自洽——hex_corner 与此表同一套约定）。
## 屏幕系 y 向下：边 0/1/2 朝镜头（下屏可见），边 3/4/5 背对镜头。
const EDGE_NEIGHBOR_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
]
const CAMERA_FACING_EDGE_COUNT := 3


## water_bodies + 显示密度 edge_px + 全图海拔表（axial Vector2i → elevation，含陆地格）→
## { "materials": { Vector2i(cell) -> ShaderMaterial }, "faces": [瀑布面段 Dictionary] }。
## face 段字段：upper_cell / edge / a_plane / b_plane（平面 px 角点）/ upper_elevation /
## lower_elevation——投影与海拔抬升换算归消费端（本层只做平面几何）。
## edge_px = baked_hex_map 的显示 px/边（水面顶点/UV 都在这个尺度）。
static func build_materials(water_bodies: Array, edge_px: float, elevations: Dictionary) -> Dictionary:
	var out := {"materials": {}, "faces": []}
	if water_bodies == null or water_bodies.is_empty():
		return out
	# 跨 body 的全水格索引（岸线判定：邻居是任意 body 的水都不算岸 → 相邻水域连续；
	# body_of_cell 供落差边把 fall 段记到下位 body）。
	var body_of_cell: Dictionary = {}
	var body_cell_lists: Array = []
	for body_index in water_bodies.size():
		var body := water_bodies[body_index] as Dictionary
		var body_cells: Array = []
		if body != null:
			for cell_value in body.get("cells", []) as Array:
				var cell := cell_value as Array
				if cell != null and cell.size() == 2:
					var coord := Vector2i(int(cell[0]), int(cell[1]))
					body_cells.append(coord)
					body_of_cell[coord] = body_index
		body_cell_lists.append(body_cells)

	# 逐边分类：岸线段（按本 body 记）/ 落差瀑布段（上位视角发现，churn 记到下位 body）。
	var shore_a: Array = []
	var shore_b: Array = []
	var churn_a: Array = []
	var churn_b: Array = []
	for _body_index in water_bodies.size():
		shore_a.append(PackedVector2Array())
		shore_b.append(PackedVector2Array())
		churn_a.append(PackedVector2Array())
		churn_b.append(PackedVector2Array())
	var faces: Array = []
	for body_index in water_bodies.size():
		for cell_value in body_cell_lists[body_index] as Array:
			var cell := cell_value as Vector2i
			var cell_elevation := int(elevations.get(cell, 0))
			var center := _plane_center(cell, edge_px)
			for edge_index in 6:
				var neighbor: Vector2i = cell + EDGE_NEIGHBOR_DIRS[edge_index]
				var corner_a := center + _hex_corner(edge_index, edge_px)
				var corner_b := center + _hex_corner((edge_index + 1) % 6, edge_px)
				if body_of_cell.has(neighbor):
					var neighbor_elevation := int(elevations.get(neighbor, 0))
					if neighbor_elevation >= cell_elevation:
						continue # 同位连续水面；落差边由更高一侧发现
					if edge_index >= CAMERA_FACING_EDGE_COUNT:
						push_warning("[InkMonWaterLayer] %s 的落差边 %d 背对镜头，瀑布面不可见——地图应让落差朝下屏" % [str(cell), edge_index])
						continue
					faces.append({
						"upper_cell": cell,
						"edge": edge_index,
						"a_plane": corner_a,
						"b_plane": corner_b,
						"upper_elevation": cell_elevation,
						"lower_elevation": neighbor_elevation,
					})
					var lower_body := int(body_of_cell[neighbor])
					(churn_a[lower_body] as PackedVector2Array).append(corner_a)
					(churn_b[lower_body] as PackedVector2Array).append(corner_b)
					continue
				# 陆地/图外邻居：岸线段；高位水的朝镜头边贴更低陆地 = 侧壁露洞（地图守则违例）。
				if edge_index < CAMERA_FACING_EDGE_COUNT and cell_elevation > 0 \
						and int(elevations.get(neighbor, -1000)) < cell_elevation:
					push_warning("[InkMonWaterLayer] 高位水格 %s 的朝镜头边 %d 邻居更低/缺格——侧壁露洞，需垫同高河岸" % [str(cell), edge_index])
				(shore_a[body_index] as PackedVector2Array).append(corner_a)
				(shore_b[body_index] as PackedVector2Array).append(corner_b)

	for body_index in water_bodies.size():
		var body := water_bodies[body_index] as Dictionary
		if body == null:
			continue
		var body_cells := body_cell_lists[body_index] as Array
		if body_cells.is_empty():
			continue

		var seg_a := shore_a[body_index] as PackedVector2Array
		var seg_b := shore_b[body_index] as PackedVector2Array
		var seg_count := seg_a.size()
		if seg_count > MAX_SEGMENTS:
			push_error("[InkMonWaterLayer] water_body '%s' 岸线段 %d 超出上限 %d" % [str(body.get("id", "")), seg_count, MAX_SEGMENTS])
			seg_count = MAX_SEGMENTS
		seg_a.resize(MAX_SEGMENTS)
		seg_b.resize(MAX_SEGMENTS)

		var fall_a := churn_a[body_index] as PackedVector2Array
		var fall_b := churn_b[body_index] as PackedVector2Array
		var fall_count := fall_a.size()
		if fall_count > MAX_FALL_SEGMENTS:
			push_error("[InkMonWaterLayer] water_body '%s' 落水基线段 %d 超出上限 %d" % [str(body.get("id", "")), fall_count, MAX_FALL_SEGMENTS])
			fall_count = MAX_FALL_SEGMENTS
		fall_a.resize(MAX_FALL_SEGMENTS)
		fall_b.resize(MAX_FALL_SEGMENTS)

		var flow := _read_flow(body)
		var f_min := INF
		var f_max := -INF
		for cell_value in body_cells:
			var proj := _plane_center(cell_value as Vector2i, edge_px).dot(flow)
			f_min = minf(f_min, proj)
			f_max = maxf(f_max, proj)

		var material := ShaderMaterial.new()
		material.shader = WATER_SURFACE_SHADER
		material.set_shader_parameter("seg_count", seg_count)
		material.set_shader_parameter("seg_a", seg_a)
		material.set_shader_parameter("seg_b", seg_b)
		material.set_shader_parameter("fall_count", fall_count)
		material.set_shader_parameter("fall_a", fall_a)
		material.set_shader_parameter("fall_b", fall_b)
		material.set_shader_parameter("flow_dir", flow)
		material.set_shader_parameter("flow_span", Vector2(f_min, f_max))
		material.set_shader_parameter("edge_px", edge_px)
		var materials := out["materials"] as Dictionary
		for cell_value in body_cells:
			materials[cell_value as Vector2i] = material
	out["faces"] = faces
	return out


static func _read_flow(body: Dictionary) -> Vector2:
	var flow_arr := body.get("flow", []) as Array
	var flow := Vector2(-1.0, 0.0)
	if flow_arr != null and flow_arr.size() == 2:
		flow = Vector2(float(flow_arr[0]), float(flow_arr[1]))
	if flow.length() < 0.001:
		flow = Vector2(-1.0, 0.0)
	return flow.normalized()


## flat-top axial → 平面中心（px）。与 baked_hex_map._plane_center 同公式。
static func _plane_center(axial: Vector2i, edge_px: float) -> Vector2:
	return Vector2(1.5 * float(axial.x), SQRT3 * (float(axial.y) + float(axial.x) * 0.5)) * edge_px


## flat-top 角点 i（相对格中心，px）。角度 60i；与 EDGE_NEIGHBOR_DIRS 同一套约定。
static func _hex_corner(index: int, edge_px: float) -> Vector2:
	var angle := deg_to_rad(60.0 * float(index))
	return Vector2(cos(angle), sin(angle)) * edge_px
