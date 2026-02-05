# Logic Game Framework 使用规范

## 1. 属性访问规范

针对拥有attribute_set的actor

**直接访问 `actor.attribute_set`，不要为每个属性创建 getter/setter**

```gdscript
# ✅ 推荐
var hp := actor.attribute_set.hp
actor.attribute_set.hp -= damage

# ❌ 不推荐
func get_hp() -> float:
    return attribute_set.hp
```

**例外：语义化方法** - 只为包含业务逻辑的操作封装方法

```gdscript
class_name CharacterActor extends Node

var attribute_set: AttributeSet  # 公开访问

# ✅ 有业务逻辑
func is_alive() -> bool:
    return attribute_set.hp > 0

func take_damage(amount: float) -> void:
    var old_hp := attribute_set.hp
    attribute_set.hp = max(0, attribute_set.hp - amount)
    if old_hp > 0 and attribute_set.hp <= 0:
        emit_signal("died")

# ❌ 单纯转发
# func get_hp() -> float:
#     return attribute_set.hp
```
