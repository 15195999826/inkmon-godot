extends Node
## T6 走台阶 smoke（adr/0006 v1 验收件）：world_main 的台阶复合体面片
## （inkmon-patches-main / terrace_stairs @ 锚定 (-2,-1)）打通高差通行规则全链。
##
## 断言：
##   1. bundle 装载成功（patch footprint 逐格校验通过 —— tiles[] 改型与面片一致）。
##   2. 被盖格打上 patch_covered metadata（渲染层压制的依据），非覆盖格没有。
##   3. 高差规则生效：无豁免的 e0→e1 边 can_traverse == false（普通高地不可瞬移爬上）。
##   4. climb_edges 豁免生效：台阶两段 e0→e1、e1→e2 均可跨越（且反向可下——双向查）。
##   5. 端到端走台阶：find_path (-2,-1)e0 → (-2,-3)e2 = 恰好沿台阶两步；反向同长。
##   6. 例外解锁连通：经台阶可达侧翼 e1 (-3,-2)（同档平走），不经台阶不可达。

const ANCHOR := Vector2i(-2, -1)      # 台阶脚下 e0（锚定格）
const STEP_E1 := Vector2i(-2, -2)     # 中间踏步 e1（climb 边朝锚定）
const TOP_E2 := Vector2i(-2, -3)      # 高地 e2（climb 边朝踏步）
const TOP_E2_SIDE := Vector2i(-1, -3) # 高地延伸 e2
const WING_E1 := Vector2i(-3, -2)     # 侧翼 e1（无 climb 边）
const PLAIN_E1 := Vector2i(-1, -4)    # 地图上普通 e1 孤格（非面片）
const PLAIN_E1_NEIGHBOR := Vector2i(0, -4)  # 它的 e0 邻居


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - terrace patch loads; height-step rule blocks plain slopes; climb edges walk up e0->e1->e2 and back")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var grid := InkMonWorldGrid.new()
	grid.setup()
	var model := grid.model
	if model == null:
		return "world grid model missing"

	# 1/2. footprint 校验已在 loader（失败会空 bundle 崩 setup）；覆盖标记抽查。
	for coord in [ANCHOR, STEP_E1, TOP_E2, TOP_E2_SIDE, WING_E1]:
		if not bool(model.get_tile_metadata(_hex(coord), "patch_covered", false)):
			return "footprint cell %s missing patch_covered metadata" % str(coord)
	if bool(model.get_tile_metadata(_hex(Vector2i(0, 0)), "patch_covered", false)):
		return "(0,0) is not covered by any patch but carries patch_covered"

	# 3. 高差规则：普通 e1 孤格从 e0 邻居不可跨越（无豁免）。
	if model.can_traverse(_hex(PLAIN_E1_NEIGHBOR), _hex(PLAIN_E1)):
		return "height-step rule inactive: plain e0->e1 edge %s->%s is traversable" % [str(PLAIN_E1_NEIGHBOR), str(PLAIN_E1)]

	# 4. climb 豁免：两段台阶边双向可跨。
	for pair in [[ANCHOR, STEP_E1], [STEP_E1, TOP_E2]]:
		var lo: Vector2i = pair[0]
		var hi: Vector2i = pair[1]
		if not model.can_traverse(_hex(lo), _hex(hi)):
			return "climb edge %s->%s not traversable (exemption missing)" % [str(lo), str(hi)]
		if not model.can_traverse(_hex(hi), _hex(lo)):
			return "climb edge %s->%s not traversable downhill (双向查 broken)" % [str(hi), str(lo)]

	# 5. 端到端走台阶（占用/预订全空 —— 纯地形规则）。
	grid.sync_occupants(ANCHOR, {})
	var up := grid.find_path(InkMonWorldGrid.PLAYER_ID, ANCHOR, TOP_E2)
	if up.size() != 2 or up[0] != STEP_E1 or up[1] != TOP_E2:
		return "stair path up unexpected: %s" % str(up)
	grid.sync_occupants(TOP_E2, {})
	var down := grid.find_path(InkMonWorldGrid.PLAYER_ID, TOP_E2, ANCHOR)
	if down.size() != 2:
		return "stair path down unexpected: %s" % str(down)

	# 6. 侧翼 e1 只能经台阶到达（e1 同档平走），其余边全被高差挡住。
	grid.sync_occupants(ANCHOR, {})
	var wing := grid.find_path(InkMonWorldGrid.PLAYER_ID, ANCHOR, WING_E1)
	if wing.is_empty():
		return "wing e1 %s unreachable via stairs" % str(WING_E1)
	if not (STEP_E1 in wing):
		return "wing path skipped the stair step (found %s) — a non-exempt slope leaked" % str(wing)

	# 高地延伸 e2 同档平走可达。
	var side := grid.find_path(InkMonWorldGrid.PLAYER_ID, ANCHOR, TOP_E2_SIDE)
	if side.is_empty():
		return "plateau extension %s unreachable" % str(TOP_E2_SIDE)
	return ""


func _hex(coord: Vector2i) -> HexCoord:
	return HexCoord.new(coord.x, coord.y)
