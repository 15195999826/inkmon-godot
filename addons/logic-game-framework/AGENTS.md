# Logic Game Framework - Architecture Overview

> **Coding conventions** have been moved to the `lgf` skill (`.opencode/skill/lgf/SKILL.md`).
> Use `load_skills=["lgf"]` when delegating tasks that involve this framework.

---

## Core Module Dependencies

```mermaid
graph TB
    subgraph "Core"
        World[GameWorld<br/>Autoload]
        Entity[Entity System<br/>Actor/System]
        Attributes[Attribute System<br/>RawAttributeSet]
        Abilities[Ability System<br/>Ability/AbilitySet]
        Events[Event System<br/>EventProcessor]
        Actions[Action System<br/>BaseAction]
        Timeline[Timeline System<br/>TimelineRegistry]
        Tags[Tag System<br/>TagContainer]
    end
    
    subgraph "Stdlib"
        Components[Components<br/>StatModifier/Duration]
        Systems[Systems<br/>ProjectileSystem]
        Replay[Replay System<br/>BattleRecorder]
    end
    
    subgraph "Example"
        HexBattle[HexBattle<br/>ATB Battle]
        Frontend[Frontend<br/>Presentation Layer]
    end
    
    World --> Entity
    World --> Events
    Entity --> Abilities
    Abilities --> Attributes
    Abilities --> Tags
    Abilities --> Actions
    Abilities --> Timeline
    Actions --> Events
    Components --> Abilities
    Systems --> Entity
    Replay --> Events
    HexBattle --> World
    HexBattle --> Replay
    Frontend --> Replay
```

## Key Data Flows

### 1. Ability Execution Flow
```
User Input → AbilityComponent.on_event()
    ↓ Check Triggers/Conditions/Costs
AbilityExecutionInstance.tick()
    ↓ Timeline keyframe triggers
Action.execute()
    ↓ Pre-Event processing (damage reduction/immunity)
Atomic operations (push event + apply state)
    ↓ Post-Event processing (thorns/lifesteal)
EventCollector collects (replay recording)
```

### 2. Attribute Modification Flow
```
StatModifierComponent.on_apply()
    ↓ Create AttributeModifier
RawAttributeSet.add_modifier()
    ↓ Mark dirty
Actor accesses attribute
    ↓ get_current_value()
AttributeCalculator.calculate()
    ↓ 4-layer formula calculation
Return AttributeBreakdown
```

### 3. Event Processing Flow
```
Action pushes event
    ↓
EventProcessor.process_pre_event()
    ↓ Iterate Pre Handlers
    ↓ Collect Intent (PASS/MODIFY/CANCEL)
    ↓ Apply modifications
MutableEvent returned
    ↓ Action checks if cancelled
EventProcessor.process_post_event()
    ↓ Broadcast to all alive Actors
    ↓ Trigger passive abilities
EventCollector.push()
```