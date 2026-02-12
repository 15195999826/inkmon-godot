# Attributes API

## Contents
- [RawAttributeSet](#rawattributeset-extends-refcounted)
- [AttributeModifier](#attributemodifier-extends-refcounted)
- [AttributeCalculator](#attributecalculator-static-utility)
- [AttributeBreakdown](#attributebreakdown)
- [BaseGeneratedAttributeSet](#basegeneratedattributeset-extends-refcounted)
- [TagContainer](#tagcontainer-extends-refcounted)

## RawAttributeSet (extends RefCounted)

Core attribute storage with modifier system and 4-layer calculation formula.

**Formula:** `currentValue = ((base + addBaseSum) * mulBaseProduct + addFinalSum) * mulFinalProduct`

**Define:**
- `define_attribute(attr_name: String, base_value: float, min_value: float = -INF, max_value: float = INF) -> void`
- `has_attribute(attr_name: String) -> bool`
- `apply_config(config: Dictionary) -> void` — Batch define from config
- `static from_config(config: Dictionary) -> RawAttributeSet`

**Read:**
- `get_base(attr_name: String) -> float`
- `get_body_value(attr_name: String) -> float` — (base + addBase) * mulBase
- `get_current_value(attr_name: String) -> float` — Final value after all modifiers
- `get_breakdown(attr_name: String) -> AttributeBreakdown` — Full calculation breakdown
- `get_add_base_sum(attr_name: String) -> float` / `get_mul_base_product(attr_name: String) -> float`
- `get_add_final_sum(attr_name: String) -> float` / `get_mul_final_product(attr_name: String) -> float`

**Write:**
- `set_base(attr_name: String, value: float) -> void`

**Modifiers:**
- `add_modifier(modifier: AttributeModifier) -> void`
- `remove_modifier(modifier_id: String) -> bool`
- `remove_modifiers_by_source(source: String) -> int`
- `update_modifier(modifier_id: String, new_value: float) -> bool`
- `get_modifiers(attr_name: String) -> Array[AttributeModifier]`
- `has_modifier(modifier_id: String) -> bool`

**Dynamic Dependencies:**
- `register_dynamic_dep(modifier_id: String, source_attribute: String, target_attribute: String, modifier_type: AttributeModifier.Type, coefficient: float) -> void`
- `unregister_dynamic_dep(modifier_id: String) -> void`

**Listeners:**
- `add_change_listener(listener: Callable) -> void` / `remove_change_listener(listener: Callable) -> void`
- `remove_all_change_listeners() -> void`
- `on_attribute_changed(attr_name: String, callback: Callable) -> Callable` — Returns unsubscribe
- `set_pre_change(callback: Callable) -> void` / `clear_pre_change() -> void` — Cross-attribute constraints

**Serialization:**
- `serialize() -> Dictionary` / `static deserialize(data: Dictionary) -> RawAttributeSet`
- `static restore_attributes(data: Dictionary) -> RawAttributeSet` — Alias for deserialize

---

## AttributeModifier (extends RefCounted)

Single modifier applied to an attribute.

**Enum:** `Type { ADD_BASE, MUL_BASE, ADD_FINAL, MUL_FINAL }`

**Properties:**
- `id: String` / `attribute_name: String` / `modifier_type: Type` / `value: float` / `source: String`

**Factory:**
- `static create_add_base(p_id: String, p_attribute_name: String, p_value: float, p_source: String = "") -> AttributeModifier`
- `static create_mul_base(p_id: String, p_attribute_name: String, p_value: float, p_source: String = "") -> AttributeModifier`
- `static create_add_final(p_id: String, p_attribute_name: String, p_value: float, p_source: String = "") -> AttributeModifier`
- `static create_mul_final(p_id: String, p_attribute_name: String, p_value: float, p_source: String = "") -> AttributeModifier`

**Serialization:**
- `serialize() -> Dictionary` / `static deserialize(data: Dictionary) -> AttributeModifier`

---

## AttributeCalculator (static utility)

- `static calculate(base_value: float, modifiers: Array[AttributeModifier]) -> AttributeBreakdown`

---

## AttributeBreakdown

Calculation result with all intermediate values.

**Properties:**
- `base: float` — Original base value
- `add_base_sum: float` — Sum of ADD_BASE modifiers
- `mul_base_product: float` — Product of MUL_BASE modifiers (default 1.0)
- `body_value: float` — (base + add_base_sum) * mul_base_product
- `add_final_sum: float` — Sum of ADD_FINAL modifiers
- `mul_final_product: float` — Product of MUL_FINAL modifiers (default 1.0)
- `current_value: float` — (body_value + add_final_sum) * mul_final_product

**Factory:**
- `static from_base(base_value: float) -> AttributeBreakdown`
- `with_clamped_value(clamped: float) -> AttributeBreakdown` — Copy with clamped current_value

---

## BaseGeneratedAttributeSet (extends RefCounted)

Base class for code-generated typed attribute sets. Subclasses provide typed property accessors (e.g. `.hp`, `.attack`).

**Properties:**
- `_raw: RawAttributeSet` — Underlying raw storage
- `actor_id: String`

**Methods:**
- `add_change_listener(listener: Callable) -> Callable` — Returns unsubscribe
- `get_raw() -> RawAttributeSet`
- `set_pre_change(callback: Callable) -> void`

---

## TagContainer (extends RefCounted)

Tag storage with three source layers: loose (manual), auto-duration (time-based), component (lifecycle-bound).

**Factory:**
- `static create(owner_id_value: String) -> TagContainer`

**Loose Tags (manual, never expire):**
- `add_loose_tag(tag: String, stacks: int = 1) -> void`
- `remove_loose_tag(tag: String, stacks: int = -1) -> bool` — stacks=-1 removes all
- `has_loose_tag(tag: String) -> bool` / `get_loose_tag_stacks(tag: String) -> int`

**Auto Duration Tags (time-based expiry):**
- `add_auto_duration_tag(tag: String, duration: float) -> void`
- `get_auto_duration_tag_stacks(tag: String) -> int`
- `cleanup_expired_tags() -> void`

**Component Tags (bound to external lifecycle):**
- `add_component_tags(component_id: String, tags: Dictionary) -> void` — tags: `{ "tag_name": stacks }`
- `remove_component_tags(component_id: String) -> void`

**General Query (all sources):**
- `has_tag(tag: String) -> bool` / `get_tag_stacks(tag: String) -> int`
- `get_all_tags() -> Dictionary`

**Logic Time:**
- `get_logic_time() -> float` / `set_logic_time(logic_time: float) -> void`
- `tick(dt: float, logic_time: float = -1.0) -> void` — Updates time, cleans expired tags

**Events:**
- `on_tag_changed(callback: Callable) -> Callable` — Returns unsubscribe. Callback: `func(tag, old_count, new_count, container)`

**Snapshot:**
- `get_snapshot() -> Dictionary`
