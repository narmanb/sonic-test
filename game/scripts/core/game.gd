extends Node
## Global game state: progression, save data, settings.

signal sparks_changed(n: int)
signal tokens_changed(n: int)
signal message(text: String, secs: float)
signal objective_changed(text: String)
signal settings_changed
signal timer_changed(active: bool, t: float, limit: float)
signal boss_hp_changed(active: bool, frac: float)

const SAVE_PATH := "user://save.json"
const TOKENS_TOTAL := 10
const TOKENS_FOR_GUARDIAN := 6

var player = null
var camera = null
var world = null

var sparks := 0
var tokens := {}            # id -> true
var flags := {}             # challenge / puzzle / boss flags
var checkpoint_id := ""
var checkpoint_pos := Vector3.ZERO
var has_checkpoint := false
var objective := ""

var settings := {
	"quality": 1,            # 0 low, 1 medium, 2 high
	"cam_dist": 7.0,
	"cam_sens": 1.0,
	"invert_y": false,
	"touch_mode": 0,         # 0 auto, 1 always, 2 never
	"touch_scale": 1.0,
	"touch_opacity": 0.55,
	"touch_swap": false,
	"volume": 0.8,
	"show_fps": false,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()

func token_count() -> int:
	return tokens.size()

func add_sparks(n: int) -> void:
	sparks = max(0, sparks + n)
	sparks_changed.emit(sparks)

func collect_token(id: String) -> bool:
	if tokens.has(id):
		return false
	tokens[id] = true
	tokens_changed.emit(tokens.size())
	say("Aurora Core %d / %d" % [tokens.size(), TOKENS_TOTAL], 3.0)
	if tokens.size() == TOKENS_FOR_GUARDIAN:
		say("The Guardian's seal has broken! Head to the basin in the north-west.", 6.0)
	update_objective()
	save_game()
	return true

func set_flag(id: String) -> void:
	flags[id] = true
	update_objective()
	save_game()

func has_flag(id: String) -> bool:
	return flags.has(id)

func say(text: String, secs: float = 3.0) -> void:
	message.emit(text, secs)

func set_checkpoint(id: String, pos: Vector3) -> void:
	if checkpoint_id == id and has_checkpoint:
		return
	checkpoint_id = id
	checkpoint_pos = pos
	has_checkpoint = true
	save_game()

func update_objective() -> void:
	if has_flag("guardian_defeated"):
		objective = "Island restored! Explore freely  (%d/%d cores)" % [tokens.size(), TOKENS_TOTAL]
	elif tokens.size() >= TOKENS_FOR_GUARDIAN:
		objective = "Challenge the Guardian in the north-west basin"
	else:
		objective = "Collect Aurora Cores to break the Guardian's seal  (%d/%d)" % [tokens.size(), TOKENS_FOR_GUARDIAN]
	objective_changed.emit(objective)

func reset_progress() -> void:
	sparks = 0
	tokens = {}
	flags = {}
	checkpoint_id = ""
	has_checkpoint = false
	save_game()

func has_progress() -> bool:
	return tokens.size() > 0 or has_checkpoint or flags.size() > 0

func save_game() -> void:
	if world != null and world.get("is_test"):
		_write({"settings": settings}, true)
		return
	var d := {
		"sparks": sparks, "tokens": tokens.keys(), "flags": flags.keys(),
		"checkpoint_id": checkpoint_id, "has_checkpoint": has_checkpoint,
		"checkpoint_pos": [checkpoint_pos.x, checkpoint_pos.y, checkpoint_pos.z],
		"settings": settings,
	}
	_write(d, false)

func _write(d: Dictionary, settings_only: bool) -> void:
	if settings_only:
		var old := _read()
		old["settings"] = d["settings"]
		d = old
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func _read() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

func load_game() -> void:
	var d := _read()
	sparks = int(d.get("sparks", 0))
	tokens = {}
	for t in d.get("tokens", []):
		tokens[str(t)] = true
	flags = {}
	for t in d.get("flags", []):
		flags[str(t)] = true
	checkpoint_id = str(d.get("checkpoint_id", ""))
	has_checkpoint = bool(d.get("has_checkpoint", false))
	var p = d.get("checkpoint_pos", [0, 0, 0])
	if p is Array and p.size() == 3:
		checkpoint_pos = Vector3(p[0], p[1], p[2])
	var s = d.get("settings", {})
	if s is Dictionary:
		for k in s:
			if settings.has(k):
				settings[k] = s[k]

func save_settings() -> void:
	_write({"settings": settings}, true)
	apply_settings()

func apply_settings() -> void:
	var q := int(settings["quality"])
	var vp := get_viewport()
	vp.scaling_3d_scale = [0.6, 0.8, 1.0][q]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X][q]
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(settings["volume"]))))
	settings_changed.emit()
