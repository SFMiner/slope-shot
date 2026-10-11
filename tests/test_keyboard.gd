extends SceneTree
## Keyboard use and the sims-site keyboard exit: Tab walks the usable controls in order, Tab past the last and
## Shift+Tab before the first leave, Escape leaves, arrows and Enter do what the mouse does, M mutes,
## nothing makes sound before the first input.

var _passed: int = 0
var _failed: int = 0
var _main: SlopeShotMain = null


func _init() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + label)


func _run() -> void:
	await get_root().ready
	_main = (load("res://main.tscn") as PackedScene).instantiate() as SlopeShotMain
	get_root().add_child(_main)
	for i: int in range(5):
		await process_frame
	var nav: KeyboardNav = _main.keyboard
	_check(nav != null, "KeyboardNav is set up")
	if nav == null:
		_finish()
		return
	_check(not _main.sfx.unlocked, "no sound before the first input")

	# Intro: SKIP is visible, so 7 stops (skip, rise -/+, run -/+, launch, sound)
	var stops: Array[Control] = []
	var before: int = nav.leave_count
	for i: int in range(12):
		await _key(KEY_TAB)
		var f: Control = get_root().gui_get_focus_owner()
		if f == null:
			break
		stops.append(f)
	_check(_main.sfx.unlocked, "first key unlocks sound")
	_check(stops.size() == 7, "Tab reaches 7 controls during the intro (got %d)" % stops.size())
	_check(nav.leave_count == before + 1, "Tab past the last control leaves")
	if stops.size() == 7:
		_check(stops[0] == _main.skip_button, "first stop is SKIP")
		_check(stops[5] == _main.launch_button, "sixth stop is LAUNCH")
		_check(stops[6] == _main.mute_button, "last stop is SOUND")

	# Skip the intro with Enter on nothing focused, then the game has 6 stops
	await _key(KEY_ENTER)
	_check(_main.current_state == SlopeShotMain.State.AIM, "Enter skips the intro")
	_check(get_root().gui_get_focus_owner() == _main.launch_button, "keyboard play puts focus on LAUNCH after the skip")
	get_root().gui_release_focus()
	stops.clear()
	before = nav.leave_count
	for i: int in range(12):
		await _key(KEY_TAB)
		var f2: Control = get_root().gui_get_focus_owner()
		if f2 == null:
			break
		stops.append(f2)
	_check(stops.size() == 6, "Tab reaches 6 controls in play (got %d)" % stops.size())
	_check(nav.leave_count == before + 1, "Tab past the last control leaves (play)")
	_check(not _main.skip_button.visible, "SKIP is gone in play")
	if stops.size() == 6:
		_check(stops[0] == _main.get("_stepper_buttons")[0], "first stop is the rise minus button")
		_check(stops[4] == _main.launch_button, "fifth stop is LAUNCH")

	# Shift+Tab from nothing starts at the end and walks back, then leaves
	before = nav.leave_count
	var back: int = 0
	for i: int in range(12):
		await _key(KEY_TAB, true)
		if get_root().gui_get_focus_owner() == null:
			break
		back += 1
	_check(back == 6, "Shift+Tab walks 6 controls back (got %d)" % back)
	_check(nav.leave_count == before + 1, "Shift+Tab before the first control leaves")

	# Shift+Tab on the last control moves back, it does not leave
	_main.mute_button.grab_focus()
	before = nav.leave_count
	await _key(KEY_TAB, true)
	_check(nav.leave_count == before and get_root().gui_get_focus_owner() == _main.launch_button, "Shift+Tab on the last control moves back")

	# Escape leaves from the middle
	before = nav.leave_count
	await _key(KEY_ESCAPE)
	_check(nav.leave_count == before + 1, "Escape leaves")
	_check(get_root().gui_get_focus_owner() == null, "focus released after Escape")

	# Arrows change rise and run, clamped
	var rise: int = _main.rise_value
	var run: int = _main.run_value
	await _key(KEY_UP)
	await _key(KEY_RIGHT)
	_check(_main.rise_value == rise + 1 and _main.run_value == run + 1, "Up/Right raise rise and run")
	await _key(KEY_DOWN)
	await _key(KEY_LEFT)
	_check(_main.rise_value == rise and _main.run_value == run, "Down/Left lower them again")
	await _key(KEY_DOWN)
	_check(_main.rise_value == SlopeShotMain.STEPPER_MIN, "rise stops at the minimum")

	# M mutes and unmutes
	await _key(KEY_M)
	_check(_main.sfx.muted and _main.mute_button.text == "SOUND: OFF", "M mutes")
	await _key(KEY_M)
	_check(not _main.sfx.muted and _main.mute_button.text == "SOUND: ON", "M unmutes")

	# Enter with nothing focused launches
	var shots: int = _main.shots
	await _key(KEY_ENTER)
	_check(_main.shots == shots + 1 and _main.current_state == SlopeShotMain.State.FLY, "Enter launches")
	# During flight the disabled steppers are not Tab stops
	_check(nav.get_stops().size() == 1, "only SOUND is a stop while the rocket flies")

	# Every stop has the focus outline
	for c: Control in [_main.launch_button, _main.mute_button, _main.skip_button]:
		_check(c.has_theme_stylebox_override("focus"), "%s has the focus outline" % c.name)
	_finish()


func _finish() -> void:
	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _key(code: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.shift_pressed = shift
		e.pressed = pressed
		get_root().push_input(e)
	await process_frame
	await process_frame
