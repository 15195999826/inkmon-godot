class_name InkMonIsoSandboxDemoMap

## iso 沙盒共享 demo 地图（绘制版 / TileMap 版同源，保证两版对照的是同一张图）。
## 纯 static 生成，固定 seed 确定性：草地为主 + 一条斜向水带 + 散布土/石 + 远水抬升海拔 + 高地长树。

const RADIUS := 5

const TERRAIN_GRASS := "grass"
const TERRAIN_DIRT := "dirt"
const TERRAIN_STONE := "stone"
const TERRAIN_WATER := "water"


## 占位配色（两版共用，保证对照同色）。
static func terrain_color(terrain: String) -> Color:
	match terrain:
		TERRAIN_WATER:
			return Color(0.26, 0.46, 0.66)
		TERRAIN_DIRT:
			return Color(0.46, 0.34, 0.22)
		TERRAIN_STONE:
			return Color(0.52, 0.52, 0.55)
		_:
			return Color(0.33, 0.55, 0.26)


## TileMap 版 atlas 列号（与 InkMonIsoTileBaker 烘焙顺序一致）。
static func atlas_column(terrain: String) -> int:
	match terrain:
		TERRAIN_DIRT:
			return 1
		TERRAIN_STONE:
			return 2
		TERRAIN_WATER:
			return 3
		_:
			return 0


## 返回 { Vector2i(q,r) -> {"terrain": String, "elevation": int, "tree": bool} }
static func generate() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260610
	var tiles := {}
	for q in range(-RADIUS, RADIUS + 1):
		var r_min := maxi(-RADIUS, -q - RADIUS)
		var r_max := mini(RADIUS, -q + RADIUS)
		for r in range(r_min, r_max + 1):
			var band := q + 2 * r
			var terrain := TERRAIN_GRASS
			var elevation := 0
			var tree := false
			if band == 1 or band == 2:
				terrain = TERRAIN_WATER
			else:
				var roll := rng.randf()
				if roll < 0.12:
					terrain = TERRAIN_STONE
				elif roll < 0.30:
					terrain = TERRAIN_DIRT
				elevation = clampi(absi(band - 1) / 4, 0, 2)
				if elevation < 2 and rng.randf() < 0.18:
					elevation += 1
				tree = terrain == TERRAIN_GRASS and elevation >= 1 and rng.randf() < 0.22
			tiles[Vector2i(q, r)] = {"terrain": terrain, "elevation": elevation, "tree": tree}
	return tiles
