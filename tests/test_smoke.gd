extends SceneTree
## Loads main.tscn, runs frames through the intro and a miss and a hit, checks nothing errors and the
## rules still hold (exact-fraction hit test, level 8 order).

var _passed: int = 0
var _failed: int = 0


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
	var m: SlopeShotMain = (load("res://main.tscn") as PackedScene).instantiate() as SlopeShotMain
	get_root().add_child(m)
	for i: int in range(10):
		await process_frame
	_check(m.current_state == SlopeShotMain.State.INTRO, "starts in the intro")
	_check(not m.sfx.unlocked, "no sound has played yet")
	m._on_skip_pressed()
	for i: int in range(5):
		await process_frame
	_check(m.current_state == SlopeShotMain.State.AIM and m.level_idx == 0, "skip starts level 1")

	# Level 1 flag is (3,3): 1/1 hits, 2/1 misses (too steep)
	m.rise_value = 2
	m.run_value = 1
	_check(m._compute_outcome()["type"] == "miss", "2/1 misses flag (3,3)")
	m.rise_value = 4
	m.run_value = 4
	_check(m._compute_outcome()["type"] == "hit", "4/4 hits flag (3,3) (unreduced is fine)")

	# Fly a miss to the end
	m.rise_value = 2
	m.run_value = 1
	m._on_launch_pressed()
	_check(m.current_state == SlopeShotMain.State.FLY, "launch starts a flight")
	var frames: int = 0
	while m.grid_view.is_flying and frames < 600:
		await process_frame
		frames += 1
	_check(not m.grid_view.is_flying and m.current_state == SlopeShotMain.State.AIM, "miss ends the flight and resets")

	# Level 8: two flags, steep one first
	m._load_level(7)
	m.rise_value = 1
	m.run_value = 3
	_check(m._compute_outcome()["type"] == "wrong", "level 8: shallow flag first is the wrong one")
	m.rise_value = 3
	m.run_value = 1
	_check(m._compute_outcome()["type"] == "hit", "level 8: steep flag is the target")

	# Endless levels past 8 still load
	m._load_level(9)
	_check(m.flags.size() == 1, "random level past 8 has one flag")
	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
