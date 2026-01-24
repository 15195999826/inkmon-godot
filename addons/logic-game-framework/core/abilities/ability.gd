extends RefCounted
class_name Ability

const STATE_PENDING := "pending"
const STATE_GRANTED := "granted"
const STATE_EXPIRED := "expired"

var id: String
var config_id: String
var source: ActorRef
var owner: ActorRef
var display_name: String = ""
var description: String = ""
var icon: String = ""
var tags: Array = []

var _state: String = STATE_PENDING
var _expire_reason: String = ""
var _components: Array = []
var _lifecycle_context = null
var _execution_instances: Array = []
var _on_triggered_callbacks: Array = []
var _on_execution_callbacks: Array = []

func _init(config: AbilityConfig, owner_value: ActorRef, source_value: ActorRef = null):
	id = IdGenerator.generate("ability")
	config_id = config.config_id
	owner = owner_value
	source = source_value if source_value else owner_value
	display_name = config.display_name
	description = config.description
	icon = config.icon
	tags = config.tags

	_components = _resolve_components(config.active_use_components, config.components)

	for component in _components:
		if component and component.has_method("initialize"):
			component.initialize(self)

func get_state() -> String:
	return _state

func is_granted() -> bool:
	return _state == STATE_GRANTED

func is_expired() -> bool:
	return _state == STATE_EXPIRED

func get_expire_reason() -> String:
	return _expire_reason

func get_component(ctor) -> Variant:
	for component in _components:
		if _component_matches(component, ctor):
			return component
	return null

func get_components(ctor) -> Array:
	var results := []
	for component in _components:
		if _component_matches(component, ctor):
			results.append(component)
	return results

func has_component(ctor) -> bool:
	for component in _components:
		if _component_matches(component, ctor):
			return true
	return false

func _component_matches(component, ctor) -> bool:
	if typeof(component) != TYPE_OBJECT:
		return false
	if typeof(ctor) == TYPE_STRING:
		return component.get_class() == ctor
	if ctor is Script:
		return component.get_script() == ctor
	return component.get_class() == str(ctor)

func get_all_components() -> Array:
	return _components

func tick(dt: float) -> void:
	if _state == STATE_EXPIRED:
		return
	for component in _components:
		if component and component.has_method("get_state") and component.get_state() == "active":
			if component.has_method("on_tick"):
				component.on_tick(dt)

func tick_executions(dt: float) -> Array:
	if _state == STATE_EXPIRED:
		return []
	var all_triggered := []
	for instance in _execution_instances:
		if _is_executing_instance(instance):
			all_triggered.append_array(instance.tick(dt))
	_execution_instances = _execution_instances.filter(_is_executing_instance)
	return all_triggered

func activate_new_execution_instance(config: Dictionary):
	var instance = AbilityExecutionInstance.new({
		"timelineId": config.get("timelineId", ""),
		"tagActions": config.get("tagActions", {}),
		"eventChain": config.get("eventChain", []),
		"gameplayState": config.get("gameplayState", null),
		"abilityInfo": {
			"id": id,
			"configId": config_id,
			"owner": owner,
			"source": source,
		},
	})
	_execution_instances.append(instance)
	for callback in _on_execution_callbacks:
		if callback.is_valid():
			callback.call(instance)
	instance.tick(0)
	return instance

func get_executing_instances() -> Array:
	return _execution_instances.filter(_is_executing_instance)

func get_all_execution_instances() -> Array:
	return _execution_instances

func cancel_all_executions() -> void:
	for instance in _execution_instances:
		if instance and instance.has_method("cancel"):
			instance.cancel()
	_execution_instances = []

func receive_event(event: Dictionary, context: Dictionary, gameplay_state) -> void:
	if _state == STATE_EXPIRED:
		return
	var triggered_components := []
	for component in _components:
		if typeof(component) != TYPE_OBJECT:
			continue
		if not _is_active_component(component):
			continue
		if component.has_method("on_event"):
			if component.on_event(event, context, gameplay_state):
				triggered_components.append(_get_component_name(component))
	if not triggered_components.is_empty():
		for callback in _on_triggered_callbacks:
			if callback.is_valid():
				callback.call(event, triggered_components)

func add_triggered_listener(callback: Callable) -> Callable:
	_on_triggered_callbacks.append(callback)
	return func() -> void:
		var index := _on_triggered_callbacks.find(callback)
		if index != -1:
			_on_triggered_callbacks.remove_at(index)

func add_execution_activated_listener(callback: Callable) -> Callable:
	_on_execution_callbacks.append(callback)
	return func() -> void:
		var index := _on_execution_callbacks.find(callback)
		if index != -1:
			_on_execution_callbacks.remove_at(index)

func apply_effects(context: Dictionary) -> void:
	if _state == STATE_GRANTED:
		Log.warning("Ability", "Ability already granted: %s" % id)
		return
	_state = STATE_GRANTED
	_lifecycle_context = context
	for component in _components:
		if component and component.has_method("on_apply"):
			component.on_apply(context)

func remove_effects() -> void:
	if _lifecycle_context == null:
		return
	for component in _components:
		if component and component.has_method("on_remove"):
			component.on_remove(_lifecycle_context)
	_lifecycle_context = null

func expire(reason: String) -> void:
	if _state == STATE_EXPIRED:
		return
	_expire_reason = reason
	remove_effects()
	_state = STATE_EXPIRED

func has_tag(tag: String) -> bool:
	return tags.has(tag)

func serialize() -> Dictionary:
	var serialized_components := []
	for component in _components:
		if component and component.has_method("serialize"):
			serialized_components.append({
				"type": component.type,
				"data": component.serialize(),
			})
	var serialized_instances := []
	for instance in _execution_instances:
		if instance and instance.has_method("serialize"):
			serialized_instances.append(instance.serialize())
	return {
		"id": id,
		"configId": config_id,
		"source": source,
		"owner": owner,
		"state": _state,
		"displayName": display_name,
		"tags": tags,
		"components": serialized_components,
		"executionInstances": serialized_instances,
	}

func _resolve_components(active_use_configs: Array, component_configs: Array) -> Array:
	var result := []
	
	# 解析 ActiveUseConfig -> ActiveUseComponent
	for cfg in active_use_configs:
		if cfg is ActiveUseConfig:
			result.append(ActiveUseComponent.new(cfg))
		elif cfg is Callable:
			result.append(cfg.call())
		else:
			result.append(cfg)
	
	# 解析组件配置
	for cfg in component_configs:
		if cfg is ActivateInstanceConfig:
			result.append(ActivateInstanceComponent.new(cfg))
		elif cfg is NoInstanceConfig:
			result.append(NoInstanceComponent.new(cfg))
		elif cfg is PreEventConfig:
			result.append(PreEventComponent.new(cfg))
		elif cfg is Callable:
			result.append(cfg.call())
		else:
			result.append(cfg)
	
	return result

func _is_executing_instance(instance) -> bool:
	return instance and instance.has_method("is_executing") and instance.is_executing()

func _is_active_component(component) -> bool:
	if component.has_method("is_active"):
		return component.is_active()
	if component.has_method("get_state"):
		return component.get_state() == "active"
	return true

func _get_component_name(component) -> String:
	if component.has_method("get_type"):
		return str(component.get_type())
	if "type" in component:
		return str(component.type)
	return component.get_class()
