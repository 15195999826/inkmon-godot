class_name InkMonMapStylePresets
## 大地图风格预设 (adr/0012 决定五): canonical 生成不随风格变, 风格 = 色板 + 开关 uniform,
## 纯表现层随时切换。默认"墨线面片"(faceted Voronoi + 墨线描界 + 苔藓橄榄色板, 对齐世界观
## low poly / sharp edges / ink sketch 与战斗场景概念图); 其余为 mock 拍板留档的备选画风。
## 偏好存 user:// (表现层偏好不进 GI/存档, adr/0002 三叉)。


const STYLE_INK := "ink"
const STYLE_MOSS := "moss"
const STYLE_WATERCOLOR := "watercolor"
const STYLE_PLAIN_WC := "plain_wc"
const STYLE_FLAT := "flat"
const STYLE_CODEX := "codex"
const ORDER: Array[String] = [STYLE_INK, STYLE_MOSS, STYLE_WATERCOLOR, STYLE_PLAIN_WC, STYLE_FLAT, STYLE_CODEX]
const DEFAULT_STYLE := STYLE_INK

const PREF_PATH := "user://inkmon_map_style.cfg"
const PREF_SECTION := "map"
const PREF_KEY := "style"

## 苔藓橄榄色板 (概念图对齐, ink/moss 共用)。
const _MOSS_COLORS := {
	"col_plain": Color(0.47, 0.48, 0.31),
	"col_forest": Color(0.33, 0.38, 0.22),
	"col_hill": Color(0.51, 0.49, 0.41),
	"col_mountain": Color(0.55, 0.54, 0.50),
	"col_tundra": Color(0.58, 0.60, 0.52),
	"col_dry": Color(0.57, 0.54, 0.36),
	"col_deep": Color(0.22, 0.28, 0.33),
	"col_sea": Color(0.30, 0.38, 0.43),
	"col_shallow": Color(0.42, 0.50, 0.53),
	"col_shore": Color(0.56, 0.51, 0.41),
	"col_snowcap": Color(0.78, 0.79, 0.77),
	"col_dense": Color(0.24, 0.29, 0.17),
	"col_rock": Color(0.63, 0.62, 0.58),
	"col_desert": Color(0.62, 0.57, 0.42),
	"col_ink": Color(0.10, 0.11, 0.10),
}

## Codex: 暗色六元素地图纸。苔绿 / 冷石 / 钢青水, 用更硬面片与重墨压出手绘裂面感。
const _CODEX_COLORS := {
	"col_plain": Color(0.38, 0.43, 0.28),
	"col_forest": Color(0.22, 0.31, 0.18),
	"col_hill": Color(0.47, 0.45, 0.35),
	"col_mountain": Color(0.44, 0.46, 0.45),
	"col_tundra": Color(0.57, 0.60, 0.52),
	"col_dry": Color(0.56, 0.43, 0.25),
	"col_deep": Color(0.10, 0.17, 0.21),
	"col_sea": Color(0.20, 0.32, 0.37),
	"col_shallow": Color(0.35, 0.48, 0.50),
	"col_shore": Color(0.52, 0.47, 0.34),
	"col_snowcap": Color(0.70, 0.72, 0.69),
	"col_dense": Color(0.16, 0.24, 0.13),
	"col_rock": Color(0.55, 0.56, 0.54),
	"col_desert": Color(0.60, 0.48, 0.30),
	"col_ink": Color(0.055, 0.060, 0.055),
}

## 经典水彩色板 (watercolor / plain_wc 共用底色)。
const _WASH_COLORS := {
	"col_plain": Color(0.53, 0.58, 0.41),
	"col_forest": Color(0.30, 0.42, 0.28),
	"col_hill": Color(0.59, 0.52, 0.38),
	"col_mountain": Color(0.52, 0.48, 0.44),
	"col_tundra": Color(0.71, 0.73, 0.65),
	"col_dry": Color(0.67, 0.64, 0.44),
	"col_deep": Color(0.13, 0.22, 0.31),
	"col_sea": Color(0.18, 0.30, 0.40),
	"col_shallow": Color(0.38, 0.55, 0.57),
	"col_shore": Color(0.80, 0.74, 0.58),
	"col_snowcap": Color(0.92, 0.93, 0.94),
	"col_dense": Color(0.22, 0.34, 0.23),
	"col_rock": Color(0.60, 0.58, 0.56),
	"col_desert": Color(0.79, 0.70, 0.50),
	"col_ink": Color(0.09, 0.13, 0.15),
}

## 扁平高饱和色板 (MC/泰拉瑞亚风)。
const _FLAT_COLORS := {
	"col_plain": Color(0.44, 0.66, 0.30),
	"col_forest": Color(0.16, 0.46, 0.20),
	"col_hill": Color(0.72, 0.58, 0.34),
	"col_mountain": Color(0.56, 0.52, 0.50),
	"col_tundra": Color(0.74, 0.79, 0.70),
	"col_dry": Color(0.80, 0.74, 0.36),
	"col_deep": Color(0.10, 0.30, 0.52),
	"col_sea": Color(0.16, 0.42, 0.62),
	"col_shallow": Color(0.30, 0.62, 0.72),
	"col_shore": Color(0.93, 0.85, 0.58),
	"col_snowcap": Color(0.97, 0.97, 0.98),
	"col_dense": Color(0.09, 0.36, 0.15),
	"col_rock": Color(0.68, 0.67, 0.66),
	"col_desert": Color(0.91, 0.79, 0.46),
	"col_ink": Color(0.05, 0.12, 0.20),
}


