# First Person Warp Sandbox

Technical proof for a first-person "walk forward on a road" effect using 2D source images plus mathematical floor warping.

Scope:

- Independent Godot sandbox scene only.
- No main game logic, hex grid, battle renderer, or overworld renderer changes.
- Ground and road are sampled from an AI-generated top-down strip texture in `first_person_floor.gdshader`.
- Horizon, billboards, and hand overlay stay as separate AI-generated 2D layers.
- Procedural fallback/source assets are kept next to the `_ai` assets for quick regeneration and comparison.

Run:

```powershell
python inkmon/tools/first_person_warp_sandbox/generate_first_person_assets.py
godot_console --headless --path . --import
godot_console --path . res://inkmon/tools/first_person_warp_sandbox/first_person_warp_sandbox.tscn
```

Smoke:

```powershell
godot_console --headless --path . res://inkmon/tools/first_person_warp_sandbox/first_person_warp_sandbox.tscn -- --smoke
```

Capture frames for a 10 second loop:

```powershell
godot_console --path . res://inkmon/tools/first_person_warp_sandbox/first_person_warp_sandbox.tscn -- --capture-dir=D:\GodotProjects\inkmon\inkmon-godot\inkmon\tools\first_person_warp_sandbox\output\frames --capture-frames=300
ffmpeg -y -framerate 30 -i inkmon/tools/first_person_warp_sandbox/output/frames/frame_%04d.png -c:v libx264 -pix_fmt yuv420p -movflags +faststart inkmon/tools/first_person_warp_sandbox/output/first_person_warp_loop_10s.mp4
```

Loop boundary check:

```powershell
godot_console --path . res://inkmon/tools/first_person_warp_sandbox/first_person_warp_sandbox.tscn -- --capture-dir=D:\GodotProjects\inkmon\inkmon-godot\inkmon\tools\first_person_warp_sandbox\output\loop_check --capture-frames=1 --capture-start-frame=300
```
