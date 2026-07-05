class_name InkMonMissionMapSheet
extends Node2D
## 地图纸子节点 (adr/0012 决定四): 唯一职责 = 带 ShaderMaterial 把 sheet 矩形画满
## (draw_texture_rect 提供 UV 0..1 映射)。数据纹理与风格 uniform 由 mission map view 喂;
## show_behind_parent → 永远垫在父节点图元 (河流/迷雾/节点/走廊/旗) 之下。


const SHEET_SHADER := preload("res://inkmon/presentation/mission/world_map_sheet.gdshader")


var _rect := Rect2()
var _white_texture: ImageTexture = null


func _init() -> void:
	show_behind_parent = true
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHEET_SHADER
	material = shader_material
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_white_texture = ImageTexture.create_from_image(image)


func set_sheet_rect(rect: Rect2) -> void:
	_rect = rect
	queue_redraw()


func set_sheet_uniform(uniform_name: String, value: Variant) -> void:
	(material as ShaderMaterial).set_shader_parameter(uniform_name, value)


func _draw() -> void:
	if _rect.size.x <= 0.0 or _rect.size.y <= 0.0:
		return
	draw_texture_rect(_white_texture, _rect, false)
