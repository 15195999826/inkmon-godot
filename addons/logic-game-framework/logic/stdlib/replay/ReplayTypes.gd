extends RefCounted
class_name ReplayTypes

const REPLAY_PROTOCOL_VERSION = "2.0"

class ReplayBattleRecord:
	var version: String
	var meta: Dictionary
	var configs: Dictionary
	var initial_actors: Array
	var timeline: Array

class ReplayMeta:
	var battle_id: String
	var recorded_at: int
	var tick_interval: float
	var total_frames: int
	var result: String

class ReplayFrameData:
	var frame: int
	var events: Array

class ReplayActorInitData:
	var id: String
	var config_id: String
	var display_name: String
	var team
	var position: Dictionary
	var attributes: Dictionary
	var abilities: Array
	var tags: Dictionary

class ReplayAbilityInitData:
	var instance_id: String
	var config_id: String
	var remaining_cooldown: float
	var stack_count: int

class RecordingContext:
	var actor_id: String
	var get_logic_time: Callable
	var push_event: Callable

class RecordableActorInterface:
	var id: String
	var config_id: String
	var display_name: String
	var team
	var position: Vector3
	var get_attribute_snapshot: Callable
	var get_ability_snapshot: Callable
	var get_tag_snapshot: Callable
	var setup_recording: Callable
