# Issues & Gotchas - Strong Typed Events Refactor

## [2026-01-28T16:18:46Z] Session: ses_3faee1563ffe6ImBUfctOVUqAn

### Known Issues from Momus Review
1. ✅ FIXED: Actor.hex_coord → actor.getPositionSnapshot()
2. ✅ FIXED: Test command → use run_tests.tscn not run_tests.gd
3. ✅ FIXED: BattleEvents._damage_type_to_string() static method call

### Potential Gotchas
- Task 6 merged into Task 3 (ActorRecordData → ActorInitData)
- Task 8.5 added to handle 22 HexBattleReplayEvents references in logic layer
- GDScript class_name auto-discovery: no need for preload/const
