class_name InkMonMissionState
extends RefCounted
## 出征 (mission, glossary §4.8) 运行态 —— transient (P1 拍板): 不进存档, 刻意无 to_dict/from_dict。
##
## GI 持有 (adr/0002 三叉: 需保留且 transient → GI 持的 RefCounted); Presentation 一份真相不持。
## "丢这趟" = Host load 出发档重建世界, 本对象随旧 GI 一起整体丢弃 —— 可整体丢弃性是设计要求,
## 别把出征态散落到本对象之外。将来要"退出续玩"时给本类加序列化即可 (game-vision §1 末, 不烧桥)。


var mission_seed := 0
## 本趟节点图 (趟内蔓延生成, transient)。
var map: InkMonMissionMapData = null
var current_node_id := 0
## 主委托目标对应的大地图地标格。
var target_site_coord := Vector2i.ZERO
## 本趟携带委托 (Phase 3, Q3.2 主 1 + 副 ≤2): [{def: InkMonQuestDef, role: "main"|"side", progress: int}]。
## transient; 副委托 progress 由趟内事件计数 (野群战胜 / 捕获成功), 回城结算判达标发奖。
var quests: Array[Dictionary] = []
## 剩余补给 (每步节点跳扣 1; 粮尽掉血 = M1.4 补给钟)。
var supplies := 0
## 途中捕获 (Phase 2 填充: {species_id, roll_seed}); 回城结算 adopt 入 roster ("落袋为安")。
var captured_pending: Array[Dictionary] = []
## 趟内足迹: node_id -> true (趟内视野/回访判定的底料)。
var visited_node_ids: Dictionary = {}
## 趟内所见节点快照 (Phase 4 迷雾 Q4.5, war3 灰态): node_id -> kind (进入视野时的类型快照)。
## transient (丢趟同丢); 离开视野后据此显示"最后所见", 从未入圆的节点全黑不显示 (Q4.4)。
var seen_node_kinds: Dictionary = {}
## 待打的野群节点 (M2.2): 踩上 battle 节点即置 (节点即内容, 必战不可绕), 期间选路移动一律拒。
## 胜后延续到捕捉阶段 (M2.3), resolve_wild_battle_encounter 收尾清 -1 解锁;
## 败 = 全灭不清 —— 世界被 Host load 出发档整体重建, 本对象随之销毁。
var pending_battle_node_id := -1
## 战后捕捉池 (M2.3, 胜利时从节点 wild payload 建): 每条
## {slot_index, actor_id, species_id, roll_seed, attempted, captured} (显示名由表现层按 species_id 查, adr/0011)。
## 每只恰好一次投掷; 离开战场 (resolve) 即作废未尝试者 ("留在战斗场景扔球"的窗口)。
var capture_pool: Array[Dictionary] = []


func has_pending_battle() -> bool:
	return pending_battle_node_id >= 0


func is_at_target() -> bool:
	return map != null and current_node_id == map.target_node_id
