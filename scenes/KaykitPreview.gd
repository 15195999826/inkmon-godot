## KayKit Hex Battle 静态预览
##
## 场景节点全部摆在 KaykitPreview.tscn 内（地形 + 建筑 + 装饰 + 6 角色）。
## 此脚本只做两件事:
##   1. 让所有 .glb 角色播 idle 动画
##   2. Space 重置摄像机
extends Node


@onready var _camera_rig: LomoCameraRig = $CameraRig as LomoCameraRig
@onready var _units_root: Node3D = $Units


func _ready() -> void:
	_play_all_idles(_units_root)
	print("[KaykitPreview] WASD 移动 / Q E 旋转 / 滚轮缩放 / Space 重置")


func _play_all_idles(root: Node) -> void:
	var anim := _find_animation_player(root)
	if anim != null:
		var idle := _find_idle_animation(anim)
		if idle != "":
			anim.play(idle)
	for child in root.get_children():
		_play_all_idles(child)


func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child as AnimationPlayer
	return null


func _find_idle_animation(anim: AnimationPlayer) -> String:
	for anim_name: StringName in anim.get_animation_list():
		if "idle" in String(anim_name).to_lower():
			return anim_name
	var list := anim.get_animation_list()
	return list[0] if list.size() > 0 else ""


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if (event as InputEventKey).keycode == KEY_SPACE and _camera_rig != null:
			_camera_rig.reset_camera()
