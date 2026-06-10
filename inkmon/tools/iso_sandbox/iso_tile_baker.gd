class_name InkMonIsoTileBaker

## TileMap 版占位 tile 烘焙器（纯 static）。纯 Image 像素操作（自写 scanline 多边形填充 +
## 插值描线），不依赖 viewport 渲染 → headless 安全、确定性。
##
## 规格（角度烘死）：flat-top hex，顶面 64×28（squish ≈ 0.5 ↔ pitch 30°，2:1 像素等轴），
## 下挂 14px 侧裙 —— 三个可见侧面（左下/正下/右下），右上来光 → 左暗右亮。
## atlas 1 行 4 列：grass / dirt / stone / water（列序见 InkMonIsoSandboxDemoMap.atlas_column）。

const TILE_W := 64
const TILE_H := 28
const SKIRT := 14
const REGION := Vector2i(TILE_W, TILE_H + SKIRT)

const OUTLINE_COLOR := Color(0.07, 0.06, 0.05, 0.9)


static func bake_atlas() -> ImageTexture:
	var atlas := Image.create_empty(TILE_W * 4, TILE_H + SKIRT, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0.0, 0.0, 0.0, 0.0))
	for column in range(4):
		var tile := _bake_tile(_terrain_for_column(column))
		atlas.blit_rect(tile, Rect2i(0, 0, REGION.x, REGION.y), Vector2i(column * TILE_W, 0))
	return ImageTexture.create_from_image(atlas)


static func _terrain_for_column(column: int) -> String:
	match column:
		1:
			return InkMonIsoSandboxDemoMap.TERRAIN_DIRT
		2:
			return InkMonIsoSandboxDemoMap.TERRAIN_STONE
		3:
			return InkMonIsoSandboxDemoMap.TERRAIN_WATER
		_:
			return InkMonIsoSandboxDemoMap.TERRAIN_GRASS


## 单 tile 画进独立 Image 再 blit，天然裁剪，杜绝越界写进相邻 atlas 列。
static func _bake_tile(terrain: String) -> Image:
	var img := Image.create_empty(REGION.x, REGION.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var base := InkMonIsoSandboxDemoMap.terrain_color(terrain)

	# flat-top hex 顶面角点（精确占满 64×28 名义格 → 相邻 cell 无缝拼接）
	var c_w := Vector2(0.0, 14.0)
	var c_nw := Vector2(16.0, 0.0)
	var c_ne := Vector2(48.0, 0.0)
	var c_e := Vector2(64.0, 14.0)
	var c_se := Vector2(48.0, 28.0)
	var c_sw := Vector2(16.0, 28.0)
	var top := PackedVector2Array([c_w, c_nw, c_ne, c_e, c_se, c_sw])

	var drop := Vector2(0.0, float(SKIRT))
	# 三个可见侧面：左下最暗 → 正下 → 右下最亮（右上来光）
	_fill_poly(img, PackedVector2Array([c_w, c_sw, c_sw + drop, c_w + drop]), base.darkened(0.55))
	_fill_poly(img, PackedVector2Array([c_sw, c_se, c_se + drop, c_sw + drop]), base.darkened(0.40))
	_fill_poly(img, PackedVector2Array([c_se, c_e, c_e + drop, c_se + drop]), base.darkened(0.25))
	_fill_poly(img, top, base)
	_outline(img, top)
	return img


static func _fill_poly(img: Image, pts: PackedVector2Array, color: Color) -> void:
	var min_y := INF
	var max_y := -INF
	for p in pts:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	for y in range(int(floorf(min_y)), int(ceilf(max_y))):
		var sy := float(y) + 0.5
		var xs: Array[float] = []
		for i in range(pts.size()):
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			if (a.y <= sy and b.y > sy) or (b.y <= sy and a.y > sy):
				xs.append(a.x + (sy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		var k := 0
		while k + 1 < xs.size():
			for x in range(int(ceilf(xs[k] - 0.5)), int(floorf(xs[k + 1] - 0.5)) + 1):
				_put(img, x, y, color)
			k += 2


static func _outline(img: Image, pts: PackedVector2Array) -> void:
	for i in range(pts.size()):
		_line(img, pts[i], pts[(i + 1) % pts.size()])


static func _line(img: Image, a: Vector2, b: Vector2) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for s in range(steps + 1):
		var p := a.lerp(b, float(s) / float(steps))
		_put(img, int(roundf(p.x)), int(roundf(p.y)), OUTLINE_COLOR)


static func _put(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, color)
