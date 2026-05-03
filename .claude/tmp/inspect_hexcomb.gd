extends SceneTree


func _initialize() -> void:
	var path := "res://art/test/HexComb.fbx"
	var ps: PackedScene = load(path)
	if ps == null:
		print("FAILED to load ", path)
		quit(1)
		return
	var inst: Node = ps.instantiate()
	print("=== HexComb.fbx structure ===")
	_dump(inst, 0)
	quit()


func _dump(node: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	var line := "%s- %s (%s)" % [pad, node.name, node.get_class()]
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var aabb := mi.mesh.get_aabb()
			line += "  mesh=%s  surf=%d  AABB pos=%s size=%s" % [
				mi.mesh.get_class(),
				mi.mesh.get_surface_count(),
				aabb.position,
				aabb.size,
			]
			for i in range(mi.mesh.get_surface_count()):
				var mat := mi.mesh.surface_get_material(i)
				var verts: int = -1
				var arr: Array = mi.mesh.surface_get_arrays(i)
				if arr.size() > Mesh.ARRAY_VERTEX:
					var pa: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					verts = pa.size()
				line += "  | surf%d verts=%d mat=%s" % [i, verts, str(mat)]
	print(line)
	for c in node.get_children():
		_dump(c, depth + 1)
