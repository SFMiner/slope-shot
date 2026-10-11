# === HEADER COMMENT ===
# grid_view.gd
# Custom-drawn coordinate grid, slope preview line, flags, and rocket.
# Part of Slope Shot educational game.
# Teaches: slope as rise/run. The dashed preview line IS the third
# representation of slope (alongside the fraction and the plain words) —
# it must update live with every stepper press so students see the
# steepness change as the numbers change.

class_name GridView
extends Control

# === CONSTANTS ===
const GRID_MAX: int = 10
const MARGIN_LEFT: float = 64.0
const MARGIN_RIGHT: float = 24.0
const MARGIN_TOP: float = 16.0
const MARGIN_BOTTOM: float = 52.0
const STAR_COUNT: int = 70

const COLOR_GRID: Color = Color(0.18, 0.55, 0.75, 0.30)
const COLOR_AXIS: Color = Color(0.35, 0.95, 1.0, 0.95)
const COLOR_PREVIEW: Color = Color(1.0, 0.35, 0.85, 0.95)
const COLOR_PATH: Color = Color(1.0, 0.85, 0.2, 1.0)
const COLOR_FLAG: Color = Color(0.3, 1.0, 0.5)
const COLOR_FLAG_DONE: Color = Color(0.45, 0.45, 0.5)
const COLOR_TARGET_RING: Color = Color(1.0, 1.0, 0.4, 0.9)
const COLOR_TEXT: Color = Color(0.55, 0.9, 1.0)
const COLOR_STAR: Color = Color(0.8, 0.85, 1.0, 0.5)

# === PUBLIC VARIABLES (set by main.gd; call queue_redraw after changes) ===
var flags: Array[Vector2i] = []
var flags_done: Array[bool] = []
var target_idx: int = 0
var rise_value: int = 1
var run_value: int = 1
var show_preview: bool = true
var rocket_grid: Vector2 = Vector2.ZERO
var rocket_dir: Vector2 = Vector2.ONE.normalized()
var is_flying: bool = false
var traced: PackedVector2Array = PackedVector2Array()
var shake_offset: Vector2 = Vector2.ZERO

# === PRIVATE VARIABLES ===
var _origin_px: Vector2 = Vector2.ZERO
var _cell: float = 32.0
var _star_points: PackedVector2Array = PackedVector2Array()

# === LIFECYCLE METHODS ===
func _ready() -> void:
	# Deterministic star field so the background doesn't flicker per redraw.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20260609
	for i in range(STAR_COUNT):
		_star_points.append(Vector2(rng.randf(), rng.randf()))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

# === PUBLIC METHODS ===
func grid_to_px(grid_pos: Vector2) -> Vector2:
	# Math grids point Y up; pixels point Y down — flip here, nowhere else.
	return _origin_px + Vector2(grid_pos.x * _cell, -grid_pos.y * _cell) + shake_offset

# === PRIVATE METHODS ===
func _layout() -> void:
	var usable_w: float = size.x - MARGIN_LEFT - MARGIN_RIGHT
	var usable_h: float = size.y - MARGIN_TOP - MARGIN_BOTTOM
	_cell = minf(usable_w / float(GRID_MAX), usable_h / float(GRID_MAX))
	var grid_side: float = _cell * float(GRID_MAX)
	_origin_px = Vector2(
		MARGIN_LEFT + (usable_w - grid_side) * 0.5,
		size.y - MARGIN_BOTTOM - (usable_h - grid_side) * 0.5
	)

func _draw() -> void:
	_layout()
	_draw_stars()
	_draw_grid()
	if show_preview:
		_draw_preview_line()
	_draw_traced_path()
	_draw_flags()
	_draw_rocket()

func _draw_stars() -> void:
	for star in _star_points:
		var pos: Vector2 = Vector2(star.x * size.x, star.y * size.y)
		draw_circle(pos, 1.5, COLOR_STAR)

