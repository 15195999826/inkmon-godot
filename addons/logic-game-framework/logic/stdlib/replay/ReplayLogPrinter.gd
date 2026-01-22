extends RefCounted
class_name ReplayLogPrinter

static func print_record(record: Dictionary) -> void:
	var meta = record.get("meta", {})
	var timeline = record.get("timeline", [])
	var initial_actors = record.get("initialActors", [])

	print("==========================================")
	print("Battle Replay Log")
	print("==========================================")
	print("")
	print("## Meta Information")
	print("Battle ID: %s" % meta.get("battleId", ""))
	print("Recorded At: %s" % _format_timestamp(meta.get("recordedAt", 0)))
	print("Tick Interval: %sms" % meta.get("tickInterval", 100))
	print("Total Frames: %d" % meta.get("totalFrames", 0))
	print("Result: %s" % meta.get("result", "unknown"))
	print("")

	print("## Initial Actors (%d)" % initial_actors.size())
	for actor_data in initial_actors:
		print("  - %s (%s)" % [actor_data.get("displayName", ""), actor_data.get("id", "")])
		print("    Team: %s" % actor_data.get("team", "none"))
		if actor_data.has("position"):
			var pos = actor_data.position
			if pos.has("world"):
				print("    Position: (%.1f, %.1f, %.1f)" % [pos.world.x, pos.world.y, pos.world.z])
		if actor_data.get("tags", {}).size() > 0:
			print("    Tags: %s" % str(actor_data.tags.keys()))
	print("")

	print("## Timeline (%d frames with events)" % timeline.size())
	for frame_data in timeline:
		var frame_val = frame_data.get("frame",0)
		var events = frame_data.get("events", [])
		if events.is_empty():
			continue
		print("Frame %d (%d events):" % [frame_val, events.size()])
		for event in events:
			_print_event(event, frame_val)

	print("==========================================")
	print("==========================================")

static func _format_timestamp(timestamp: int) -> String:
	var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]

static func _print_event(event: Dictionary, frame: int) -> void:
	var kind = str(event.get("kind", ""))
	var indent = "    "

	print("%s[%s] %s" % [indent, kind, str(event).substr(0, 100)])

	match kind:
		"actorSpawned":
			print("%s  Actor: %s (%s)" % [indent, event.get("displayName", ""), event.get("actorId", "")])
		"actorDestroyed":
			print("%s  Actor: %s, Reason: %s" % [indent, event.get("actorId", ""), event.get("reason", "")])
		"damage":
			print("%s  Source: %s -> Target: %s, Damage: %s" % [
				indent, event.get("sourceId", ""), event.get("targetId", ""), event.get("damage", 0)
			])
		"heal":
			print("%s  Target: %s, Heal: %s" % [indent, event.get("targetId", ""), event.get("heal", 0)])
		"abilityGranted":
			print("%s  Actor: %s, Ability: %s" % [indent, event.get("ownerId", ""), event.get("abilityId", "")])
		"abilityRemoved":
			print("%s  Actor: %s, Ability: %s, Reason: %s" % [
				indent, event.get("ownerId", ""), event.get("abilityId", ""), event.get("reason", "")
			])
		"tagChanged":
			print("%s  Actor: %s, Tag: %s, Stacks: %d" % [
				indent, event.get("actorId", ""), event.get("tagName", ""), event.get("stacks", 0)
			])
		"stageCue":
			print("%s  Source: %s, Cue: %s" % [indent, event.get("sourceActorId", ""), event.get("cueId", "")])
		_:
			for key in event.keys():
				if key != "kind" and key != "timestamp":
					print("%s  %s: %s" % [indent, key, str(event[key])])
