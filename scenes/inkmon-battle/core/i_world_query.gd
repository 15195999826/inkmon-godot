class_name IWorldQuery
## 主世界只读查询协议(CQRS Query 通道)—— Presentation 只经此读 Logic,不见 concrete InkMonWorldGI。
##
## 静态协议检测工具(仿 LGF IGameStateProvider):GDScript 无真接口,故 InkMonWorldGI 鸭子实现下列读方法,
## 本类只做 has_method 协议校验 + 文档化"表演侧能读的表面"。约定级 seam(GDScript 拦不住 cast,靠 review),
## 非编译级铁墙(docs/main-game-architecture.md §1 facade seam, Non-Goal: 不追求编译级强制)。
##
## 读协议(InkMonWorldGI 实现):
##   get_player_coord() -> Vector2i
##   get_world_actor(key: String) -> InkMonWorldActor
##   get_npc_actions(npc_id: String) -> Array
##   has_npc_handler(npc_id: String) -> bool
##   属性读:session / near_npc_id / npc_defs
## 写路径不在本协议 —— 用 submit(InkMonWorldCommand);flow/lifecycle 是 Host 控制面,也不在此。


## 只读查询协议要求的方法集(鸭子检测用)。属性(session/near_npc_id/npc_defs)由 GDScript var 暴露,不入此表。
const REQUIRED_METHODS: Array[String] = [
	"get_player_coord",
	"get_world_actor",
	"get_npc_actions",
	"has_npc_handler",
]


## 校验对象是否实现只读查询协议(鸭子检测)。约定级:通过不代表它"只能读",仅代表读表面齐全。
static func is_implemented(obj: Variant) -> bool:
	if obj == null or not (obj is Object):
		return false
	var object := obj as Object
	for method_name in REQUIRED_METHODS:
		if not object.has_method(method_name):
			return false
	return true
