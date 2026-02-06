extends CollisionDetector
class_name MobaCollisionDetector

func detect(projectile: ProjectileActor, _potential_targets: Array[Actor]) -> Dictionary:
	if projectile.config.get("projectileType", "bullet") != ProjectileActor.PROJECTILE_TYPE_MOBA:
		return {"hit": false}

	var target = projectile.get_target()
	if not target:
		return {"hit": false}

	if projectile.should_moba_hit():
		var pos = projectile.position
		return {
			"hit": true,
			"target": target,
			"hitPosition": Vector3(pos.x, pos.y, pos.z if pos.z else 0.0),
		}

	return {"hit": false}
