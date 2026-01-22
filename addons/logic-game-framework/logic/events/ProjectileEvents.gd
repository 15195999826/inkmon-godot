extends RefCounted
class_name ProjectileEvents

const PROJECTILE_LAUNCHED_EVENT := "projectileLaunched"
const PROJECTILE_HIT_EVENT := "projectileHit"
const PROJECTILE_MISS_EVENT := "projectileMiss"
const PROJECTILE_DESPAWN_EVENT := "projectileDespawn"
const PROJECTILE_PIERCE_EVENT := "projectilePierce"

static func create_projectile_launched_event(projectile_id: String, source, start_position: Vector3, projectile_type: String, speed: float, target = null, target_position: Vector3 = Vector3.ZERO, has_target_position: bool = false) -> Dictionary:
	var payload := {
		"kind": PROJECTILE_LAUNCHED_EVENT,
		"projectileId": projectile_id,
		"source": source,
		"startPosition": start_position,
		"projectileType": projectile_type,
		"speed": speed,
	}
	if target != null:
		payload["target"] = target
	if has_target_position:
		payload["targetPosition"] = target_position
	return payload

static func create_projectile_hit_event(projectile_id: String, source, target, hit_position: Vector3, fly_time: float, fly_distance: float, options: Dictionary = {}) -> Dictionary:
	var payload := {
		"kind": PROJECTILE_HIT_EVENT,
		"projectileId": projectile_id,
		"source": source,
		"target": target,
		"hitPosition": hit_position,
		"flyTime": fly_time,
		"flyDistance": fly_distance,
	}
	for key in options.keys():
		payload[key] = options[key]
	return payload

static func create_projectile_miss_event(projectile_id: String, source, reason: String, final_position: Vector3, fly_time: float, target = null) -> Dictionary:
	var payload := {
		"kind": PROJECTILE_MISS_EVENT,
		"projectileId": projectile_id,
		"source": source,
		"reason": reason,
		"finalPosition": final_position,
		"flyTime": fly_time,
	}
	if target != null:
		payload["target"] = target
	return payload

static func create_projectile_despawn_event(projectile_id: String, source, reason: String) -> Dictionary:
	return {
		"kind": PROJECTILE_DESPAWN_EVENT,
		"projectileId": projectile_id,
		"source": source,
		"reason": reason,
	}

static func create_projectile_pierce_event(projectile_id: String, source, target, pierce_position: Vector3, pierce_count: int, damage = null) -> Dictionary:
	var payload := {
		"kind": PROJECTILE_PIERCE_EVENT,
		"projectileId": projectile_id,
		"source": source,
		"target": target,
		"piercePosition": pierce_position,
		"pierceCount": pierce_count,
	}
	if damage != null:
		payload["damage"] = damage
	return payload

static func is_projectile_launched_event(event: Dictionary) -> bool:
	return event.get("kind", "") == PROJECTILE_LAUNCHED_EVENT

static func is_projectile_hit_event(event: Dictionary) -> bool:
	return event.get("kind", "") == PROJECTILE_HIT_EVENT

static func is_projectile_miss_event(event: Dictionary) -> bool:
	return event.get("kind", "") == PROJECTILE_MISS_EVENT

static func is_projectile_despawn_event(event: Dictionary) -> bool:
	return event.get("kind", "") == PROJECTILE_DESPAWN_EVENT

static func is_projectile_pierce_event(event: Dictionary) -> bool:
	return event.get("kind", "") == PROJECTILE_PIERCE_EVENT
