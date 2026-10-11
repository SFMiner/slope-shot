# === HEADER COMMENT ===
# sfx.gd
# Procedural retro sound effects, generated as PCM samples at startup.
# Part of Slope Shot educational game.
# WHY runtime PCM: web exports only import .ogg audio assets cleanly, but
# an AudioStreamWAV built in code needs no imported asset file at all —
# zero import pipeline risk, works identically on desktop and web.

class_name Sfx
extends Node

# === CONSTANTS ===
const MIX_RATE: int = 22050

# === PRIVATE VARIABLES ===
var _players: Dictionary = {}
# No sound until the player's first click or key (browsers and the site's
# accessibility rules both require it), and the player can mute at any time.
var unlocked: bool = false
var muted: bool = false

# === LIFECYCLE METHODS ===
func _ready() -> void:
	_add_sound("click", _gen_click())
	_add_sound("whoosh", _gen_whoosh())
	_add_sound("ding", _gen_ding())
	_add_sound("buzz", _gen_buzz())

# === PUBLIC METHODS ===
func unlock() -> void:
	unlocked = true

func play_sound(sound_name: String) -> void:
	if not unlocked or muted:
		return
	if _players.has(sound_name):
		_players[sound_name].play()
	else:
		push_warning("Sound '%s' not found" % sound_name)

# === PRIVATE METHODS ===
func _add_sound(sound_name: String, samples: PackedFloat32Array) -> void:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	stream.data = bytes
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	_players[sound_name] = player

func _gen_click() -> PackedFloat32Array:
	# Short bright tick for stepper presses — feedback without distraction.
	var n: int = int(0.05 * MIX_RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		out[i] = sin(TAU * 1100.0 * t) * exp(-60.0 * t) * 0.5
	return out

func _gen_whoosh() -> PackedFloat32Array:
	# Launch sound: noise through a closing one-pole lowpass. The falling
	# cutoff reads as "falling pitch" — a cheap convincing rocket whoosh.
	var n: int = int(0.7 * MIX_RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var y: float = 0.0
	for i in range(n):
		var progress: float = float(i) / float(n)
		var alpha: float = lerpf(0.45, 0.04, progress)
		y += alpha * (randf_range(-1.0, 1.0) - y)
		var env: float = minf(progress * 8.0, 1.0) * pow(1.0 - progress, 1.5)
		out[i] = y * env * 0.9
	return out

func _gen_ding() -> PackedFloat32Array:
	# Hit sound: two harmonically related sines, exponential decay.
	# Misses get a quiet buzz; hits get THIS — the reward must be louder
	# and longer than the failure, by design, for these students.
	var n: int = int(0.6 * MIX_RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var tone: float = sin(TAU * 880.0 * t) * 0.55 + sin(TAU * 1318.5 * t) * 0.3
		out[i] = tone * exp(-6.0 * t) * 0.8
	return out

func _gen_buzz() -> PackedFloat32Array:
	# Miss sound: short, quiet, low. Misses must feel cheap and private —
	# no klaxon, nothing the whole room turns around for.
	var n: int = int(0.28 * MIX_RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(n)
		var square: float = 1.0 if fmod(t * 95.0, 1.0) < 0.5 else -1.0
		out[i] = square * 0.18 * (1.0 - progress * 0.5)
	return out
