class_name TimeTrial
extends Node3D
## Timed gate race. Touch the first gate to start, pass each in order, and
## reach the last one inside the limit to earn the reward.

var points: Array = []
var limit := 20.0
var token_id := ""
var title := "Time Trial"
var running := false
var idx := 0
var t := 0.0
var rings: Array = []
var m_idle := Build.mat(Color(0.5, 0.6, 0.7, 0.5), 0.4, 0.3, true)
var m_next := Build.mat(Color(1.0, 0.85, 0.3), 0.3, 2.5)
var m_done := Build.mat(Color(0.3, 1.0, 0.5), 0.3, 1.2)

static func make(parent: Node, pts: Array, secs: float, tid: String, name_: String) -> TimeTrial:
	var tt := TimeTrial.new()
	tt.points = pts
	tt.limit = secs
	tt.token_id = tid
	tt.title = name_
	parent.add_child(tt)
	return tt

func _ready() -> void:
	add_to_group("respawn_listener")
	var tm := TorusMesh.new()
	tm.inner_radius = 4.2
	tm.outer_radius = 4.8
	tm.rings = 20
	tm.ring_segments = 6
	for i in points.size():
		var mi := MeshInstance3D.new()
		mi.mesh = tm
		add_child(mi)
		mi.global_position = points[i] + Vector3(0, 3.0, 0)
		var nxt: Vector3 = points[(i + 1) % points.size()] if i < points.size() - 1 else points[i] * 2.0 - points[i - 1]
		var d: Vector3 = nxt - points[i]
		mi.rotation = Vector3(PI / 2, atan2(-d.x, -d.z), 0)
		rings.append(mi)
	_paint()

func _paint() -> void:
	for i in rings.size():
		var mi: MeshInstance3D = rings[i]
		if not running:
			mi.material_override = m_next if i == 0 else m_idle
			mi.visible = i == 0 or i == rings.size() - 1
		else:
			mi.visible = true
			mi.material_override = m_done if i < idx else (m_next if i == idx else m_idle)

func on_player_respawn() -> void:
	if running:
		_stop("")

func _stop(msg: String) -> void:
	running = false
	Game.timer_changed.emit(false, 0.0, limit)
	if msg != "":
		Game.say(msg, 3.5)
	_paint()

func _physics_process(dt: float) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p):
		return
	var pp: Vector3 = p.global_position
	if not running:
		if pp.distance_to(points[0] + Vector3(0, 2, 0)) < 5.0 and p.speed() > 1.0:
			running = true
			idx = 1
			t = 0.0
			Sfx.play("check", 1.3)
			Game.say("%s: reach every gate in %d seconds!" % [title, int(limit)], 3.0)
			_paint()
		return
	t += dt
	Game.timer_changed.emit(true, t, limit)
	if t > limit:
		Sfx.play("hurt", 0.8)
		_stop("Time's up! Touch the first gate to try again.")
		return
	if pp.distance_to(points[0]) > 400.0:
		_stop("")
		return
	var gate: Vector3 = points[idx] + Vector3(0, 2.5, 0)
	var back: Vector3 = pp - p.velocity * dt
	if Geometry3D.get_closest_point_to_segment(gate, back, pp).distance_to(gate) < 6.0:
		idx += 1
		Sfx.play("spark", 0.7 + idx * 0.08)
		p.add_boost(12.0)
		if idx >= points.size():
			Sfx.play("win")
			var first := not Game.tokens.has(token_id)
			_stop("%s cleared in %.1fs!" % [title, t])
			if first:
				Game.collect_token(token_id)
				Sfx.play("token")
			return
		_paint()
