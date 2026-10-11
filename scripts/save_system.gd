# === HEADER COMMENT ===
# save_system.gd
# High-score persistence: browser localStorage on web, user:// JSON on desktop.
# Part of Slope Shot educational game.
# Scores are local-only by design — the teacher reads them off the screen
# and posts them on the physical board. No networking, no accounts.

class_name SaveSystem
extends Node

# === CONSTANTS ===
const SAVE_KEY: String = "slope_shot_highscores"
const SAVE_PATH: String = "user://slope_shot_highscores.json"
const MAX_SCORES: int = 5

# === PRIVATE VARIABLES ===
# Untyped on purpose: JavaScriptObject only exists in web builds, so a
# type hint here would break desktop parsing.
var _js_storage = null

# === LIFECYCLE METHODS ===
func _ready() -> void:
	if OS.has_feature("web"):
		_js_storage = JavaScriptBridge.get_interface("localStorage")

# === PUBLIC METHODS ===
func save_scores(scores: Array) -> bool:
	var json_string: String = JSON.stringify(scores)
	if OS.has_feature("web") and _js_storage:
		_js_storage.setItem(SAVE_KEY, json_string)
		return true
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		return true
	push_warning("Could not save high scores")
	return false

func load_scores() -> Array:
	var json_string: String = ""
	if OS.has_feature("web") and _js_storage:
		var raw = _js_storage.getItem(SAVE_KEY)
		if raw != null:
			json_string = str(raw)
	elif FileAccess.file_exists(SAVE_PATH):
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			json_string = file.get_as_text()
			file.close()
	if json_string == "" or json_string == "null":
		return []
	var json: JSON = JSON.new()
	if json.parse(json_string) == OK and json.data is Array:
		return json.data
	return []

func add_score(player_name: String, shots: int) -> Array:
	# Insert, sort ascending (fewer shots is better), keep top five.
	var scores: Array = load_scores()
	scores.append({"name": player_name, "shots": shots})
	scores.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["shots"]) < int(b["shots"])
	)
	if scores.size() > MAX_SCORES:
		scores.resize(MAX_SCORES)
	save_scores(scores)
	return scores
