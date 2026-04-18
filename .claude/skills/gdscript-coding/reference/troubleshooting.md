# GDScript Troubleshooting

## Can't load the script as it doesn't inherit from SceneTree or MainLoop

```
ERROR: Can't load the script "xxx.gd" as it doesn't inherit from SceneTree or MainLoop.
   at: start (main/main.cpp:4251)
```

**Cause**: `godot --script` on a script that `extends Node`.

**Fix**: Run via scene instead:

```bash
# BAD
godot --headless --script tests/test_framework.gd

# GOOD
godot --headless tests/run_tests.tscn
```

Or change the script to `extends SceneTree` if it doesn't need the scene tree.

## Autoload loading rules

| Run method | Autoload loaded? |
|------------|-----------------|
| `godot --script main.gd` | NO |
| `godot main.tscn` | YES |
| `godot --headless main.tscn` | YES |

**Rule**: If your script depends on Autoload, run it via `.tscn`, not `--script`.
