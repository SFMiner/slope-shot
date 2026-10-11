# === HEADER COMMENT ===
# main.gd
# Slope Shot — set rise and run so the rocket's line lands on the flag.
# Part of Slope Shot educational game (8th-grade special-ed math).
# Teaches: slope as rise/run, shown three ways at once — the fraction,
# plain words ("up 2 for every 1 across"), and the picture of the line.
# All input is buttons; students who cannot write never type a math answer.
# Misses are cheap and private: instant reset, quiet buzz, no lockout.

class_name SlopeShotMain
extends Control

# === ENUMS ===
enum State { INTRO, AIM, FLY, NAME_ENTRY, BOARD }

# === CONSTANTS ===
const GRID_MAX: int = 10
const STEPPER_MIN: int = 1
const STEPPER_MAX: int = 8
# The dashed preview line is the slope's third representation, but it's also a
# crutch: a student can ignore the numbers and button-mash until it lines up.
# Show it only on the first four levels (and the intro demo), then take it away
# so the later levels force reading the fraction/words.
const PREVIEW_LEVELS: int = 4
const FLIGHT_SPEED: float = 6.0  # grid units per second along the staircase
const HIT_PAUSE: float = 1.5
const TOP_BAR_HEIGHT: float = 56.0
const BOTTOM_BAR_HEIGHT: float = 150.0
const ALPHABET: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

const COLOR_NEON: Color = Color(0.35, 0.95, 1.0)
const COLOR_GOOD: Color = Color(0.4, 1.0, 0.6)
const COLOR_BAD: Color = Color(1.0, 0.5, 0.4)
const COLOR_WARN: Color = Color(1.0, 1.0, 0.5)
const COLOR_BG: Color = Color(0.04, 0.05, 0.10)

# Level data. "ordered" = multiple flags, steepest target must be hit first.
# Hit test is exact rational comparison (rise * flag.x == run * flag.y),
# so any unreduced equivalent like 4/2 for slope 2 is accepted.
const LEVELS: Array[Dictionary] = [
	{"flags": [Vector2i(3, 3)]},
	{"flags": [Vector2i(2, 4)]},
	{"flags": [Vector2i(1, 3)]},
	{"flags": [Vector2i(4, 8)]},
	{"flags": [Vector2i(4, 2)]},
	{"flags": [Vector2i(6, 2)]},
	{"flags": [Vector2i(6, 4)]},
	{"flags": [Vector2i(1, 3), Vector2i(3, 1)], "ordered": true},
]

# === PUBLIC VARIABLES ===
var current_state: State = State.INTRO
var level_idx: int = 0
var rise_value: int = 1
var run_value: int = 1
var shots: int = 0
var flags: Array[Vector2i] = []
var flags_done: Array[bool] = []
var target_idx: int = 0

# === PRIVATE VARIABLES (flight state) ===
var _corners: Array[Vector2] = []
var _seg_idx: int = 0
var _seg_t: float = 0.0
var _outcome: Dictionary = {}
var _shake: float = 0.0
var _banner_tween: Tween = null
var _letters: Array[int] = [0, 0, 0]
var _confetti: Array[CPUParticles2D] = []
var _stepper_buttons: Array[Button] = []

# === NODE REFERENCES (built in code in _ready) ===
var grid_view: GridView = null
var sfx: Sfx = null
var save_system: SaveSystem = null
var shots_label: Label = null
var level_label: Label = null
var banner_label: Label = null
var rise_value_label: Label = null
var run_value_label: Label = null
var slope_fraction_label: Label = null
var slope_words_label: Label = null
var launch_button: Button = null
var skip_button: Button = null
var name_overlay: Control = null
var board_overlay: Control = null
var board_list_label: Label = null
var letter_labels: Array[Label] = []

# === LIFECYCLE METHODS ===
func _ready() -> void:
	sfx = Sfx.new()
	add_child(sfx)
	save_system = SaveSystem.new()
	add_child(save_system)
	_build_background()
	_build_grid_view()
	_build_top_bar()
	_build_bottom_bar()
	_build_banner()
	_build_confetti()
	_build_name_overlay()
	_build_board_overlay()
	_refresh_slope()
	_run_intro()

