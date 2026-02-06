extends CollisionDetector
class_name DistanceCollisionDetector

var hit_distance: float

func _init(distance: float = 50.0):
	hit_distance = distance

func detect(projectile: ProjectileActor, potential_targets: Array[Actor]) -> Dictionary:
	if not projectile.position:
		return {"hit": false}

	var projectile_pos = projectile.position
	var z_coord = projectile_pos.z if typeof(projectile_pos) == TYPE_VECTOR3 else 0.0

	for target in potential_targets:
		if not target.position:
			continue

		var dx = target.position.x - projectile_pos.x
		var dy = target.position.y - projectile_pos.y
		var distance = sqrt(dx * dx + dy * dy)

		if distance <= hit_distance:
			return {
				"hit": true,
				"target": target.to_ref(),
				"hitPosition": Vector3(projectile_pos.x, projectile_pos.y, z_coord),
			}

	return {"hit": false}
