class_name CollisionDetector
extends RefCounted

func detect(projectile: ProjectileActor, potential_targets: Array[Actor]) -> Dictionary:
	push_error("CollisionDetector is abstract and must be overridden")
	return {"hit": false}