func _process(delta: float) -> void:
	if grid_view.is_flying:
		_advance_flight(delta)
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, delta * 40.0)
		grid_view.shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		grid_view.queue_redraw()
	elif grid_view.shake_offset != Vector2.ZERO:
		grid_view.shake_offset = Vector2.ZERO
		grid_view.queue_redraw()

# === CORE MECHANIC: hit test and flight ===
func _compute_outcome() -> Dictionary:
	# Exact rational test: the line y = (rise/run)x passes through flag
	# (fx, fy) iff rise * fx == run * fy. Integer math only — no float
	# equality, no rounding bugs, and unreduced fractions still count.
	for i in range(flags.size()):
		if flags_done[i]:
			continue
		var f: Vector2i = flags[i]
		if rise_value * f.x == run_value * f.y:
			if i == target_idx:
				return {"type": "hit", "flag": f, "idx": i}
			return {"type": "wrong", "flag": f, "idx": i}
	return {"type": "miss"}

func _build_staircase() -> Array[Vector2]:
	# Step RIGHT by run, then UP by rise — the literal picture of rise/run.
	# Overshoots one cycle past the grid edge; the miss check stops flight.
	var pts: Array[Vector2] = [Vector2.ZERO]
	var p: Vector2 = Vector2.ZERO
	while p.x <= float(GRID_MAX) + 0.5 and p.y <= float(GRID_MAX) + 0.5:
		p.x += float(run_value)
		pts.append(p)
		p.y += float(rise_value)
		pts.append(p)
	return pts

func _launch(is_demo: bool = false) -> void:
	if grid_view.is_flying:
		return
	if not is_demo:
		shots += 1
		_update_shots_label()
		current_state = State.FLY
	_outcome = _compute_outcome()
	_corners = _build_staircase()
	_seg_idx = 0
	_seg_t = 0.0
	grid_view.traced = PackedVector2Array([Vector2.ZERO])
	grid_view.rocket_grid = Vector2.ZERO
	grid_view.is_flying = true
	grid_view.show_preview = false
	launch_button.disabled = true
	_set_steppers_enabled(false)
	sfx.play_sound("whoosh")

func _advance_flight(delta: float) -> void:
	var travel: float = FLIGHT_SPEED * delta
	while travel > 0.0 and _seg_idx < _corners.size() - 1:
		var a: Vector2 = _corners[_seg_idx]
		var b: Vector2 = _corners[_seg_idx + 1]
		var seg_len: float = a.distance_to(b)
		var remain: float = seg_len * (1.0 - _seg_t)
		if travel < remain:
			_seg_t += travel / seg_len
			travel = 0.0
		else:
			travel -= remain
			_seg_idx += 1
			_seg_t = 0.0
	var seg_a: Vector2 = _corners[_seg_idx]
	var seg_b: Vector2 = _corners[mini(_seg_idx + 1, _corners.size() - 1)]
	grid_view.rocket_grid = seg_a.lerp(seg_b, _seg_t)
	if seg_b != seg_a:
		grid_view.rocket_dir = (seg_b - seg_a).normalized()
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(_seg_idx + 1):
		pts.append(_corners[i])
	grid_view.traced = pts
	grid_view.queue_redraw()
	_check_flight_result()

func _check_flight_result() -> void:
	var pos: Vector2 = grid_view.rocket_grid
	if _outcome["type"] != "miss":
		var f: Vector2i = _outcome["flag"]
		# The staircase has fully covered the flag once both the
		# horizontal and vertical legs have passed its coordinates.
		if pos.x >= float(f.x) - 0.001 and pos.y >= float(f.y) - 0.001:
			if _outcome["type"] == "hit":
				_resolve_hit(int(_outcome["idx"]))
			else:
				_resolve_wrong_flag()
			return
	if pos.x > float(GRID_MAX) + 0.3 or pos.y > float(GRID_MAX) + 0.3:
		_resolve_miss()

