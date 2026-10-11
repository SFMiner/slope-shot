# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Slope Shot — a single-screen educational Godot 4.5 game for 8th-grade special-ed
math. Students set `rise` and `run` with +/- steppers so a rocket's staircase
line lands on a flag, teaching slope as rise/run shown three ways at once: the
fraction, plain words ("up 2 for every 1 across"), and the live preview line.
Design constraints that drive the code: **all input is buttons** (no typing —
students who can't write never type a math answer), and **misses are cheap and
private** (instant reset, quiet short buzz, no lockout; hits get a louder/longer
reward by deliberate asymmetry).

## Running and exporting

- **Run in editor**: open `project.godot` in Godot 4.5, press **F5**. The main
  scene is `main.tscn` (a bare `Control` with `main.gd` attached). This is the
  normal teacher/projector path.
- **Web export**: preset **Web** is preconfigured (lean 2D custom template,
  absolute path) and exports to `../exports/slope-shot/index.html`; run
  `check_web_template.py` first. Serve over HTTP, not `file://`.
- **Thread support is deliberately OFF** in the export preset so the build runs
  on any dumb static host without COOP/COEP headers. Do not enable it.
- Tests: `GODOT=<4.5 binary> bash tests/run_all_tests.sh` (keyboard + smoke).
- **Keyboard**: Tab order lives in `_setup_keyboard()` in `main.gd` (passed to
  `scripts/keyboard_nav.gd`, which does Tab/Esc/leave and the arrow/Enter/M
  shortcuts, and skips disabled/hidden controls). Sound stays silent until
  `Sfx.unlock()` (first key/click) and respects `Sfx.muted`.
- `countdown.mp3` / `rocket_engine.mp3` are unused leftovers (excluded from export).

## Architecture

Everything is built **in code** — `main.tscn` contains no UI nodes; `main.gd`
constructs the entire UI tree in `_ready()` via the `_build_*` helpers. There is
no scene-file UI to edit; change layout in `main.gd`.

Four scripts, all `class_name` globals (no AutoLoads):

- **`scripts/main.gd`** (`SlopeShotMain`) — the whole game. Owns the FSM
  (`State.{INTRO, AIM, FLY, NAME_ENTRY, BOARD}`), level data (`LEVELS`), input
  handlers, flight simulation, and UI construction. Instantiates `Sfx` and
  `SaveSystem` as children in `_ready()`.
- **`scripts/grid_view.gd`** (`GridView`) — custom `_draw()` of the coordinate
  grid, dashed slope preview line, flags, traced path, and rocket. `main.gd`
  pushes state into its public vars and calls `queue_redraw()`. The preview line
  is the third representation of slope and must update live on every stepper
  press. `grid_to_px()` is the **only** place math-Y-up flips to pixel-Y-down.
- **`scripts/sfx.gd`** (`Sfx`) — retro SFX generated as PCM `AudioStreamWAV` at
  startup (click/whoosh/ding/buzz). No audio asset files, so the web `.ogg`
  import constraint never applies. Call `sfx.play_sound("name")`.
- **`scripts/save_system.gd`** (`SaveSystem`) — top-5 high scores, lower shots =
  better. Browser `localStorage` on web (per-machine, per-browser),
  `user://slope_shot_highscores.json` on desktop. `_js_storage` is intentionally
  untyped because `JavaScriptObject` only exists in web builds.

### Core mechanic invariants

- **Hit test is exact integer math**: a line hits flag `(fx, fy)` iff
  `rise * fx == run * fy` (`_compute_outcome`). No float equality, no rounding.
  Unreduced equivalents (4/2 for slope 2) are accepted on purpose. The same
  comparison decides steep-vs-shallow feedback on a miss.
- **The flight is a literal staircase**: step RIGHT by `run`, then UP by `rise`,
  repeated (`_build_staircase`). It's the picture of rise/run, not a straight
  ray. Flight ends when the rocket covers the flag or overshoots the grid.
- **Level 8 is the only multi-flag level** (`"ordered": true`): two flags,
  steeper must be hit first. Hitting the shallow flag early gives a distinct
  message ("THE STEEP ONE FIRST!", `_resolve_wrong_flag`) instead of the generic
  steep/shallow feedback. A target ring in `GridView` shows which flag is live.
- **Steppers are clamped 1–8**; the grid is 0–10 (`STEPPER_MIN/MAX`, `GRID_MAX`).
- **Play is endless past level 8.** After the authored `LEVELS`, `_load_level`
  pulls from `_level_data`, which generates random single-flag levels via
  `_make_random_level` (slope = independent `randi_range(1,6)` rise/run; flag at
  `(run, rise)` so the exact pair always solves within the 1–8 steppers). There
  is **no high-score finale** — the name-entry/board flow (`_show_name_entry`,
  `_build_name_overlay`, `_build_board_overlay`, and `SaveSystem`) is now dead,
  unreachable code left in place.

### Adding/changing levels

Edit the `LEVELS` array in `main.gd`. Each entry is `{"flags": [Vector2i(run,
rise), ...]}`; add `"ordered": true` for steepest-first multi-flag levels. Note
flag vectors are `(x, y)` = `(run, rise)`. The `"LEVEL n/8"` label is hardcoded
`8` for authored levels; past that it shows a plain `"LEVEL n"`. If you change
the authored level count, update that `8` (and the intro/dead name-entry "8/8"
copy).

## Conventions

GDScript with full static type hints throughout; tabs for indentation; section
banner comments (`# === ... ===`). Comments explain *why* (the pedagogical
constraint), not *what*. Match that when editing. UIDs in `main.tscn` are
placeholders Godot regenerates on first import — that's expected.
