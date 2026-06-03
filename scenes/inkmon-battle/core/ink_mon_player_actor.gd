class_name InkMonPlayerActor
extends InkMonWorldActor
## 玩家走路 avatar = 常驻 GI registry 的活 actor (adr/0001 统一 live-actor)。
##
## 揣玩家级数据 (非单只, 影响全局): gold / progression / medals + bag 容器 id。
## bag 容器 id 是 runtime (ItemSystem 注册), **不进存档** —— 存档只存容器内物品 (镜像 UE InventoryKit
## container-as-ActorComponent: 物品实例住中央 ItemSystem, actor 只持容器 id 引用)。
## 走路位置 = hex_position (InkMonWorldActor 基类字段), 进存档 (coord)。


const DEFAULT_GOLD := 100


var gold := 0
var progression: Dictionary = {}
## 勋章 = 玩家级 (非单只, 影响所有 InkMon, 对标 TFT 海克斯)。
var medals: Array[String] = []
## bag 容器 id (ItemSystem 注册, runtime; 不进存档)。-1 = 未注册。
var bag_container_id := -1


## 新游戏默认玩家态 (gold 100 + progression 默认 + 空 medals)。
static func create_new() -> InkMonPlayerActor:
	var player := InkMonPlayerActor.new()
	player.type = "inkmon_player"
	player.set_display_name("Player")
	player.gold = DEFAULT_GOLD
	player.progression = {
		"trainer_rank": 1,
		"guild_joined": false,
		"cultivation_points": 0,
	}
	player.medals = []
	return player


## adr/0001 自序列化: 从存档持久切片建玩家 actor。bag 容器 id 不在存档 (runtime), 由 GI 装配。
static func from_dict(data: Dictionary) -> InkMonPlayerActor:
	var player := InkMonPlayerActor.new()
	player.type = "inkmon_player"
	player.set_display_name("Player")
	player.gold = int(data.get("gold", 0))
	# as Dictionary 对"存在但非字典"的值返回 null (非 {}), 故显式 guard (对齐下方 coord)。
	var prog := data.get("progression", {}) as Dictionary
	player.progression = prog.duplicate(true) if prog != null else {}
	player.medals = _string_array(data.get("medals", []))
	var coord := data.get("coord", {}) as Dictionary
	if coord != null and not coord.is_empty():
		player.hex_position = HexCoord.from_dict(coord)
	return player


func to_dict() -> Dictionary:
	return {
		"gold": gold,
		"progression": progression.duplicate(true),
		"medals": medals.duplicate(),
		# 无效位置存 {} (镜像 InkMonBattleActor.serialize), round-trip 保"未放置", 不被钳成 (0,0)。
		"coord": hex_position.to_dict() if hex_position.is_valid() else {},
	}


func try_spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	return true


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	var source := value as Array
	if source == null:
		return result
	for item in source:
		result.append(str(item))
	return result