func _resolve_hit(idx: int) -> void:
	grid_view.is_flying = false
	flags_done[idx] = true
	grid_view.flags_done = flags_done
	grid_view.rocket_grid = Vector2(flags[idx])
	grid_view.queue_redraw()
	sfx.play_sound("ding")
	_burst_confetti(Vector2(flags[idx]))
	_shake = 14.0
	_show_banner("NAILED IT!", COLOR_GOOD)
	if current_state == State.INTRO:
		return
	await _sleep(HIT_PAUSE)
	if _all_flags_done():
		# After the 8 authored levels the game never ends — it keeps loading
		# freshly generated random levels. No high-score finale by design.
		_load_level(level_idx + 1)
	else:
		# Two-flag level: steeper flag down, shallow one is next.
		target_idx += 1
		grid_view.target_idx = target_idx
		_show_banner("NOW THE OTHER ONE!", COLOR_WARN)
		_reset_for_attempt()

func _resolve_miss() -> void:
	grid_view.is_flying = false
	sfx.play_sound("buzz")
	# Steep vs shallow uses the same exact integer comparison as the hit
	# test, judged against the current target flag.
	var f: Vector2i = flags[target_idx]
	if rise_value * f.x > run_value * f.y:
		_show_banner("TOO STEEP — TRY AGAIN", COLOR_BAD)
	else:
		_show_banner("TOO SHALLOW — TRY AGAIN", COLOR_BAD)
	_reset_for_attempt()

func _resolve_wrong_flag() -> void:
	# Level 8 only: the line hit the shallow flag while the steep one
	# was still the target. Generic steep/shallow feedback would be
	# wrong here, so this gets its own message.
	grid_view.is_flying = false
	sfx.play_sound("buzz")
	_show_banner("THE STEEP ONE FIRST!", COLOR_WARN)
	_reset_for_attempt()

func _reset_for_attempt() -> void:
	grid_view.is_flying = false
	grid_view.traced = PackedVector2Array()
	grid_view.rocket_grid = Vector2.ZERO
	grid_view.show_preview = _preview_allowed()
	grid_view.rocket_dir = Vector2(float(run_value), float(rise_value)).normalized()
	grid_view.queue_redraw()
	launch_button.disabled = false
	_set_steppers_enabled(true)
	if current_state != State.INTRO:
		current_state = State.AIM

func _preview_allowed() -> bool:
	# Intro always demos the line; gameplay only on the first PREVIEW_LEVELS.
	return current_state == State.INTRO or level_idx < PREVIEW_LEVELS

func _all_flags_done() -> bool:
	for done in flags_done:
		if not done:
			return false
	return true

# === LEVEL FLOW ===
func _level_data(idx: int) -> Dictionary:
	# The first LEVELS.size() levels are authored; everything past that is
	# generated on demand so play continues indefinitely.
	if idx < LEVELS.size():
		return LEVELS[idx]
	return _make_random_level()

func _make_random_level() -> Dictionary:
	# Slope = rise/run, each an independent 1..6 roll. The flag sits at
	# (run, rise) so the exact pair always solves it within the 1..8 steppers,
	# and the hit test accepts any equivalent fraction the student lands on.
	var rise: int = randi_range(1, 6)
	var run: int = randi_range(1, 6)
	return {"flags": [Vector2i(run, rise)]}

func _load_level(idx: int) -> void:
	level_idx = idx
	var data: Dictionary = _level_data(idx)
	flags.assign(data["flags"])
	flags_done.clear()
	for i in range(flags.size()):
		flags_done.append(false)
	target_idx = 0
	grid_view.flags = flags
	grid_view.flags_done = flags_done
	grid_view.target_idx = 0
	if idx < LEVELS.size():
		level_label.text = "LEVEL %d/8" % (idx + 1)
	else:
		level_label.text = "LEVEL %d" % (idx + 1)
	if bool(data.get("ordered", false)):
		_show_banner("HIT THE STEEPER ONE FIRST!", COLOR_WARN)
	current_state = State.AIM
	_reset_for_attempt()

func _start_game() -> void:
	skip_button.visible = false
	shots = 0
	_update_shots_label()
	current_state = State.AIM
	_load_level(0)

