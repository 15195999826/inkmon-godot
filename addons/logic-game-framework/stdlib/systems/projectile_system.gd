extends System
class_name ProjectileSystem

var collision_detector: CollisionDetector
var event_collector: EventCollector
var pending_removal: Dictionary = {}
var auto_remove: bool = true

func _init(detector: CollisionDetector = null, collector: EventCollector = null, auto_remove_val: bool = true):
	super(System.SystemPriority.NORMAL)
	type = "ProjectileSystem"

	collision_detector = detector if detector else DistanceCollisionDetector.new(50.0)
	event_collector = collector
	auto_remove = auto_remove_val

func set_event_collector(collector: EventCollector) -> void:
	event_collector = collector

func tick(actors: Array[Actor], dt: float) -> void:
	var projectiles: Array[ProjectileActor] = []
	var potential_targets: Array[Actor] = []

	for actor in actors:
		if actor is ProjectileActor and actor.is_flying():
			projectiles.append(actor)
		elif actor is Actor:
			potential_targets.append(actor)

	for projectile in projectiles:
		_update_projectile(projectile, potential_targets, dt)

	if auto_remove:
		_process_pending_removal(actors)

func _update_projectile(projectile: ProjectileActor, potential_targets: Array[Actor], dt: float) -> void:
	if projectile.config.get("projectileType", "bullet") == ProjectileActor.PROJECTILE_TYPE_HITSCAN:
		_process_hitscan(projectile, potential_targets)
		return

	var still_flying := projectile.update(dt)

	if not still_flying:
		if projectile.get_projectile_state() == ProjectileActor.STATE_MISSED:
			_emit_miss_event(projectile, "timeout")
		_mark_for_removal(projectile)
		return

	var valid_targets := _filter_valid_targets(projectile, potential_targets)
	var collision := collision_detector.detect(projectile, valid_targets)

	if collision.get("hit", false) and collision.get("target_actor_id", "") != "":
		_process_hit(projectile, collision)

func _process_hitscan(projectile: ProjectileActor, potential_targets: Array[Actor]) -> void:
	var valid_targets := _filter_valid_targets(projectile, potential_targets)

	var target_actor_id: String = projectile.get_target_actor_id()
	if target_actor_id != "":
		var target_actor: Actor = null
		for actor in potential_targets:
			if actor is Actor and actor.id == target_actor_id:
				target_actor = actor
				break
		if target_actor:
			var hit_position := projectile.position
			projectile.hit(target_actor_id)
			_emit_hit_event(projectile, target_actor_id, hit_position)
			_mark_for_removal(projectile)
			return

	var collision := collision_detector.detect(projectile, valid_targets)
	if collision.get("hit", false) and collision.get("target_actor_id", "") != "":
		var hit_target_actor_id: String = collision.get("target_actor_id", "")
		projectile.hit(hit_target_actor_id)
		var collision_hit_position: Vector3 = collision.get("hitPosition", Vector3.ZERO) as Vector3
		_emit_hit_event(projectile, hit_target_actor_id, collision_hit_position)
	else:
		projectile.miss("no_target")
		_emit_miss_event(projectile, "no_target")

	_mark_for_removal(projectile)

func _process_hit(projectile: ProjectileActor, collision: Dictionary) -> void:
	var target_actor_id: String = collision.get("target_actor_id", "")
	var hit_position_raw: Variant = collision.get("hitPosition", null)

	if target_actor_id == "" or not (hit_position_raw is Vector3):
		return

	var hit_position := hit_position_raw as Vector3
	var continue_flying := projectile.hit(target_actor_id)

	if continue_flying:
		_emit_pierce_event(projectile, target_actor_id, hit_position)
	else:
		_emit_hit_event(projectile, target_actor_id, hit_position)
		_mark_for_removal(projectile)

func _filter_valid_targets(projectile: ProjectileActor, potential_targets: Array[Actor]) -> Array[Actor]:
	var source_actor_id: String = projectile.get_source_actor_id()

	var valid: Array[Actor] = []
	for target in potential_targets:
		if not (target is Actor):
			continue

		if source_actor_id != "" and target.id == source_actor_id:
			continue

		if projectile.has_hit_target(target.id):
			continue

		valid.append(target)

	return valid

func _mark_for_removal(projectile: ProjectileActor) -> void:
	pending_removal[projectile.id] = true

func _process_pending_removal(actors: Array[Actor]) -> void:
	if pending_removal.is_empty():
		return
	var remaining: Array[Actor] = []
	for actor in actors:
		if actor is ProjectileActor and pending_removal.has(actor.id):
			continue
		remaining.append(actor)
	actors.clear()
	for actor in remaining:
		actors.append(actor)
	pending_removal.clear()

func _emit_hit_event(projectile: ProjectileActor, target_actor_id: String, hit_position: Vector3) -> void:
	if not event_collector:
		return

	var source_actor_id: String = projectile.get_source_actor_id()
	if source_actor_id == "":
		source_actor_id = "unknown"
	var event := ProjectileEvents.create_projectile_hit_event(
		projectile.id,
		source_actor_id,
		target_actor_id,
		hit_position,
		projectile.get_fly_time(),
		projectile.get_fly_distance(),
		{
			"damage": projectile.config.get("damage"),
			"damageType": projectile.config.get("damageType"),
		}
	)

	event_collector.push(event)

func _emit_miss_event(projectile: ProjectileActor, reason: String) -> void:
	if not event_collector:
		return

	var source_actor_id: String = projectile.get_source_actor_id()
	if source_actor_id == "":
		source_actor_id = "unknown"
	var final_position := projectile.position

	var event := ProjectileEvents.create_projectile_miss_event(
		projectile.id,
		source_actor_id,
		reason,
		final_position,
		projectile.get_fly_time(),
		projectile.get_target_actor_id()
	)

	event_collector.push(event)

	var despawn_event := ProjectileEvents.create_projectile_despawn_event(
		projectile.id,
		source_actor_id,
		"miss"
	)

	event_collector.push(despawn_event)

func _emit_pierce_event(projectile: ProjectileActor, target_actor_id: String, pierce_position: Vector3) -> void:
	if not event_collector:
		return

	var source_actor_id: String = projectile.get_source_actor_id()
	if source_actor_id == "":
		source_actor_id = "unknown"
	var event := ProjectileEvents.create_projectile_pierce_event(
		projectile.id,
		source_actor_id,
		target_actor_id,
		pierce_position,
		projectile.get_pierce_count(),
		projectile.config.get("damage")
	)

	event_collector.push(event)

func get_active_projectiles(actors: Array[Actor]) -> Array[ProjectileActor]:
	var projectiles: Array[ProjectileActor] = []
	for actor in actors:
		if actor is ProjectileActor and actor.is_flying():
			projectiles.append(actor)
	return projectiles

func get_pending_removal_ids() -> Dictionary:
	return pending_removal.duplicate()

func force_hit(projectile: ProjectileActor, target_actor_id: String, hit_position: Vector3) -> void:
	if not projectile.is_flying():
		return

	projectile.hit(target_actor_id)
	_emit_hit_event(projectile, target_actor_id, hit_position)
	_mark_for_removal(projectile)

func force_miss(projectile: ProjectileActor, reason: String = "forced") -> void:
	if not projectile.is_flying():
		return

	projectile.miss(reason)
	_emit_miss_event(projectile, reason)
	_mark_for_removal(projectile)
