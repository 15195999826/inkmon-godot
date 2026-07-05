class_name InkMonQuestDef
extends RefCounted
## 委托单数据形状 (Phase 3, glossary §4.8: quest = 委托板上的一张单)。纯数据, 进据点档
## (quest_board 随 GI 序列化); 运行时主/副角色住 MissionState.quests, 不在本类。
## Q3.5 拍板: v1 只住 godot (代码常量参数 roll 生成, 不进 lab; 类型稳定后再议数据外置)。


## 主委托类型 (Q3.1 拍板 2 型): 抵达型 / 讨伐型 (清掉目标节点野群)。
const TYPE_REACH := "reach"
const TYPE_HUNT := "hunt"
## 副委托类型 (工程展开: 趟内事件计数型 —— 单目标 DAG 无"顺路第二地标"可判, 计数零新机制)。
const TYPE_HUNT_COUNT := "hunt_count"
const TYPE_CAPTURE_COUNT := "capture_count"


var quest_id := ""
var type := TYPE_REACH
## 主委托目标地标 (world_map.landmarks 的 id); 副委托不用 ("")。
var target_site_id := ""
var reward_gold := 0
## 奖励物品 (Q3.4 金币+物品; "" = 无; roll 自 item catalog price>0 池)。
var reward_item_id := ""
## 副委托计数目标 (主委托 0)。
var goal_count := 0


func is_side_type() -> bool:
	return type == TYPE_HUNT_COUNT or type == TYPE_CAPTURE_COUNT


## 展示文案不在本类 (adr/0011 逻辑层禁产玩家可见文案): 标题/奖励行由表现层
## InkMonText.quest_title / quest_reward 按 to_dict() 语义字段组装。
func to_dict() -> Dictionary:
	return {
		"quest_id": quest_id,
		"type": type,
		"target_site_id": target_site_id,
		"reward_gold": reward_gold,
		"reward_item_id": reward_item_id,
		"goal_count": goal_count,
	}


static func from_dict(data: Dictionary) -> InkMonQuestDef:
	var def := InkMonQuestDef.new()
	def.quest_id = str(data.get("quest_id", ""))
	def.type = str(data.get("type", TYPE_REACH))
	def.target_site_id = str(data.get("target_site_id", ""))
	def.reward_gold = int(data.get("reward_gold", 0))
	def.reward_item_id = str(data.get("reward_item_id", ""))
	def.goal_count = int(data.get("goal_count", 0))
	return def
