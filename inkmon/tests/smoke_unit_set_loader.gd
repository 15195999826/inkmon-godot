extends Node
## Smoke: InkMonUnitSetLoader 消费已发布 inkmon-units-main(inkmon-unitset/1)。
## 契约面程序化断言(T7 M4 验收):帧数 / fps(含契约 12)/ loop / stride_world /
## 6 向三形态展开(真帧 3、alias 2/4、mirror 5/0/1 —— mirror 的 flip 标记 +
## centered offset.x 取反)/ 锚定公式 offset = size/2 − anchor / 程序影预推
## (帧数对齐 + 脚线锚点 offset + mirror 向翻转剪影独立影动画[斜向恒右不随
## 镜像,二轮验收修正])。数值基准 = mon_0001 v2 manifest(批2 逐向真生成)。

const SET_ID := "inkmon-units-main"
const UNIT_ID := "mon_0001"
const EPS := 0.01


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - unit set loader consumes inkmon-unitset/1 (frames/dirs/mirror/anchor/fps/shadow)")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	# (1) manifest 读取 + schema 校验。
	var manifest := InkMonUnitSetLoader.load_set_manifest(SET_ID)
	if manifest.is_empty():
		return "load_set_manifest(%s) should succeed" % SET_ID
	if float((manifest.get("projection", {}) as Dictionary).get("unit_fps", 0.0)) != 12.0:
		return "manifest projection.unit_fps should be 12 (契约)"

	# (2) 全 set 装载(含程序影预推)。
	var units := InkMonUnitSetLoader.load_set(SET_ID)
	if units.is_empty() or not units.has(UNIT_ID):
		return "load_set should yield %s" % UNIT_ID
	var visual := units[UNIT_ID] as InkMonUnitSetLoader.UnitVisual
	if visual.unit_fps != 12.0:
		return "UnitVisual.unit_fps should be 12"

	# (3) ring:全帧发布(契约 Q3)——121 源帧 / loop / fps_override=src 实值(24)
	#     + entry 透传 src 映射(viewer 指认帧坐标系)。
	if not visual.has_ring():
		return "mon_0001 should have a ring"
	var sf := visual.sprite_frames
	if sf.get_frame_count("ring") != 121:
		return "ring should have 121 frames (全帧发布), got %d" % sf.get_frame_count("ring")
	if not sf.get_animation_loop("ring"):
		return "ring should loop"
	if absf(sf.get_animation_speed("ring") - 24.0) > EPS:
		return "ring fps should be 24 (fps_override=src), got %f" % sf.get_animation_speed("ring")
	var ring_entry := visual.ring_entry()
	if (ring_entry.get("src_frames", []) as Array).size() != 121:
		return "ring entry should expose 121 src_frames"
	if int(ring_entry.get("src_frame_count", 0)) != 121:
		return "ring entry src_frame_count should be 121"

	# (4) 动作清单与真帧帧数(批2 逐向真生成:walk d3=21 / idle d3=23 / attack d3=12)。
	var actions := visual.actions()
	for expected_action in ["walk", "idle", "attack"]:
		if not expected_action in actions:
			return "actions should include %s, got %s" % [expected_action, str(actions)]
	var frame_expect := {"walk_d3": 21, "idle_d3": 23, "attack_d3": 12}
	for anim_value in frame_expect.keys():
		var anim := str(anim_value)
		if sf.get_frame_count(anim) != int(frame_expect[anim]):
			return "%s should have %d frames, got %d" % [anim, int(frame_expect[anim]), sf.get_frame_count(anim)]
	if not sf.get_animation_loop("walk_d3"):
		return "walk should loop"
	if not sf.get_animation_loop("idle_d3"):
		return "idle should loop"
	if sf.get_animation_loop("attack_d3"):
		return "attack should NOT loop (单发)"

	# (5) 6 向逐向真生成(批2 首验收 Q1):真帧 3/4/1/2 各自动画 + 镜像 5←3、0←2。
	#     每真帧向有独立动画 <action>_d<dir>;镜像向 flip + 复用目标真帧向动画。
	for true_dir in [3, 4, 1, 2]:
		var e := visual.entry("walk", true_dir)
		if e.is_empty() or str(e.get("kind")) != "true" or bool(e.get("mirrored")):
			return "walk d%d should be a true-frame direction" % true_dir
		if str(e.get("animation")) != "walk_d%d" % true_dir:
			return "walk d%d should have its own animation" % true_dir
	# d5 镜像 d3、d0 镜像 d2(契约镜像对 3↔5、2↔0)。
	var d5 := visual.entry("walk", 5)
	if str(d5.get("kind")) != "mirror" or not bool(d5.get("mirrored")) or str(d5.get("animation")) != "walk_d3":
		return "walk d5 should mirror walk_d3"
	var d0 := visual.entry("walk", 0)
	if str(d0.get("kind")) != "mirror" or not bool(d0.get("mirrored")) or str(d0.get("animation")) != "walk_d2":
		return "walk d0 should mirror walk_d2"

	# (6) 锚定公式(manifest walk d3: size [308,314] anchor [115.16,299.58]);
	#     offset = size/2 − anchor;镜像向 offset.x 取反(probe 消费端镜像规则)。
	var walk3 := visual.entry("walk", 3)
	var want_offset := Vector2(308.0 * 0.5 - 115.16, 314.0 * 0.5 - 299.58)
	var got_offset := walk3.get("offset") as Vector2
	if got_offset.distance_to(want_offset) > EPS:
		return "walk d3 offset should be %s, got %s" % [str(want_offset), str(got_offset)]
	# d5 镜像 d3:offset.x 取反(相对 d3,非 d0——d0 镜像的是 d2)。
	var mirror_offset := d5.get("offset") as Vector2
	if mirror_offset.distance_to(Vector2(-want_offset.x, want_offset.y)) > EPS:
		return "walk d5 mirror offset.x should flip d3's sign, got %s" % str(mirror_offset)

	# (7) 速度绑定数据:stride_world 透出(批2 walk d3 = 0.467)+ 自然步速公式
	#     (0.467 × 12fps / 21 帧 ≈ 0.267)。
	if absf(visual.stride_of("walk") - 0.467) > EPS:
		return "walk stride_world should be 0.467, got %f" % visual.stride_of("walk")
	if absf(visual.natural_speed("walk") - (0.467 * 12.0 / 21.0)) > EPS:
		return "walk natural_speed should be %f world/s, got %f" % [0.467 * 12.0 / 21.0, visual.natural_speed("walk")]
	if visual.stride_of("idle") != 0.0:
		return "idle should have no stride_world"

	# (8) 程序影预推:帧数与本体对齐;alpha 已烧进像素(契约 0.33);脚线锚点 offset 就位;
	#     影不随镜像(mirror 向 shadow_offset == 真帧向)。
	var shadows := visual.shadow_frames
	if shadows == null:
		return "shadow_frames should be prebuilt by default"
	for anim_value in ["ring", "walk_d3", "idle_d3", "attack_d3"]:
		var anim := str(anim_value)
		if shadows.get_frame_count(anim) != sf.get_frame_count(anim):
			return "shadow %s frame count should match body" % anim
	var shadow_tex := shadows.get_frame_texture("walk_d3", 0)
	if shadow_tex == null:
		return "shadow frame texture missing"
	var shadow_img := shadow_tex.get_image()
	var center_a := shadow_img.get_pixel(shadow_img.get_width() / 2, shadow_img.get_height() / 2).a
	if center_a <= 0.0 or center_a > 0.5:
		return "shadow center alpha should be in (0, 0.5] (契约 0.33 烧进像素), got %f" % center_a
	# 影几何锁数值(2026-07-09 首验收⑤修复:脚线基准=轴锚地线,非画布底):
	# walk d3 anchor_y 299.58 → ground_row 300 → gh 301 → sh = round(301×0.35) = 105
	# → out_h = 105 + 2×margin(14) = 133;feet.y = margin → offset.y = 66.5−14。
	if shadow_img.get_height() != 133:
		return "walk shadow out_h should be 133 (anchor-line squash+margin), got %d" % shadow_img.get_height()
	var walk_shadow_off := walk3.get("shadow_offset") as Vector2
	if absf(walk_shadow_off.y - (133.0 * 0.5 - 14.0)) > EPS:
		return "walk shadow_offset.y should anchor feet at margin row, got %f" % walk_shadow_off.y
	if (walk3.get("shadow_offset") as Vector2) == Vector2.ZERO:
		return "walk d3 shadow_offset should be non-zero (feet anchored)"
	# 影不随镜像 = **斜向不翻**;剪影随屏上身位(二轮验收修正 2026-07-09):
	# d5 有独立影动画 walk_d5(翻转剪影重推),脚线锚用镜像锚 anchor_x' =
	# size_x − anchor_x ⇒ 影画布同尺寸下 shadow_offset.x 差 = 2·anchor_x − size_x。
	if str(walk3.get("shadow_animation", "")) != "walk_d3":
		return "walk d3 shadow_animation should be walk_d3 (真帧向 = 本体同名)"
	if str(d5.get("shadow_animation", "")) != "walk_d5":
		return "walk d5 should carry its own mirrored-silhouette shadow animation walk_d5"
	if not shadows.has_animation("walk_d5"):
		return "shadow_frames should contain walk_d5 (mirror 向翻转剪影影)"
	if shadows.get_frame_count("walk_d5") != sf.get_frame_count("walk_d3"):
		return "walk_d5 shadow frame count should match walk_d3 body"
	var d5_shadow_off := d5.get("shadow_offset") as Vector2
	var want_d5_x := walk_shadow_off.x + (2.0 * 115.16 - 308.0)
	if absf(d5_shadow_off.x - want_d5_x) > EPS or absf(d5_shadow_off.y - walk_shadow_off.y) > EPS:
		return "walk d5 shadow_offset should use mirrored feet anchor (%f, %f), got %s" % [want_d5_x, walk_shadow_off.y, str(d5_shadow_off)]
	# 剪影确实翻转(熊剪影非对称 ⇒ 像素数据必不同):
	var d3_shadow_img := shadows.get_frame_texture("walk_d3", 0).get_image()
	var d5_shadow_img := shadows.get_frame_texture("walk_d5", 0).get_image()
	if d3_shadow_img.get_data() == d5_shadow_img.get_data():
		return "walk_d5 shadow should be rebuilt from the flipped silhouette (identical to d3's)"
	# 语义全等断言:d5 影 == _make_shadow(flip_x(源帧), 镜像锚) 逐字节——
	# 剪影随屏上身位翻、斜切参数原样(shear>0 恒右,影斜向不随镜像)。
	var shadow_params := (manifest.get("projection", {}) as Dictionary).get("unit_shadow", {}) as Dictionary
	if float(shadow_params.get("shear", 0.0)) <= 0.0:
		return "projection.unit_shadow.shear should stay positive (影斜向恒右的契约参数)"
	var src_tex := load("res://content/art/units/%s/mon_0001/unit_mon_0001_walk_d3_f01.png" % SET_ID) as Texture2D
	if src_tex == null:
		return "walk_d3 f01 source frame should load"
	# duplicate 后再 flip——get_image() 可能返回资源内部缓存引用(loader 同注记)。
	var flipped := src_tex.get_image().duplicate() as Image
	flipped.flip_x()
	var expect := InkMonUnitSetLoader._make_shadow(flipped, 308.0 - 115.16, 299.58, shadow_params)
	if expect.is_empty():
		return "_make_shadow on flipped silhouette should succeed"
	if (expect["image"] as Image).get_data() != d5_shadow_img.get_data():
		return "walk_d5 shadow should equal shadow(flip_x(src), mirrored anchor) byte-for-byte"
	# ring 触地归一(export v2)+ 锚线脚线:ring anchor_y ≈ 底行 → 影从脚线起。
	var ring_shadow_tex := shadows.get_frame_texture("ring", 0)
	if ring_shadow_tex == null:
		return "ring shadow frame missing"

	# (8b) mirror 影动画也吃 with_shadows 开关——见 (9) bare 断言(shadow_frames
	#      整体为 null,mirror 向不预推)。

	# (9) with_shadows=false:跳过预推(启动耗时口径)。
	var bare := InkMonUnitSetLoader.load_set(SET_ID, false)
	var bare_visual := bare[UNIT_ID] as InkMonUnitSetLoader.UnitVisual
	if bare_visual.shadow_frames != null:
		return "load_set(with_shadows=false) should skip shadow prebuild"

	# (10) with_ring=false:world 装载免吃全帧 ring(契约 Q3 消费端条款)。
	var ringless := InkMonUnitSetLoader.load_set(SET_ID, true, false)
	var ringless_visual := ringless[UNIT_ID] as InkMonUnitSetLoader.UnitVisual
	if ringless_visual.has_ring():
		return "load_set(with_ring=false) should skip ring"
	if ringless_visual.sprite_frames.has_animation("ring"):
		return "load_set(with_ring=false) should not build the ring animation"
	if ringless_visual.entry("walk", 3).is_empty():
		return "load_set(with_ring=false) should still load actions"

	return ""