# === INTRO (wordless ~8s how-to: rise changes, line steepens, launch, hit) ===
func _run_intro() -> void:
	current_state = State.INTRO
	skip_button.visible = true
	flags.assign([Vector2i(2, 4)])
	flags_done.assign([false])
	target_idx = 0
	grid_view.flags = flags
	grid_view.flags_done = flags_done
	grid_view.target_idx = 0
	level_label.text = "WATCH!"
	rise_value = 1
	run_value = 1
	_refresh_slope()
	_reset_for_attempt()
	await _sleep(1.6)
	if current_state != State.INTRO:
		return
	rise_value = 2
	sfx.play_sound("click")
	_refresh_slope()
	grid_view.rocket_dir = Vector2(float(run_value), float(rise_value)).normalized()
	grid_view.queue_redraw()
	await _sleep(1.6)
	if current_state != State.INTRO:
		return
	_launch(true)
	while grid_view.is_flying and current_state == State.INTRO:
		await get_tree().process_frame
	if current_state != State.INTRO:
		return
	await _sleep(2.2)
	if current_state != State.INTRO:
		return
	_start_game()

# === INPUT HANDLERS ===
func _change_rise(amount: int) -> void:
	if current_state != State.AIM:
		return
	rise_value = clampi(rise_value + amount, STEPPER_MIN, STEPPER_MAX)
	sfx.play_sound("click")
	_refresh_slope()

func _change_run(amount: int) -> void:
	if current_state != State.AIM:
		return
	run_value = clampi(run_value + amount, STEPPER_MIN, STEPPER_MAX)
	sfx.play_sound("click")
	_refresh_slope()

func _on_launch_pressed() -> void:
	if current_state != State.AIM:
		return
	_launch(false)

func _on_skip_pressed() -> void:
	if current_state != State.INTRO:
		return
	_start_game()

func _change_letter(slot: int, amount: int) -> void:
	_letters[slot] = posmod(_letters[slot] + amount, ALPHABET.length())
	letter_labels[slot].text = ALPHABET[_letters[slot]]
	sfx.play_sound("click")

func _on_name_confirmed() -> void:
	var player_name: String = ""
	for idx in _letters:
		player_name += ALPHABET[idx]
	var scores: Array = save_system.add_score(player_name, shots)
	_populate_board(scores)
	name_overlay.visible = false
	board_overlay.visible = true
	current_state = State.BOARD
	sfx.play_sound("ding")

func _on_play_again_pressed() -> void:
	board_overlay.visible = false
	_start_game()

# === UI REFRESH ===
func _refresh_slope() -> void:
	rise_value_label.text = str(rise_value)
	run_value_label.text = str(run_value)
	slope_fraction_label.text = "SLOPE = %d/%d" % [rise_value, run_value]
	slope_words_label.text = "up %d for every %d across" % [rise_value, run_value]
	grid_view.rise_value = rise_value
	grid_view.run_value = run_value
	grid_view.rocket_dir = Vector2(float(run_value), float(rise_value)).normalized()
	grid_view.queue_redraw()

func _update_shots_label() -> void:
	shots_label.text = "SHOTS: %d" % shots

func _set_steppers_enabled(enabled: bool) -> void:
	for btn in _stepper_buttons:
		btn.disabled = not enabled

func _show_banner(text: String, color: Color) -> void:
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", color)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	banner_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	banner_label.visible = true
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner_label, "modulate:a", 1.0, 0.15)
	_banner_tween.tween_interval(1.1)
	_banner_tween.tween_property(banner_label, "modulate:a", 0.0, 0.4)

func _burst_confetti(grid_pos: Vector2) -> void:
	var px: Vector2 = grid_view.grid_to_px(grid_pos)
	for p in _confetti:
		p.position = px
		p.restart()

func _populate_board(scores: Array) -> void:
	var lines: Array[String] = []
	for i in range(scores.size()):
		var entry: Dictionary = scores[i]
		lines.append("%d.  %s  —  %d SHOTS" % [i + 1, str(entry["name"]), int(entry["shots"])])
	if lines.is_empty():
		lines.append("NO SCORES YET")
	board_list_label.text = "\n".join(lines)

# === UI CONSTRUCTION ===
func _build_background() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

func _build_grid_view() -> void:
	grid_view = GridView.new()
	grid_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_view.offset_top = TOP_BAR_HEIGHT
	grid_view.offset_bottom = -BOTTOM_BAR_HEIGHT
	grid_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid_view)

