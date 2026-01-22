extends CollisionDetector
class_name DistanceCollisionDetector

var hit_distance: float

func _init(distance: float = 50.0):
	hit_distance = distance

func detect(projectile: ProjectileActor, potential_targets: Array) -> Dictionary:
	if not projectile.position:
		return {"hit": false}

	var projectile_pos = projectile.position

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
				"hitPosition": Vector3(projectile_pos.x, projectile_pos.y, projectile.position.z if projectile.position.z else 0.0),
			}

	return {"hit": false}
