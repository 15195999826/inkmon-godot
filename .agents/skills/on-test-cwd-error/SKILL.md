---
name: on-test-cwd-error
description: Invoke when your last `godot ...` command failed, hung, or produced empty/garbled output. Diagnoses cwd / shell-tool / `--path` / launcher / pipe-buffering issues and issues ONE corrected command. No background re-explanation, no extended apology.
---

# On test cwd / shell / path error — fast recovery

The user just told you the previous `godot` invocation was wrong. Don't retry the same command, don't bump the timeout, don't add `2>&1` — none of that fixes cwd. Diagnose, then issue ONE corrected command.

## Step 1 — Stop. Acknowledge briefly.

One short sentence: "对，我刚才 X 错了" (where X is the actual mistake — Bash tool / `--path .` / 没用 launcher / 没 redirect)。Don't write a paragraph. Don't relitigate the background — the user already knows it, that's why they corrected you.

## Step 2 — Diagnose (pick exactly one row)

| Symptom in your last command | Root cause | Fix |
|---|---|---|
| Used **Bash tool** to invoke `godot` | git-bash cwd drifted into a submodule from earlier `cd` | Re-issue from **PowerShell tool** |
| `--path .` (relative) | cwd at process spawn isn't repo root | Replace with `--path D:/GodotProjects/inkmon/inkmon-godot` (absolute) |
| Hand-typed `godot ... <scene>.tscn` for a scene that IS in a manifest | Bypassed launcher → no parallelism, no timeout, no log capture | Find group via `./tools/run_tests.ps1 -List`, run `./tools/run_tests.ps1 <group>` |
| `for s in scenes; do godot ...; done` (batched smoke) | Same as above, plus single-Bash-call output silence | Same — use launcher with multiple groups |
| `\| grep` / `\| Select-String` | Windows pipe buffering + Godot ObjectDB cleanup → 2-3 min "hang" | Redirect to file, then **Read** or **Grep** tool on the file |
| `--script foo.gd` (no .tscn) | `--script` mode skips autoloads → `Log` / `GameWorld` undefined | Wrap in a `.tscn` and run that |

If multiple apply (e.g. Bash tool **and** `--path .`), fix all in the corrected command.

## Step 3 — Issue the corrected command

### Case A — Scene IS in a `test_groups.json` manifest

```powershell
./tools/run_tests.ps1 <group>
```

Quick lookup if you don't know the group:

```powershell
./tools/run_tests.ps1 -List
```

Manifests live at `addons/logic-game-framework/{tests,example/*/tests}/test_groups.json` and `addons/sim-nav-map/{tests,examples/*/tests}/test_groups.json`.

### Case B — Ad-hoc scene (not in any manifest)

PowerShell tool, absolute `--path`, redirect to file:

```powershell
godot --headless --path D:/GodotProjects/inkmon/inkmon-godot path/to/scene.tscn `
  > $env:TEMP\godot_out.txt 2>&1
```

Then `Read` `$env:TEMP\godot_out.txt` (or `Grep` on it).

## Anti-patterns when recovering

- ❌ Re-explaining why cwd matters / why Bash drifts / why pipe buffering hangs — user already knows
- ❌ Listing 3-5 alternatives and asking the user to pick — pick one and run it
- ❌ Apologizing for 2+ sentences before the corrected command
- ❌ Adding new flags (`--verbose`, longer timeout) hoping it fixes the underlying cwd error
- ❌ Quietly retrying the same command in PowerShell that you just ran in Bash without changing `--path`
