extends RefCounted
class_name ActivationContext

var source: ActorRef
var targets: Array
var logic_time: float

func _init(source_value: ActorRef, targets_value: Array, logic_time_value: float) -> void:
	source = source_value
	targets = targets_value
	logic_time = logic_time_value