func _build_top_bar() -> void:
	shots_label = Label.new()
	shots_label.text = "SHOTS: 0"
	shots_label.add_theme_font_size_override("font_size", 26)
	shots_label.add_theme_color_override("font_color", COLOR_NEON)
	shots_label.position = Vector2(20.0, 14.0)
	add_child(shots_label)

	level_label = Label.new()
	level_label.text = "LEVEL 1/8"
	level_label.add_theme_font_size_override("font_size", 26)
	level_label.add_theme_color_override("font_color", COLOR_NEON)
	level_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_top = 14.0
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(level_label)

	skip_button = Button.new()
	skip_button.text = "SKIP \u25B6"
	skip_button.custom_minimum_size = Vector2(140.0, 56.0)
	skip_button.add_theme_font_size_override("font_size", 24)
	skip_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_button.offset_left = -160.0
	skip_button.offset_top = 10.0
	skip_button.offset_right = -20.0
	skip_button.offset_bottom = 66.0
	skip_button.pressed.connect(_on_skip_pressed)
	_style_button(skip_button)
	add_child(skip_button)

func _build_bottom_bar() -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -BOTTOM_BAR_HEIGHT
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 44)
	add_child(bar)

	var rise_parts: Dictionary = _make_stepper("Y ('RISE')")
	rise_value_label = rise_parts["value"]
	var rise_minus: Button = rise_parts["minus"]
	var rise_plus: Button = rise_parts["plus"]
	rise_minus.pressed.connect(func() -> void: _change_rise(-1))
	rise_plus.pressed.connect(func() -> void: _change_rise(1))
	bar.add_child(rise_parts["box"])

	var slope_box: VBoxContainer = VBoxContainer.new()
	slope_box.alignment = BoxContainer.ALIGNMENT_CENTER
	slope_box.custom_minimum_size = Vector2(300.0, 0.0)
	slope_fraction_label = Label.new()
	slope_fraction_label.add_theme_font_size_override("font_size", 36)
	slope_fraction_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.85))
	slope_fraction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slope_box.add_child(slope_fraction_label)
	slope_words_label = Label.new()
	slope_words_label.add_theme_font_size_override("font_size", 20)
	slope_words_label.add_theme_color_override("font_color", COLOR_NEON)
	slope_words_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slope_box.add_child(slope_words_label)
	bar.add_child(slope_box)

	var run_parts: Dictionary = _make_stepper("X ('RUN')")
	run_value_label = run_parts["value"]
	var run_minus: Button = run_parts["minus"]
	var run_plus: Button = run_parts["plus"]
	run_minus.pressed.connect(func() -> void: _change_run(-1))
	run_plus.pressed.connect(func() -> void: _change_run(1))
	bar.add_child(run_parts["box"])

	launch_button = Button.new()
	launch_button.text = "LAUNCH!"
	launch_button.custom_minimum_size = Vector2(230.0, 92.0)
	launch_button.add_theme_font_size_override("font_size", 36)
	_style_button(launch_button, Color(0.3, 1.0, 0.5))
	launch_button.pressed.connect(_on_launch_pressed)
	bar.add_child(launch_button)

func _make_stepper(title: String) -> Dictionary:
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var title_label: Label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", COLOR_NEON)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var minus: Button = Button.new()
	minus.text = "\u2212"
	minus.custom_minimum_size = Vector2(76.0, 76.0)
	minus.add_theme_font_size_override("font_size", 40)
	_style_button(minus)
	_stepper_buttons.append(minus)
	row.add_child(minus)
	var value_label: Label = Label.new()
	value_label.text = "1"
	value_label.custom_minimum_size = Vector2(64.0, 76.0)
	value_label.add_theme_font_size_override("font_size", 44)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	var plus: Button = Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(76.0, 76.0)
	plus.add_theme_font_size_override("font_size", 40)
	_style_button(plus)
	_stepper_buttons.append(plus)
	row.add_child(plus)
	box.add_child(row)
	return {"box": box, "minus": minus, "plus": plus, "value": value_label}

func _style_button(btn: Button, border_color: Color = COLOR_NEON) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.10, 0.20)
	normal.border_color = border_color
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(10)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.14, 0.18, 0.32)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = border_color.darkened(0.55)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.06, 0.07, 0.12)
	disabled.border_color = Color(0.3, 0.3, 0.35)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color.WHITE)

func _build_banner() -> void:
	banner_label = Label.new()
	banner_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner_label.offset_top = 90.0
	banner_label.offset_bottom = 170.0
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 52)
	banner_label.add_theme_constant_override("outline_size", 10)
	banner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	banner_label.visible = false
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_label)

