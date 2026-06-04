class_name InkMonMain
extends Node
## 外层 screen 路由 (ngnl inner_main 式): 标题 → 菜单 → 进游戏 的大场景切换层 (docs/main-game-architecture.md §6b)。
##
## v1 stub: 直接进游戏 (实例化内层游戏导播)。结构留好 —— 将来加标题/菜单只在此插一层,
## 不必重接入口 (project.godot run/main_scene 已指向本场景)。
## 内层游戏导播 (inkmon/host/ink_mon_game.tscn) 只管游戏内
## (主世界 ↔ 战斗 ↔ NPC ↔ save), 零规则零数据零 UI 自绘。


const GameScene := preload("res://inkmon/host/ink_mon_game.tscn")

var _game_director: InkMonWorldHost = null


func _ready() -> void:
	_enter_game()


## v1: 直接进游戏。将来在此插标题/菜单 → 选 new / continue → 再 _enter_game()。
func _enter_game() -> void:
	if _game_director != null:
		return
	_game_director = GameScene.instantiate() as InkMonWorldHost
	add_child(_game_director)


func get_game_director() -> InkMonWorldHost:
	return _game_director