func _draw_grid() -> void:
	var font: Font = get_theme_default_font()
	for i in range(GRID_MAX + 1):
		var col: Color = COLOR_AXIS if i == 0 else COLOR_GRID
		var width: float = 3.0 if i == 0 else 1.0
		draw_line(grid_to_px(Vector2(i, 0)), grid_to_px(Vector2(i, GRID_MAX)), col, width)
		draw_line(grid_to_px(Vector2(0, i)), grid_to_px(Vector2(GRID_MAX, i)), col, width)
		# Axis numbers must be readable from across a classroom.
		var x_label_pos: Vector2 = grid_to_px(Vector2(i, 0)) + Vector2(-6.0, 30.0)
		draw_string(font, x_label_pos, str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, COLOR_TEXT)
		if i > 0:
			var y_label_pos: Vector2 = grid_to_px(Vector2(0, i)) + Vector2(-38.0, 7.0)
			draw_string(font, y_label_pos, str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, COLOR_TEXT)

func _draw_preview_line() -> void:
	# The line y = (rise/run) * x, extended to whichever grid edge it
	# reaches first. This is the live picture of the current slope.
	var t: float = minf(
		float(GRID_MAX) / float(run_value),
		float(GRID_MAX) / float(rise_value)
	)
	var end_grid: Vector2 = Vector2(float(run_value), float(rise_value)) * t
	draw_dashed_line(grid_to_px(Vector2.ZERO), grid_to_px(end_grid), COLOR_PREVIEW, 4.0, 14.0)

func _draw_traced_path() -> void:
	if traced.size() == 0:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	for p in traced:
		pts.append(grid_to_px(p))
	pts.append(grid_to_px(rocket_grid))
	if pts.size() >= 2:
		draw_polyline(pts, COLOR_PATH, 5.0)

func _draw_flags() -> void:
	for i in range(flags.size()):
		var base: Vector2 = grid_to_px(Vector2(flags[i]))
		var done: bool = flags_done[i] if i < flags_done.size() else false
		var col: Color = COLOR_FLAG_DONE if done else COLOR_FLAG
		# On the two-flag level a ring marks the current target, so the
		# "steeper one first" rule is visible, not just verbal.
		if flags.size() > 1 and i == target_idx and not done:
			draw_arc(base, _cell * 0.45, 0.0, TAU, 32, COLOR_TARGET_RING, 3.0)
		draw_circle(base, _cell * 0.16, col)
		var pole_top: Vector2 = base + Vector2(0.0, -_cell * 0.9)
		draw_line(base, pole_top, col, 3.0)
		var flag_tri: PackedVector2Array = PackedVector2Array([
			pole_top,
			pole_top + Vector2(_cell * 0.55, _cell * 0.18),
			pole_top + Vector2(0.0, _cell * 0.36),
		])
		draw_colored_polygon(flag_tri, col)
		if done:
			# A tick on cleared flags, so "done" is not shown by grey alone.
			var tick: PackedVector2Array = PackedVector2Array([
				base + Vector2(-_cell * 0.3, _cell * 0.05),
				base + Vector2(-_cell * 0.12, _cell * 0.25),
				base + Vector2(_cell * 0.3, -_cell * 0.2),
			])
			draw_polyline(tick, COLOR_TARGET_RING, 4.0)

func _draw_rocket() -> void:
	var center: Vector2 = grid_to_px(rocket_grid)
	var dir_px: Vector2 = Vector2(rocket_dir.x, -rocket_dir.y)
	var angle: float = dir_px.angle()
	var s: float = clampf(_cell * 0.5, 12.0, 26.0)
	var body: PackedVector2Array = PackedVector2Array([
		Vector2(s, 0.0),
		Vector2(-s * 0.7, s * 0.55),
		Vector2(-s * 0.4, 0.0),
		Vector2(-s * 0.7, -s * 0.55),
	])
	var body_px: PackedVector2Array = PackedVector2Array()
	for p in body:
		body_px.append(center + p.rotated(angle))
	draw_colored_polygon(body_px, Color(0.95, 0.97, 1.0))
	draw_circle(center + Vector2(s * 0.25, 0.0).rotated(angle), s * 0.18, Color(0.2, 0.8, 1.0))
	if is_flying:
		# Flicker is fine here: flight redraws every frame anyway.
		var flick: float = randf_range(0.7, 1.3)
		var flame: PackedVector2Array = PackedVector2Array([
			Vector2(-s * 0.55, s * 0.25),
			Vector2(-s * 1.1 * flick, 0.0),
			Vector2(-s * 0.55, -s * 0.25),
		])
		var flame_px: PackedVector2Array = PackedVector2Array()
		for p in flame:
			flame_px.append(center + p.rotated(angle))
		draw_colored_polygon(flame_px, Color(1.0, 0.55, 0.1))
