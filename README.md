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

Preset **Web** uses the lean 2D custom template (`godot-2d-web-template`),
single-threaded, and writes to `../exports/slope-shot/index.html`:

```
Godot --headless --path . --export-release "Web" ../exports/slope-shot/index.html
```

Before exporting run `python ../../godot-2d-web-template/check_web_template.py .`.
Serve the export over HTTP (browsers block `file://`), e.g.
`python -m http.server 8000` inside the export folder.

## Tests

`GODOT=<godot 4.5 binary> bash tests/run_all_tests.sh` runs `test_keyboard.gd`
(Tab order, keyboard exit, shortcuts, mute) and `test_smoke.gd` (loads the
game, runs a flight, checks the hit test and level 8).

## Features

- [x] 8 authored levels, then endless random levels
- [x] Slope shown three ways: fraction, words, preview line (first 4 levels)
- [x] Button input only (no typing)
- [x] Keyboard: Up/Down rise, Left/Right run, Enter launch, Tab order, M sound, Esc leave
- [x] On-screen key hint
- [x] Sound waits for first click/key; SOUND on/off button
- [x] Visible focus outline on every control
- [x] Sims-site keyboard exit (Tab past the ends and Esc post `sims:leave-game`)
- [x] Cleared flags show a tick, not only a colour change
- [x] Web export (lean 2D template) and headless tests
- [ ] Screen reader support (canvas-drawn grid; not available)

## Notes

- **Audio**: all SFX are generated as PCM in code (`scripts/sfx.gd`). There
  are no audio asset files, so the web .ogg import constraint never applies.
- **High scores**: unused (no finale since play is endless). `save_system.gd`
  uses browser localStorage on web or `user://slope_shot_highscores.json`
  on desktop; no absolute paths.
- `countdown.mp3` and `rocket_engine.mp3` are not used by the game and are
  left out of the export.
- **Hit test**: exact integer comparison `rise * flag.x == run * flag.y`.
  Unreduced fractions (4/2 for slope 2) count as correct.
- **Level 8**: two flags, steeper first. Hitting the shallow one early gives
  its own message ("THE STEEP ONE FIRST!") instead of the generic
  steep/shallow feedback.
