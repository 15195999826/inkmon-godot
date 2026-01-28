# Architectural Decisions - hex-battle-refactor

## Session: ses_3fa41049cffewEEqrg8wYw4G4U
Started: 2026-01-28T18:22:19.781Z

---

## Key Decisions from Planning

1. **_actors Storage**: HexBattle retains its own `_actors: Dictionary` (key=id) for O(1) lookup performance, overriding parent class methods instead of modifying framework layer.

2. **base_tick() Integration**: HexBattle.tick() will call base_tick(dt) to support future System integration, even though no Systems are used currently.

3. **GameWorld Registration**: Calling code (main.gd, etc.) is responsible for registering HexBattle with GameWorld, not HexBattle itself.

4. **Logic Time Management**: Remove HexBattle's own logic_time property, use parent class's _logic_time instead.

5. **Migration Scope**: All 3 calling points (main.gd, SimulationManager.gd, hex-atb-battle-frontend/main.gd) will be migrated.

---
