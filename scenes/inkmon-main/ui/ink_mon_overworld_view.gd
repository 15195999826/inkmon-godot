class_name InkMonOverworldView
extends Node2D


const HEX_SIZE := 44.0
const MAP_RADIUS := 4


var player_coord := Vector2i.ZERO
var near_npc_id := ""
var npc_defs: Dictionary = {}


func set_player_coord(coord: Vector2i) -> void:
	player_coord = coord
	queue_redraw()


func set_near_npc_id(npc_id: String) -> void:
	near_npc_id = npc_id
	queue_redraw()


func set_npcs(defs: Dictionary) -> void:
	npc_defs = defs.duplicate(true)
	queue_redraw()


func coord_to_screen(coord: Vector2i) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var center := Vector2(viewport_size.x * 0.47, viewport_size.y * 0.55)
	var x := HEX_SIZE * sqrt(3.0) * (float(coord.x) + float(coord.y) * 0.5)
	var y := HEX_SIZE * 1.5 * float(coord.y)
	return center + Vector2(x, y)


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.76, 0.68, 0.52))
	_draw_hex_map()
	_draw_npcs()
	_draw_player()


func _draw_hex_map() -> void:
	for q in range(-MAP_RADIUS, MAP_RADIUS + 1):
		for r in range(-MAP_RADIUS, MAP_RADIUS + 1):
			var coord := Vector2i(q, r)
			if _axial_distance(coord, Vector2i.ZERO) > MAP_RADIUS:
				continue
			var center := coord_to_screen(coord)
			var points := _hex_points(center)
			var fill := Color(0.82, 0.75, 0.58, 0.72)
			if (q + r) % 3 == 0:
				fill = Color(0.70, 0.68, 0.50, 0.64)
			draw_colored_polygon(points, fill)
			draw_polyline(_closed_points(points), Color(0.22, 0.20, 0.16, 0.34), 1.5)
			if abs(q - r) % 4 == 0:
				draw_circle(center + Vector2(8, -9), 4.0, Color(0.24, 0.30, 0.20, 0.30))


func _draw_npcs() -> void:
	for npc_id_value in npc_defs.keys():
		var npc_id := str(npc_id_value)
		var def := npc_defs[npc_id] as Dictionary
		if def == null:
			continue
		var coord := def.get("coord", Vector2i.ZERO) as Vector2i
		var center := coord_to_screen(coord)
		var emphasized: bool = npc_id == "shop" or npc_id == "trainer"
		if emphasized:
			draw_circle(center, 46.0, Color(0.95, 0.70, 0.20, 0.22))
		var base_color := Color(0.16, 0.13, 0.10)
		var accent := Color(0.87, 0.67, 0.25) if emphasized else Color(0.38, 0.34, 0.28)
		draw_circle(center, 24.0, base_color)
		draw_circle(center, 19.0, accent)
		var marker_rect := Rect2(center - Vector2(12, 14), Vector2(24, 28))
		draw_rect(marker_rect, Color(0.92, 0.83, 0.58))
		if npc_id == "shop":
			draw_circle(center + Vector2(0, 0), 5.0, Color(0.20, 0.16, 0.10))
		elif npc_id == "trainer":
			draw_line(center + Vector2(-8, 8), center + Vector2(8, -8), Color(0.20, 0.16, 0.10), 3.0)
			draw_line(center + Vector2(-8, -8), center + Vector2(8, 8), Color(0.20, 0.16, 0.10), 3.0)
		if npc_id == near_npc_id:
			draw_arc(center, 31.0, 0.0, TAU, 48, Color(1.0, 0.86, 0.36), 3.0)


func _draw_player() -> void:
	var center := coord_to_screen(player_coord)
	draw_circle(center, 22.0, Color(0.09, 0.08, 0.07))
	draw_circle(center, 17.0, Color(0.15, 0.28, 0.42))
	draw_circle(center + Vector2(0, -7), 6.0, Color(0.92, 0.78, 0.62))
	draw_rect(Rect2(center + Vector2(-7, 0), Vector2(14, 15)), Color(0.16, 0.33, 0.54))


func _hex_points(center: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(6):
		var angle := PI / 6.0 + float(i) * TAU / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * HEX_SIZE)
	return points


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if not points.is_empty():
		closed.append(points[0])
	return closed


func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return int((abs(dq) + abs(dq + dr) + abs(dr)) / 2)
