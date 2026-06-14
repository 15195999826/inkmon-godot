extends Node
## Phase 3 契约 (Logic 级,直接驱动 InkMonWorldGI,无 Host/View):主世界写路径 = 对象化 command。
##
## 断言:
##   1. submit(InkMonMoveCommand) → tick drain → 玩家逐格走到目标 (移动 command 走多态 apply)。
##   2. 方案 A:command 在 tick drain 一处生效 —— submit 后未 tick 时世界态不变、command_applied 不 fire。
##   3. submit(InkMonBuyCommand) drain 后扣金币 + 入袋, 经 command_applied signal 回流 ok 结果。
##   4. submit(InkMonNpcActionCommand cultivation) drain 后练级 lead。
##   5. 训练 flow intent 经 command_applied 浮现, 但 GI 自己不起战斗 (flow 归 Host)。
##   6. IWorldQuery 只读协议成立 (InkMonWorldGI 鸭子实现)。


const FIXED_DT := 1.0 / 30.0
const MINOR_RUNE_PRICE := 10
const FIXTURE_PATH := "res://inkmon/tests/fixtures/sample_creature_contract.json"


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - submit(InkMonWorldCommand) drains polymorphically in tick (A); intent surfaces via signal; IWorldQuery holds")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()
	# adr/0003: load fixture items (item_NNNN) so BuyCommand resolves item_0002
	# (stub fallback was removed; _make_gi's new_game reads this static cache).
	InkMonItemCatalog.reload_static_items_for_tests(FIXTURE_PATH)

	var checks := [
		_test_move_command,
		_test_buy_command_is_async_and_signals,
		_test_cultivation_command,
		_test_trainer_intent_surfaces_without_gi_flow,
		_test_iworldquery_facade,
	]
	for check in checks:
		var status := (check as Callable).call() as String
		if status != "":
			GameWorld.shutdown()
			return status

	GameWorld.shutdown()
	return ""


func _make_gi() -> InkMonWorldGI:
	var gi := GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
	gi.new_game()
	return gi


## 1 + 2(move 侧):submit 后未 tick 不动;tick drain 多态 apply MoveCommand → 逐格抵达。
func _test_move_command() -> String:
	var gi := _make_gi()
	var start := gi.get_player_coord()
	gi.submit(InkMonMoveCommand.new(Vector2i(1, 0)))
	if gi.get_player_coord() != start:
		return "MoveCommand must not apply before tick (A: mutation only in tick drain)"
	for _i in range(40):
		gi.tick(FIXED_DT)
	if gi.get_player_coord() != Vector2i(1, 0):
		return "submit(MoveCommand) + ticks should walk player to (1,0), got %s" % str(gi.get_player_coord())
	GameWorld.destroy_all_instances()
	return ""


## 2 + 3:buy 是 A(入队不立即生效),drain 后扣金币 + 入袋, 结果经 command_applied 回流。
func _test_buy_command_is_async_and_signals() -> String:
	var gi := _make_gi()
	var results: Array[Dictionary] = []
	gi.command_applied.connect(func(result: Dictionary) -> void:
		results.append(result)
	)
	var gold_before := gi.player_actor.gold
	gi.submit(InkMonBuyCommand.new(&"item_0002"))
	if gi.player_actor.gold != gold_before:
		return "BuyCommand must not spend gold before tick (A)"
	if not results.is_empty():
		return "command_applied must not fire before tick drain"
	gi.tick(FIXED_DT)
	if gi.player_actor.gold != gold_before - MINOR_RUNE_PRICE:
		return "BuyCommand drain should spend %d gold" % MINOR_RUNE_PRICE
	if results.size() != 1 or not bool(results[0].get("ok", false)):
		return "BuyCommand should emit exactly one ok command_applied result"
	GameWorld.destroy_all_instances()
	return ""


## 4:cultivation npc-action command drain 后 lead 升一级。
func _test_cultivation_command() -> String:
	var gi := _make_gi()
	var lead := gi.roster[0]
	var level_before := lead.level
	gi.submit(InkMonNpcActionCommand.new("cultivation", InkMonCultivationNpcHandler.ACTION_CULTIVATE_LEAD))
	if lead.level != level_before:
		return "NpcActionCommand must not apply before tick (A)"
	gi.tick(FIXED_DT)
	if lead.level != level_before + 1:
		return "cultivation NpcActionCommand drain should level the lead"
	GameWorld.destroy_all_instances()
	return ""


## 5:训练 action 的 flow intent 经 command_applied 浮现,但 GI 不执行 flow(不起战斗)。
func _test_trainer_intent_surfaces_without_gi_flow() -> String:
	var gi := _make_gi()
	var results: Array[Dictionary] = []
	gi.command_applied.connect(func(result: Dictionary) -> void:
		results.append(result)
	)
	gi.submit(InkMonNpcActionCommand.new("trainer", InkMonTrainingNpcHandler.ACTION_START_BATTLE))
	gi.tick(FIXED_DT)
	if results.size() != 1:
		return "trainer NpcActionCommand should emit one command_applied"
	var intent := results[0].get(InkMonNpcHandler.RESULT_INTENT, {}) as Dictionary
	if str(intent.get(InkMonNpcHandler.INTENT_KIND, "")) != InkMonTrainingNpcHandler.INTENT_START_BATTLE:
		return "trainer command result must carry start_battle flow intent"
	if gi.has_active_battle():
		return "GI must NOT start battle itself — flow (start battle) belongs to Host"
	GameWorld.destroy_all_instances()
	return ""


## 6:IWorldQuery facade 转发 read + submit,且不暴露 concrete GI(无 get_gi 逃逸口)。
func _test_iworldquery_facade() -> String:
	var gi := _make_gi()
	var query := IWorldQuery.new(gi)
	# 只读转发与底层一致。
	if query.get_player_coord() != gi.get_player_coord():
		return "IWorldQuery should forward get_player_coord to the gi"
	if query.player_actor != gi.player_actor:
		return "IWorldQuery should forward the player_actor getter"
	if not query.has_npc_handler("shop") or query.get_world_actor(InkMonWorldGrid.PLAYER_ID) == null:
		return "IWorldQuery should forward has_npc_handler / get_world_actor"
	# submit 经 facade 入队,tick drain 后等价于直接 submit(扣金币)。
	var gold_before := gi.player_actor.gold
	query.submit(InkMonBuyCommand.new(&"item_0002"))
	gi.tick(FIXED_DT)
	if gi.player_actor.gold != gold_before - MINOR_RUNE_PRICE:
		return "IWorldQuery.submit should reach the command queue (gold spent on drain)"
	# 隔离:facade 不暴露 concrete GI / flow / lifecycle(无 get_gi / 序列化 / 起战斗);表演只能经 read+submit。
	if query.has_method("get_gi") or query.has_method("request_training_battle") or query.has_method("to_dict"):
		return "IWorldQuery must NOT expose concrete GI / flow / lifecycle (isolation)"
	GameWorld.destroy_all_instances()
	return ""
