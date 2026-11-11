class_name Grunt
extends Enemy
## Basic rolling sentry: wanders near home, then telegraphs and charges.

enum { WANDER, WINDUP, CHARGE, REST }
var mode := WANDER
var t := 0.0
var wander_to := Vector3.ZERO
var eye: MeshInstance3D
var dir := Vector3.FORWARD

static func make(parent: Node, pos: Vector3, hover_h: float = 0.0) -> Grunt:
	var e := Grunt.new()
	e.position = pos + Vector3(0, 1.1, 0)
	e.hover = hover_h + 1.1 if hover_h > 0.0 else 0.0
	parent.add_child(e)
	return e

func _make() -> void:
	hit_radius = 1.3
	Build.visual(body, _sphere(1.0), Build.mat(Color(0.85, 0.25, 0.22), 0.5), Vector3.ZERO)
	var t2 := TorusMesh.new()
	t2.inner_radius = 0.85
	t2.outer_radius = 1.2
	t2.rings = 14
	t2.ring_segments = 6
	Build.visual(body, t2, Build.mat(Color(0.2, 0.2, 0.25), 0.5), Vector3.ZERO, Vector3.ONE, Vector3(0, 0, PI / 2))
	eye = Build.visual(body, _sphere(0.35, 8), Build.mat(Color(1.0, 0.9, 0.3), 0.3, 2.0), Vector3(0, 0.25, -0.8))
	wander_to = home
	_reset()

func _reset() -> void:
	mode = WANDER
	t = randf_range(0.5, 2.0)
	eye.scale = Vector3.ONE

func _think(dt: float, p: Player, d: float) -> void:
	t -= dt
	var to_p: Vector3 = p.global_position - global_position
	to_p.y = 0
	match mode:
		WANDER:
			if t <= 0.0:
				t = randf_range(1.5, 3.0)
				wander_to = home + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))
			var to := wander_to - global_position
			to.y = 0
			if to.length() > 0.5:
				_move(to.normalized() * 3.5, dt)
			if d < 24.0 and absf(p.global_position.y - global_position.y) < 7.0:
				mode = WINDUP
				t = 0.55
				Sfx.play("warn", 1.0, -8.0)
		WINDUP:
			# telegraph: eye swells, body shakes while turning to the player
			face(to_p, dt, 8.0)
			eye.scale = Vector3.ONE * (1.0 + (0.55 - t) * 2.0)
			body.position = Vector3(randf_range(-0.06, 0.06), 0, randf_range(-0.06, 0.06))
			if t <= 0.0:
				mode = CHARGE
				t = 1.1
				dir = to_p.normalized() if to_p.length() > 0.1 else forward()
				body.position = Vector3.ZERO
		CHARGE:
			_move(dir * 17.0, dt)
			body.rotate_object_local(Vector3.RIGHT, -dt * 14.0)
			if t <= 0.0 or global_position.distance_to(home) > 40.0:
				mode = REST
				t = 1.2
				eye.scale = Vector3.ONE
		REST:
			if t <= 0.0:
				mode = WANDER
				wander_to = home

func _move(v: Vector3, dt: float) -> void:
	position += v * dt
	position.y = ground(position.x, position.z) + 1.1
	if v.length() > 0.5:
		face(v, dt, 6.0)
