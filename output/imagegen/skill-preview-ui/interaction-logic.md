# SkillPreview UI vNext - Character Panel Interaction Logic

## Goal

Keep the existing SkillPreview control surface intact, and add a dedicated
right-side Character Panel for actor selection, actor editing, runtime state,
and keyframe context.

The panel must not introduce a second actor data source. It reads and mutates
the existing `_actors` model in setup/timeline mode, and reads runtime state
from `_world` / `_last_timeline` in playback mode.

## Layout

- Center: 3D hex viewport remains the primary workspace.
- Left: existing compact controls stay responsible for setup tabs, timeline tab,
  scene config, and run controls.
- Right: new `CharacterPanel` shows actor list plus selected actor details.
- Bottom: existing drawer switches between timeline, log, warnings, and playback
  evidence.

## Modes

### Setup

- Clicking an actor in the viewport selects the corresponding `_actors[idx]`.
- Clicking a row in Character Panel selects the same actor and highlights its
  grid unit.
- Character Panel exposes class, HP, ATK, Q/R, passives, and remove actor.
- Position edits reuse existing placement validation:
  `_nearest_free_coord_for`, `_apply_actor_position_change`, and world mutation.
- Adding/removing actors still goes through existing control paths.

### Timeline Edit

- Timeline drawer remains the canonical visual editor for keyframes.
- Character Panel keeps selected actor context visible while keyframe editing.
- Selecting a keyframe sets:
  `_selected_kind = SELECT_KEYFRAME`,
  `_selected_spt_actor_idx`,
  `_selected_spt_kf_idx`.
- Character Panel shows a `Selected Keyframe` section derived from
  `_actors[actor_idx]["track"][kf_idx]`.
- Time, skill, and target edits call the existing mutation functions:
  `_on_keyframe_time_changed`,
  `_on_keyframe_skill_changed`,
  `_on_keyframe_target_field_changed`.
- Same-skill occupy bump remains automatic.
- Cooldown / target warnings remain derived via `SkillPreviewValidation`.

### Playback

- On Start, editing controls and Character Panel inputs become locked.
- Character Panel switches from setup values to live/readback values:
  HP, status chips, cooldown tags, defeated state, and damage history.
- Replay uses `_last_timeline`; Reset returns to setup state and re-enables edits.
- Status copy should stay explicit:
  `Playback complete - reset before editing`.

## Selection Contract

- One selection model drives all surfaces:
  `SELECT_NONE`, `SELECT_HEX`, `SELECT_ACTOR`, `SELECT_ENVIRONMENT`,
  `SELECT_KEYFRAME`.
- Character Panel is a view over that selection, not a separate selection stack.
- Actor list hover may highlight a unit, but hover must not mutate selection.
- Selection changes call the same refresh path as today:
  `_rebuild_inspector()` / `_refresh_details_popup()` / panel refresh.

## Implementation Notes

- Add right panel as a sibling of current left panel and bottom drawer under
  `ConfigUI/Root`.
- Prefer a small `CharacterPanelVBox` subtree in scene plus dynamic row builders
  in `skill_preview.gd`.
- Reuse `_build_actor_detail_panel` logic where possible, but split pure data
  rows from popup-only layout.
- Do not move timeline editing state into the Character Panel.
- Do not duplicate `_actors` into panel-local arrays.
- Keep runtime playback read-only; mutations require Reset first.

