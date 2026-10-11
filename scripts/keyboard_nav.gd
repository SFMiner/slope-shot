# === HEADER COMMENT ===
# keyboard_nav.gd
# Keyboard use and the keyboard exit for the sims site (SPEC section 6).
# Tab walks the usable controls in order; Tab past the last or Shift+Tab before
# the first leaves the game; Escape leaves. Arrow keys, Enter and M are
# shortcuts for the things a mouse does. Tab order is the array passed to setup().

class_name KeyboardNav
extends Node

# === SIGNALS ===
# action is one of: rise_up, rise_down, run_up, run_down, launch, mute
signal shortcut(action: String)
## Any key or click: lets main unlock sound even though this node handles the key first.
signal activity

# === CONSTANTS ===
const FOCUS_COLOR: Color = Color(1.0, 0.85, 0.2)

# === PUBLIC VARIABLES ===
## Times the keyboard left the game; read by tests/test_keyboard.gd.
var leave_count: int = 0
## True after a key press, false after a mouse click: decides whether to put focus back on LAUNCH.
var keyboard_mode: bool = false

# === PRIVATE VARIABLES ===
var _controls: Array[Control] = []
var _ring: StyleBoxFlat = null

# === LIFECYCLE METHODS ===
func _ready() -> void:
	_ring = StyleBoxFlat.new()
	_ring.draw_center = false
	_ring.border_color = FOCUS_COLOR
	_ring.set_border_width_all(4)
	_ring.set_corner_radius_all(10)
	_ring.set_expand_margin_all(3.0)

# === PUBLIC METHODS ===
func setup(controls: Array[Control]) -> void:
	_controls = controls
	for c: Control in _controls:
		c.focus_mode = Control.FOCUS_ALL
		c.add_theme_stylebox_override("focus", _ring)

## Controls Tab can land on right now (visible and enabled), in Tab order.
func get_stops() -> Array[Control]:
	var out: Array[Control] = []
	for c: Control in _controls:
		var b: BaseButton = c as BaseButton
		if c.is_visible_in_tree() and (b == null or not b.disabled):
			out.append(c)
	return out

## Drops focus and asks the sims site's play page to take the keyboard back. On its own page there is no parent.
func leave_game() -> void:
	get_viewport().gui_release_focus()
	leave_count += 1
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
				"if (window.parent !== window) window.parent.postMessage({type: 'sims:leave-game'}, location.origin)")

# === INPUT ===
func _input(event: InputEvent) -> void:
	# _input, not _unhandled_input: the GUI takes Tab and the arrow keys for its own focus movement first.
	if event is InputEventMouseButton and event.pressed:
		keyboard_mode = false
		activity.emit()
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	keyboard_mode = true
	activity.emit()
	var focus: Control = get_viewport().gui_get_focus_owner()
	if event.is_action_pressed("ui_cancel"):
		_handled()
		leave_game()
		return
	# Exact match (third argument): without it ui_focus_next also matches Shift+Tab
	if event.is_action_pressed("ui_focus_next", true, true):
		_tab(focus, 1)
		return
	if event.is_action_pressed("ui_focus_prev", true, true):
		_tab(focus, -1)
		return
	if key.echo:
		return
	match key.keycode:
		KEY_UP:
			_emit("rise_up")
		KEY_DOWN:
			_emit("rise_down")
		KEY_RIGHT:
			_emit("run_up")
		KEY_LEFT:
			_emit("run_down")
		KEY_L:
			_emit("launch")
		KEY_M:
			_emit("mute")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			# A focused button takes Enter/Space itself (presses it), so this only runs with nothing focused
			if focus == null:
				_emit("launch")

# === PRIVATE METHODS ===
func _emit(action: String) -> void:
	_handled()
	shortcut.emit(action)

func _handled() -> void:
	get_viewport().set_input_as_handled()

func _tab(focus: Control, step: int) -> void:
	var stops: Array[Control] = get_stops()
	_handled()
	if stops.is_empty():
		leave_game()
		return
	var idx: int = stops.find(focus)
	if idx == -1:
		# Nothing (or something not in the list) focused: start at the end Tab came from
		stops[0 if step > 0 else stops.size() - 1].grab_focus()
		return
	var target: int = idx + step
	if target < 0 or target >= stops.size():
		leave_game()
		return
	stops[target].grab_focus()
