extends RefCounted
class_name ActivationContext

var source: ActorRef
var targets: Array
var logic_time: float

func _init(source_value: ActorRef, targets_value: Array = null, logic_time_value: float = 0.0):
	source = source_value
	targets = targets_value if targets_value != null else []
	logic_time = logic_time_value
