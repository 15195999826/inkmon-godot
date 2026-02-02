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

func tick(actors: Array, dt: float) -> void:
	var projectiles := []
	var potential_targets := []

	for actor in actors:
		if actor is ProjectileActor and actor.is_flying():
			projectiles.append(actor)
		elif actor is Actor:
			potential_targets.append(actor)

	for projectile in projectiles:
		_update_projectile(projectile, potential_targets, dt)

	if auto_remove:
		_process_pending_removal(actors)

func _update_projectile(projectile: ProjectileActor, potential_targets: Array, dt: float) -> void:
	if projectile.config.get("projectileType", "bullet") == ProjectileActor.PROJECTILE_TYPE_HITSCAN:
		_process_hitscan(projectile, potential_targets)
		return

	var still_flying = projectile.update(dt)

	if not still_flying:
		if projectile.get_projectile_state() == ProjectileActor.STATE_MISSED:
			_emit_miss_event(projectile, "timeout")
		_mark_for_removal(projectile)
		return

	var valid_targets = _filter_valid_targets(projectile, potential_targets)
	var collision = collision_detector.detect(projectile, valid_targets)

	if collision.get("hit", false) and collision.get("target"):
		_process_hit(projectile, collision)

func _process_hitscan(projectile: ProjectileActor, potential_targets: Array) -> void:
	var valid_targets = _filter_valid_targets(projectile, potential_targets)

	var target: ActorRef = projectile.get_target()
	if target:
		var target_actor: Actor = null
		for actor in potential_targets:
			if actor is Actor and actor.id == target.id:
				target_actor = actor
				break
		if target_actor:
			var hit_position: Vector3 = projectile.position if projectile.position else target_actor.position
			projectile.hit(target.id)
			_emit_hit_event(projectile, target, hit_position)
			_mark_for_removal(projectile)
			return

	var collision = collision_detector.detect(projectile, valid_targets)
	if collision.get("hit", false) and collision.get("target"):
		var hit_target: ActorRef = collision.get("target")
		projectile.hit(hit_target.id)
		_emit_hit_event(projectile, hit_target, collision.get("hitPosition"))
	else:
		projectile.miss("no_target")
		_emit_miss_event(projectile, "no_target")

	_mark_for_removal(projectile)

func _process_hit(projectile: ProjectileActor, collision: Dictionary) -> void:
	var target: ActorRef = collision.get("target")
	var hit_position: Vector3 = collision.get("hitPosition")

	if not target or not hit_position:
		return

	var continue_flying = projectile.hit(target.id)

	if continue_flying:
		_emit_pierce_event(projectile, target, hit_position)
	else:
		_emit_hit_event(projectile, target, hit_position)
		_mark_for_removal(projectile)

func _filter_valid_targets(projectile: ProjectileActor, potential_targets: Array) -> Array:
	var source_ref: ActorRef = projectile.get_source()
	var source_id: String = source_ref.id if source_ref else ""

	var valid := []
	for target in potential_targets:
		if not (target is Actor):
			continue

		if source_id and target.id == source_id:
			continue

		if projectile.has_hit_target(target.id):
			continue

		valid.append(target)

	return valid

func _mark_for_removal(projectile: ProjectileActor) -> void:
	pending_removal[projectile.id] = true

func _process_pending_removal(actors: Array) -> void:
	# Remove marked projectiles from actors array
	var i = 0
	while i < actors.size():
		var actor = actors[i]
		if actor is ProjectileActor and pending_removal.has(actor.id):
			actors.remove_at(i)
		else:
			i += 1
	pending_removal.clear()

func _emit_hit_event(projectile: ProjectileActor, target: ActorRef, hit_position: Vector3) -> void:
	if not event_collector:
		return

	var source: ActorRef = projectile.get_source() if projectile.get_source() else ActorRef.new("unknown")
	var event = ProjectileEvents.create_projectile_hit_event(
		projectile.id,
		source,
		target,
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

	var source: ActorRef = projectile.get_source() if projectile.get_source() else ActorRef.new("unknown")
	var final_position := projectile.position

	var event = ProjectileEvents.create_projectile_miss_event(
		projectile.id,
		source,
		reason,
		final_position,
		projectile.get_fly_time(),
		projectile.get_target()
	)

	event_collector.push(event)

	var despawn_event = ProjectileEvents.create_projectile_despawn_event(
		projectile.id,
		source,
		"miss"
	)

	event_collector.push(despawn_event)

func _emit_pierce_event(projectile: ProjectileActor, target: ActorRef, pierce_position: Vector3) -> void:
	if not event_collector:
		return

	var source: ActorRef = projectile.get_source() if projectile.get_source() else ActorRef.new("unknown")
	var event = ProjectileEvents.create_projectile_pierce_event(
		projectile.id,
		source,
		target,
		pierce_position,
		projectile.get_pierce_count(),
		projectile.config.get("damage")
	)

	event_collector.push(event)

func get_active_projectiles(actors: Array) -> Array:
	var projectiles := []
	for actor in actors:
		if actor is ProjectileActor and actor.is_flying():
			projectiles.append(actor)
	return projectiles

func get_pending_removal_ids() -> Dictionary:
	return pending_removal.duplicate()

func force_hit(projectile: ProjectileActor, target: ActorRef, hit_position: Vector3) -> void:
	if not projectile.is_flying():
		return

	projectile.hit(target.id)
	_emit_hit_event(projectile, target, hit_position)
	_mark_for_removal(projectile)

func force_miss(projectile: ProjectileActor, reason: String = "forced") -> void:
	if not projectile.is_flying():
		return

	projectile.miss(reason)
	_emit_miss_event(projectile, reason)
	_mark_for_removal(projectile)
