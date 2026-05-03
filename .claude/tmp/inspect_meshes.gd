extends SceneTree


const PATHS := [
	"res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/tiles/base/hex_grass.gltf",
	"res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/tiles/roads/hex_road_A.gltf",
	"res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/tiles/rivers/hex_river_A.gltf",
	"res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/tiles/rivers/hex_river_crossing_A.gltf",
	"res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/hill_single_A.gltf",
	"res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/hills_A_trees.gltf",
	"res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/mountain_A.gltf",
	"res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/decoration/nature/mountain_A_grass.gltf",
	"res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_castle_blue.gltf",
	"res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_barracks_blue.gltf",
	"res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_archeryrange_blue.gltf",
	"res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_tower_A_blue.gltf",
	"res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_blacksmith_blue.gltf",
]


func _initialize() -> void:
	for p in PATHS:
		var ps: PackedScene = load(p)
		if ps == null:
			print("FAIL: ", p)
			continue
		var inst := ps.instantiate()
		var mis: Array = []
		_collect_mi(inst, mis)
		var name := p.get_file()
		print("[%s] mesh_instances=%d" % [name, mis.size()])
		for mi: MeshInstance3D in mis:
			var aabb := mi.mesh.get_aabb() if mi.mesh != null else AABB()
			print("    %s  mesh=%s  aabb_size=%s  xform=%s" % [
				mi.name,
				mi.mesh.get_class() if mi.mesh != null else "null",
				aabb.size,
				mi.transform,
			])
		inst.queue_free()
	quit()


func _collect_mi(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_mi(c, out)
