---
description: Update LGF skill docs based on recent addon changes
---

# Update Logic Game Framework Skill Documentation

## Baseline

The last synced commit is recorded in `.opencode/skill/lgf/update.json`:

!`cat .opencode/skill/lgf/update.json`

## Recent Changes

Commits since last sync that touched the LGF addon:

!`node -e "const fs=require('fs');const j=JSON.parse(fs.readFileSync('.opencode/skill/lgf/update.json','utf8'));const h=j.last_commit;const {execSync}=require('child_process');process.stdout.write(execSync('git log --oneline '+h+'..HEAD -- addons/logic-game-framework/').toString())"`

Diff of all changes since last sync:

!`node -e "const fs=require('fs');const j=JSON.parse(fs.readFileSync('.opencode/skill/lgf/update.json','utf8'));const h=j.last_commit;const {execSync}=require('child_process');process.stdout.write(execSync('git diff '+h+'..HEAD -- addons/logic-game-framework/').toString())"`

## Current Skill Files

!`find .opencode/skill/lgf/ -type f -name "*.md" -o -name "*.json"`

## Instructions

You are updating the LGF skill documentation to reflect recent changes in the `addons/logic-game-framework/` addon source code.

### Step 1: Analyze Changes

Look at the commits and diff above. Identify:
- New classes, methods, or properties added
- Changed APIs (signatures, behavior)
- Removed or deprecated features
- New patterns or conventions introduced

If there are **no commits** or **no diff** since the last sync, report "No changes detected" and stop.

### Step 2: Map Changes to Skill Docs

For each change, determine which skill doc(s) it affects:
- `SKILL.md` — Main conventions and quick reference
- `reference/conventions-detail.md` — Detailed examples and architecture
- `reference/entity.md` — Actor, System, GameWorld, GameplayInstance
- `reference/abilities.md` — Ability, AbilitySet, AbilityConfig, Components, Builder API
- `reference/actions.md` — Action, ExecutionContext, TargetSelector, Resolvers
- `reference/events.md` — EventProcessor, MutableEvent, Intent, Modification
- `reference/attributes.md` — RawAttributeSet, AttributeModifier, Calculator, TagContainer
- `reference/stdlib.md` — StatModifier, TimeDuration, Stack, Projectile, Replay, Timeline
- `reference/example-app-*.md` — Example application docs

### Step 3: Update Skill Docs

For each affected doc:
1. Read the current content
2. Apply the necessary updates (add new content, modify existing, remove outdated)
3. Maintain the existing writing style and format
4. Keep Chinese for explanatory text, English for code and technical terms

**Rules:**
- Do NOT rewrite entire files — make targeted edits only
- Do NOT remove content unless the underlying feature was removed
- Do NOT change the overall structure of SKILL.md unless necessary
- If a new major feature was added that doesn't fit existing docs, create a new reference file

### Step 4: Update Tracking

After all skill docs are updated, update `.opencode/skill/lgf/update.json`:
- Set `last_commit` to the current HEAD commit hash (run `git rev-parse HEAD`)
- Set `last_update` to today's date (YYYY-MM-DD format)
- Set `note` to a brief summary of what was updated

### Output

When done, provide a summary:
1. What changes were detected in the addon
2. Which skill docs were updated and why
3. The new commit hash recorded in update.json