func _build_confetti() -> void:
	var colors: Array[Color] = [
		Color(0.3, 1.0, 0.9),
		Color(1.0, 0.4, 0.9),
		Color(1.0, 0.9, 0.3),
	]
	for col in colors:
		var p: CPUParticles2D = CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 36
		p.lifetime = 1.1
		p.explosiveness = 1.0
		p.spread = 180.0
		p.gravity = Vector2(0.0, 500.0)
		p.initial_velocity_min = 180.0
		p.initial_velocity_max = 420.0
		p.scale_amount_min = 2.0
		p.scale_amount_max = 5.0
		p.color = col
		grid_view.add_child(p)
		_confetti.append(p)

func _build_name_overlay() -> void:
	name_overlay = _make_overlay()
	var panel: VBoxContainer = _make_center_panel(name_overlay)
	var title: Label = _make_panel_label("8/8 CLEARED!", 48, COLOR_GOOD)
	panel.add_child(title)
	var shots_line: Label = _make_panel_label("", 32, COLOR_NEON)
	shots_line.name = "ShotsLine"
	panel.add_child(shots_line)
	var hint: Label = _make_panel_label("YOUR NAME:", 24, Color.WHITE)
	panel.add_child(hint)
	var letters_row: HBoxContainer = HBoxContainer.new()
	letters_row.alignment = BoxContainer.ALIGNMENT_CENTER
	letters_row.add_theme_constant_override("separation", 24)
	for slot in range(3):
		var col_box: VBoxContainer = VBoxContainer.new()
		col_box.alignment = BoxContainer.ALIGNMENT_CENTER
		var up: Button = Button.new()
		up.text = "\u25B2"
		up.custom_minimum_size = Vector2(72.0, 56.0)
		up.add_theme_font_size_override("font_size", 28)
		_style_button(up)
		up.pressed.connect(_change_letter.bind(slot, 1))
		col_box.add_child(up)
		var letter: Label = Label.new()
		letter.text = "A"
		letter.add_theme_font_size_override("font_size", 56)
		letter.add_theme_color_override("font_color", Color.WHITE)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter_labels.append(letter)
		col_box.add_child(letter)
		var down: Button = Button.new()
		down.text = "\u25BC"
		down.custom_minimum_size = Vector2(72.0, 56.0)
		down.add_theme_font_size_override("font_size", 28)
		_style_button(down)
		down.pressed.connect(_change_letter.bind(slot, -1))
		col_box.add_child(down)
		letters_row.add_child(col_box)
	panel.add_child(letters_row)
	var ok_button: Button = Button.new()
	ok_button.text = "OK!"
	ok_button.custom_minimum_size = Vector2(180.0, 72.0)
	ok_button.add_theme_font_size_override("font_size", 32)
	_style_button(ok_button, COLOR_GOOD)
	ok_button.pressed.connect(_on_name_confirmed)
	panel.add_child(ok_button)

func _build_board_overlay() -> void:
	board_overlay = _make_overlay()
	var panel: VBoxContainer = _make_center_panel(board_overlay)
	var title: Label = _make_panel_label("HIGH SCORES", 48, COLOR_WARN)
	panel.add_child(title)
	board_list_label = _make_panel_label("", 30, Color.WHITE)
	panel.add_child(board_list_label)
	var again: Button = Button.new()
	again.text = "PLAY AGAIN"
	again.custom_minimum_size = Vector2(240.0, 72.0)
	again.add_theme_font_size_override("font_size", 30)
	_style_button(again, COLOR_GOOD)
	again.pressed.connect(_on_play_again_pressed)
	panel.add_child(again)

func _make_overlay() -> Control:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	return overlay

func _make_center_panel(overlay: Control) -> VBoxContainer:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel: VBoxContainer = VBoxContainer.new()
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 24)
	center.add_child(panel)
	return panel

func _make_panel_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _show_name_entry() -> void:
	current_state = State.NAME_ENTRY
	var shots_line: Label = name_overlay.find_child("ShotsLine", true, false)
	if shots_line != null:
		shots_line.text = "8/8 CLEARED \u2014 SHOTS: %d" % shots
	name_overlay.visible = true

# === UTILITY ===
func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