## 预设查表: uniforms 整组下发 shader; rivers/river_* 归 view 的 polyline overlay。
## 未知 id = 程序 bug (调用方只该拿 ORDER 里的 id) → 响亮失败。
static func preset(style_id: String) -> Dictionary:
	match style_id:
		STYLE_INK:
			return {
				"name_key": "MAP_STYLE_INK",
				"rivers": true,
				"river_under": Color(0.13, 0.15, 0.15, 0.85),
				"river_core": Color(0.36, 0.44, 0.47, 0.95),
				"uniforms": _merge(_MOSS_COLORS, {
					"facet_mix": 1.0, "facet_scale": 0.80,
					"ink_strength": 0.85, "hatch_strength": 0.22, "shade_k": 0.42,
					"grain_amt": 0.05, "vignette_amt": 0.16, "shallow_steps": 0.0,
					"mottle_amt": 0.16, "post_darken": 0.95,
				}),
			}
		STYLE_MOSS:
			return {
				"name_key": "MAP_STYLE_MOSS",
				"rivers": true,
				"river_under": Color(0.16, 0.19, 0.20, 0.7),
				"river_core": Color(0.34, 0.41, 0.45, 0.9),
				"uniforms": _merge(_MOSS_COLORS, {
					"facet_mix": 0.0, "facet_scale": 0.62,
					"ink_strength": 0.75, "hatch_strength": 0.0, "shade_k": 0.40,
					"grain_amt": 0.05, "vignette_amt": 0.16, "shallow_steps": 0.0,
					"mottle_amt": 0.16, "post_darken": 0.95,
				}),
			}
		STYLE_WATERCOLOR:
			return {
				"name_key": "MAP_STYLE_WATERCOLOR",
				"rivers": true,
				"river_under": Color(0.10, 0.18, 0.22, 0.6),
				"river_core": Color(0.23, 0.38, 0.44, 0.9),
				"uniforms": _merge(_WASH_COLORS, {
					"facet_mix": 0.0, "facet_scale": 0.62,
					"ink_strength": 0.75, "hatch_strength": 0.0, "shade_k": 0.40,
					"grain_amt": 0.05, "vignette_amt": 0.10, "shallow_steps": 0.0,
					"mottle_amt": 0.0, "post_darken": 1.0,
				}),
			}
		STYLE_PLAIN_WC:
			# "无气候带"观感 = 色表把 tundra 映射回草色 (canonical 生成不变, adr/0012 决定五)。
			var plain_colors := _merge(_WASH_COLORS, {"col_tundra": _WASH_COLORS["col_plain"]})
			return {
				"name_key": "MAP_STYLE_PLAIN_WC",
				"rivers": false,
				"river_under": Color(0, 0, 0, 0),
				"river_core": Color(0, 0, 0, 0),
				"uniforms": _merge(plain_colors, {
					"facet_mix": 0.0, "facet_scale": 0.62,
					"ink_strength": 0.75, "hatch_strength": 0.0, "shade_k": 0.40,
					"grain_amt": 0.05, "vignette_amt": 0.10, "shallow_steps": 0.0,
					"mottle_amt": 0.0, "post_darken": 1.0,
				}),
			}
		STYLE_FLAT:
			return {
				"name_key": "MAP_STYLE_FLAT",
				"rivers": true,
				"river_under": Color(0.08, 0.22, 0.35, 0.7),
				"river_core": Color(0.20, 0.45, 0.60, 0.95),
				"uniforms": _merge(_FLAT_COLORS, {
					"facet_mix": 0.0, "facet_scale": 0.62,
					"ink_strength": 0.55, "hatch_strength": 0.0, "shade_k": 0.12,
					"grain_amt": 0.0, "vignette_amt": 0.0, "shallow_steps": 2.0,
					"mottle_amt": 0.0, "post_darken": 1.0,
				}),
			}
		STYLE_CODEX:
			return {
				"name_key": "MAP_STYLE_CODEX",
				"rivers": true,
				"river_under": Color(0.055, 0.075, 0.080, 0.85),
				"river_core": Color(0.32, 0.47, 0.50, 0.95),
				"uniforms": _merge(_CODEX_COLORS, {
					"facet_mix": 1.0, "facet_scale": 0.56,
					"ink_strength": 0.92, "hatch_strength": 0.30, "shade_k": 0.54,
					"grain_amt": 0.07, "vignette_amt": 0.22, "shallow_steps": 3.0,
					"mottle_amt": 0.20, "post_darken": 0.95,
				}),
			}
	Log.assert_crash(false, "InkMonMapStylePresets", "unknown style id: %s" % style_id)
	return {}


static func name_key(style_id: String) -> String:
	return str(preset(style_id).get("name_key", ""))


static func next_style(style_id: String) -> String:
	var index := ORDER.find(style_id)
	return ORDER[(index + 1) % ORDER.size()] if index >= 0 else DEFAULT_STYLE


## user:// 偏好 (表现层, 不进存档)。损坏/未知值回退默认。
static func load_pref() -> String:
	var config := ConfigFile.new()
	if config.load(PREF_PATH) != OK:
		return DEFAULT_STYLE
	var style_id := str(config.get_value(PREF_SECTION, PREF_KEY, DEFAULT_STYLE))
	return style_id if ORDER.has(style_id) else DEFAULT_STYLE


static func save_pref(style_id: String) -> void:
	var config := ConfigFile.new()
	config.set_value(PREF_SECTION, PREF_KEY, style_id)
	config.save(PREF_PATH)


static func _merge(base: Dictionary, extra: Dictionary) -> Dictionary:
	var merged := base.duplicate()
	merged.merge(extra, true)
	return merged
