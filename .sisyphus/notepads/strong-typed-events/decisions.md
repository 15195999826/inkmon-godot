# Architectural Decisions - Strong Typed Events Refactor

## [2026-01-28T16:18:46Z] Session: ses_3faee1563ffe6ImBUfctOVUqAn

### Three-Layer Architecture
- **hex-atb-battle-core**: Shared data layer (events, ActorInitData)
- **hex-atb-battle**: Logic layer (battle computation)
- **hex-atb-battle-frontend**: Presentation layer (3D rendering, replay)

### Serialization Strategy
- Dictionary keys: camelCase (JSON compatibility)
- Class properties: snake_case (GDScript convention)
- Enums: serialize to lowercase strings

### Backward Compatibility
- Keep replay JSON format unchanged
- Preserve old factory functions (mark as @deprecated)
- No breaking changes to public APIs
