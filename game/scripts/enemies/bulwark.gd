class_name Bulwark
extends Enemy
## Armoured walker. Its energy shield deflects everything from the front:
## stomp nearby to short it out, or get behind it faster than it can turn.

enum { GUARD, WINDUP, BASH, REST }
var mode := GUARD
var t := 0.0
var stun := 0.0
var shield: MeshInstance3D

static func make(parent: Node, pos: Vector3) -> Bulwark:
	var e := Bulwark.new()
	e.position = pos + Vector3(0, 1.6, 0)
	parent.add_child(e)
	return e

func _make() -> void:
	hp = 2
	max_hp = 2
	reward = 8
	hit_radius = 1.9
	add_to_group("stomp_listener")
	var m := Build.mat(Color(0.3, 0.36, 0.5), 0.4)
	Build.cyl(body, Vector3(0, 0, 0), 1.4, 2.4, m, false, 1.1, 8)
	Build.visual(body, _sphere(0.9), Build.mat(Color(0.22, 0.25, 0.35), 0.4), Vector3(0, 1.5, 0))
	Build.visual(body, _sphere(0.25, 8), Build.mat(Color(1.0, 0.3, 0.2), 0.3, 2.5), Vector3(0, 1.6, -0.8))
	Build.visual(body, _sphere(0.5, 8), Build.mat(Color(1.0, 0.75, 0.2), 0.3, 1.5), Vector3(0, 0.2, 1.3))   # exposed core on its back
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.3, 0.85, 1.0, 0.55)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.emission_enabled = true
	sm.emission = Color(0.3, 0.85, 1.0)
	sm.emission_energy_multiplier = 1.5
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var c := CylinderMesh.new()
	c.top_radius = 2.3
	c.bottom_radius = 2.3
	c.height = 0.25
	c.radial_segments = 8
	shield = Build.visual(body, c, sm, Vector3(0, 0.3, -1.9), Vector3.ONE, Vector3(PI / 2, 0, 0))

func _reset() -> void:
	mode = GUARD
	stun = 0.0
	shield.visible = true

func on_stomp(pos: Vector3, radius: float) -> void:
	if alive and pos.distance_to(global_position) < radius + 2.0:
		stun = 5.0
		shield.visible = false
		mode = GUARD
		Sfx.play("break", 1.5, -4.0)
		Fx.burst(global_position, Color(0.4, 0.9, 1.0), 14, 8.0, 0.5)

func can_be_hit(p: Player) -> bool:
	if stun > 0.0 or p.state == Player.St.STOMP:
		return true
	var from: Vector3 = p.global_position - global_position
	from.y = 0
	return from.normalized().dot(forward()) < -0.15

func _think(dt: float, p: Player, d: float) -> void:
	t -= dt
	if stun > 0.0:
		stun -= dt
		body.rotation.z = sin(stun * 9.0) * 0.12
		if stun <= 0.0:
			shield.visible = true
			body.rotation.z = 0.0
		return
	var to_p: Vector3 = p.global_position - global_position
	to_p.y = 0
	match mode:
		GUARD:
			if d < 40.0:
				face(to_p, dt, 1.25)
			if d < 9.0 and to_p.normalized().dot(forward()) > 0.7 and t <= 0.0:
				mode = WINDUP
				t = 0.6
				Sfx.play("warn", 0.7, -6.0)
		WINDUP:
			shield.scale = Vector3.ONE * (1.0 + 0.3 * sin(t * 30.0))
			body.position.z = lerpf(0.0, 0.8, 1.0 - t / 0.6)
			if t <= 0.0:
				mode = BASH
				t = 0.3
				shield.scale = Vector3.ONE
				body.position.z = 0.0
		BASH:
			position += forward() * 26.0 * dt
			position.y = ground(position.x, position.z) + 1.6
			if t <= 0.0:
				mode = REST
				t = 1.4
		REST:
			if t <= 0.0:
				mode = GUARD
				t = 1.0
				if global_position.distance_to(home) > 25.0:
					position = home
