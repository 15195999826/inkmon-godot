# Single Stage Tile 6 Variants

Candidate-only raw generation for testing the direction: AI owns individual tile surface identity, Blender owns final inter-tile seam treatment.

## Inputs

- Base template: `blender/templates/template_design_e0.png`
- Style reference: `docs/concept.jpg`
- Quality: `low`
- Size: `1024x1024`
- Mode: one `n=1` call per tile, template locked

## Outputs

| File | Theme | Call | Image | Initial note |
|---|---|---|---|---|
| `raw/tile_01_grass_meadow.png` | olive grass meadow | `call_mqhspbs6_tp0i6` | `img_mqhspwfa_bopmi` | Usable. Clear top, light rim, some small weeds. |
| `raw/tile_02_cracked_dry_earth.png` | cracked dry earth | `call_mqhsqiyf_x4063` | `img_mqhsrr36_h7j95` | Usable. Good material contrast, clean silhouette. |
| `raw/tile_03_mossy_flagstone.png` | mossy flagstone floor | `call_mqhssdzc_qjbbd` | `img_mqhst9fu_mpp8h` | Usable, but cracks are strong and may read as ink if repeated. |
| `raw/tile_04_dirt_arena.png` | scuffed dirt arena | `call_mqhsu1ri_2l37h` | `img_mqhsv4gp_pbm2j` | Usable. Strong independent stage identity. |
| `raw/tile_05_pale_limestone.png` | pale limestone slab | `call_mqhsvoz4_ccano` | `img_mqhswjwp_630ka` | Usable, but edge highlight is bright; may need bake tuning. |
| `raw/tile_06_dark_forest_floor.png` | dark forest floor | `call_mqhsx2zm_l13tp` | `img_mqhsxwi5_jbb1g` | Usable as a contrast tile, but overall value is dark. |

Preview:

- `raw_tile_6_contact_sheet.png`

## Conclusion

This direction is better than whole-map generation. Whole-map generation makes AI own the seams and tends to produce hard outlines. Single-tile generation keeps content controllable, while the narrow dark crevice and upper-edge light should be generated deterministically in Blender during map assembly.
