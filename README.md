# Slope Shot

Rocket-aiming slope game (rise/run) for 8th-grade special-ed math. Godot 4.5,
GDScript, all-button input, 8 levels, local top-5 high scores.

## Open the project

1. Open Godot 4.5 → **Import** → select this folder's `project.godot` → **Import & Edit**.
2. Press **F5** (or the Play button) to run it in the editor. That alone is
   enough for projector/teacher-machine use.

On first import Godot will regenerate the placeholder UIDs — that's normal.
Just let it save.

## Export the web build

1. **Editor → Manage Export Templates → Download and Install** (one-time, per
   Godot version).
2. **Project → Export** → the **Web** preset is already configured →
   **Export Project** → keep the path `export/web/index.html`.

## Run the web build

A Godot web export will NOT run by double-clicking `index.html` (browsers
block it on `file://`). Serve it over HTTP:

```
cd export/web
python -m http.server 8000
```

Then open `http://localhost:8000` in a browser. On the school network, run
that on your machine and have Chromebooks browse to `http://YOUR_IP:8000`,
or drop the `export/web` folder onto any static host (itch.io, GitHub Pages,
school web space).

Thread support is deliberately disabled in the export preset, so the build
runs without special COOP/COEP server headers — any dumb static host works.

## Notes

- **Audio**: all SFX are generated as PCM in code (`scripts/sfx.gd`). There
  are no audio asset files, so the web .ogg import constraint never applies.
- **High scores**: stored in browser localStorage on web (per-machine,
  per-browser — each Chromebook keeps its own list), or
  `user://slope_shot_highscores.json` on desktop.
- **Hit test**: exact integer comparison `rise * flag.x == run * flag.y`.
  Unreduced fractions (4/2 for slope 2) count as correct.
- **Level 8**: two flags, steeper first. Hitting the shallow one early gives
  its own message ("THE STEEP ONE FIRST!") instead of the generic
  steep/shallow feedback.
