# Lab Content Contract

Status: documented stub/import contract for the L2 vertical slice.

The current game still runs on project-local handwritten stub configs. This is intentional until `inkmon-lab` finishes the canon schema reset and exporter. The contract below defines the JSON shape that future lab exports must satisfy before replacing the stubs.

## Runtime Boundary

- Current runtime source: `InkMonUnitConfig`, `InkMonItemCatalog`, and project-local skill classes under `scenes/inkmon-battle/`.
- Future import source: one lab-generated JSON document matching schema `inkmon.l2.content.v1`.
- Validation entry: `InkMonL2ContentContract.validate_export(data) -> Array[String]`.
- Current smoke: `./tools/run_tests.ps1 inkmon/content`.

L2 must not consume partially migrated canon data. A lab export either validates fully or remains outside the runtime.

## Required Export Shape

Top-level fields:

- `schema`: exactly `inkmon.l2.content.v1`
- `version`: `1`
- `units`: non-empty array
- `skill_pools`: non-empty array
- `skills`: non-empty array
- `items`: non-empty array

Unit fields:

- `id`, `display_name`, `species`
- `stage`: `baby`, `mature`, or `adult`
- `role`: `tank`, `dps`, `healer`, or `flex`
- `elements`: one or more of `fire`, `water`, `wind`, `light`, `dark`
- `base_stats`: `max_hp`, `ad`, `ap`, `armor`, `mr`, `speed`
- `skill_slots`: slot number plus `pool_id`
- `fallback_active_skill_id`: temporary bridge for the current one-active-skill runtime

Deferred fields must stay documented instead of silently appearing in runtime data:

- multi-slot active kit selection
- skill variance values
- evolution tables
- engraving/medal effect payloads
- canon Equipment mapping if lab item domain changes

## Validation Path

`InkMonL2ContentContract.build_current_stub_export()` builds a JSON-like export from the current project stubs and validates it with the same validator intended for lab output. The smoke also round-trips through `JSON.stringify` / `JSON.parse_string` and checks that old canon stat keys such as `bst` / `special_attack` are absent.

Future replacement steps:

1. Add lab exporter that writes `inkmon.l2.content.v1`.
2. Add a fixture export from `inkmon-lab`.
3. Run `InkMonL2ContentContract.validate_export()` in a smoke before runtime import.
4. Only after validation passes, add a mapper from export units/items/skills into project runtime config resources or data tables.
