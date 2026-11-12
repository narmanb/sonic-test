extends Node3D
## Original placeholder hero ("Zip", a wind sprite) built from primitives and
## animated procedurally: run cycle tied to speed, lean, curl ball, charge spin.

var p: Player
var rig: Node3D            # oriented to facing + ground normal
var body_root: Node3D      # limbs & torso (hidden while curled)
var ball_root: Node3D
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var torso: Node3D
var head: Node3D
var scarf: Array[Node3D] = []
var aura: MeshInstance3D
var trail: MeshInstance3D
var trail_mesh: ImmediateMesh
var trail_pts: Array[Vector3] = []
var phase := 0.0
var lean := 0.0
var up_s := Vector3.UP
var fwd_s := Vector3.FORWARD
var prev_fwd := Vector3.FORWARD
var spin := 0.0
var dust_t := 0.0

const C_BODY := Color(0.1, 0.72, 0.68)
const C_DARK := Color(0.06, 0.2, 0.32)
const C_ACC := Color(1.0, 0.62, 0.12)
const C_SKIN := Color(0.98, 0.93, 0.82)

func _mat(c: Color, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _ready() -> void:
	p = get_parent()
	rig = Node3D.new()
	add_child(rig)
	body_root = Node3D.new()
	body_root.position.y = -0.5
	rig.add_child(body_root)
	ball_root = Node3D.new()
	rig.add_child(ball_root)

	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 16
	sph.rings = 8
	var cap := CapsuleMesh.new()
	cap.radius = 0.5
	cap.height = 2.0
	cap.radial_segments = 10
	cap.rings = 4
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 8
	var box := BoxMesh.new()

	var m_body := _mat(C_BODY)
	var m_dark := _mat(C_DARK)
	var m_acc := _mat(C_ACC)
	var m_skin := _mat(C_SKIN)
	var m_eye := _mat(Color(0.5, 1.0, 0.95), 2.0)

	# torso + head (model faces -Z)
	torso = Node3D.new()
	torso.position = Vector3(0, 0.62, 0)
	body_root.add_child(torso)
	_part(torso, sph, m_body, Vector3.ZERO, Vector3(0.52, 0.6, 0.46))
	_part(torso, sph, m_skin, Vector3(0, -0.02, -0.1), Vector3(0.36, 0.42, 0.3))
	head = Node3D.new()
	head.position = Vector3(0, 0.5, -0.02)
	torso.add_child(head)
	_part(head, sph, m_body, Vector3.ZERO, Vector3(0.62, 0.56, 0.6))
	_part(head, sph, m_dark, Vector3(0, 0.02, -0.17), Vector3(0.5, 0.26, 0.34))        # visor
	_part(head, sph, m_eye, Vector3(-0.1, 0.03, -0.3), Vector3(0.1, 0.13, 0.08))
	_part(head, sph, m_eye, Vector3(0.1, 0.03, -0.3), Vector3(0.1, 0.13, 0.08))
	# swept-back crest fins
	for sx in [-1.0, 1.0]:
		_part(head, cone, m_body, Vector3(0.17 * sx, 0.2, 0.2), Vector3(0.2, 0.62, 0.12), Vector3(-2.0, 0.25 * sx, 0))
	_part(head, cone, m_acc, Vector3(0, 0.27, 0.16), Vector3(0.14, 0.7, 0.1), Vector3(-1.9, 0, 0))
	# scarf: chain of segments streaming behind
	var sparent: Node3D = torso
	for i in 4:
		var seg := Node3D.new()
		seg.position = Vector3(0, 0.3, 0.16) if i == 0 else Vector3(0, 0, 0.3)
		sparent.add_child(seg)
		_part(seg, box, m_acc, Vector3(0, 0, 0.15), Vector3(0.22 - i * 0.03, 0.04, 0.32))
		scarf.append(seg)
		sparent = seg
	_part(torso, sph, m_acc, Vector3(0, 0.3, 0), Vector3(0.44, 0.14, 0.42))
	# limbs
	for sx in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.14 * sx, 0.42, 0)
		body_root.add_child(hip)
		_part(hip, cap, m_dark, Vector3(0, -0.17, 0), Vector3(0.11, 0.17, 0.11))
		_part(hip, sph, m_acc, Vector3(0, -0.36, -0.07), Vector3(0.2, 0.15, 0.34))
		legs.append(hip)
		var sh := Node3D.new()
		sh.position = Vector3(0.27 * sx, 0.72, 0)
		body_root.add_child(sh)
		_part(sh, cap, m_body, Vector3(0, -0.14, 0), Vector3(0.08, 0.14, 0.08))
		_part(sh, sph, m_skin, Vector3(0, -0.3, 0), Vector3(0.15, 0.15, 0.15))
		arms.append(sh)

	# curl ball
	_part(ball_root, sph, m_body, Vector3.ZERO, Vector3(0.95, 0.95, 0.95))
	var band := TorusMesh.new()
	band.inner_radius = 0.36
	band.outer_radius = 0.5
	band.rings = 16
	band.ring_segments = 6
	_part(ball_root, band, m_acc, Vector3.ZERO, Vector3.ONE, Vector3(0, 0, PI / 2))
	ball_root.visible = false

	# boost aura
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.albedo_color = Color(0.45, 0.95, 1.0, 0.35)
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	am.cull_mode = BaseMaterial3D.CULL_DISABLED
	aura = _part(rig, cone, am, Vector3(0, 0.05, -0.2), Vector3(1.7, 2.6, 1.7), Vector3(-PI / 2, 0, 0))
	aura.visible = false

	# speed trail (world space ribbon)
	trail_mesh = ImmediateMesh.new()
	trail = MeshInstance3D.new()
	trail.mesh = trail_mesh
	trail.top_level = true
	trail.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.vertex_color_use_as_albedo = true
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	trail.material_override = tm
	add_child(trail)

func _process(dt: float) -> void:
	if p == null or not visible:
		trail_pts.clear()
		trail_mesh.clear_surfaces()
		return
	var spd := p.speed()
	var grounded := p.state == Player.St.GROUND or p.state == Player.St.CHARGE
	var grind := p.state == Player.St.GRIND
	var curled := p.ball or p.rolling or p.state == Player.St.CHARGE or p.state == Player.St.HOMING or p.state == Player.St.STOMP

	# --- orientation
	var up_t := p.ground_normal if grounded else Vector3.UP
	if grind and p.rail != null:
		var tn: Vector3 = p.rail.tangent(p.rail_off)
		up_t = (Vector3.UP - tn * tn.y).normalized()
	up_s = _nl(up_s, up_t, dt * 14.0)
	var f := p.facing
	if grounded and spd > 1.0:
		f = p.velocity.normalized()
	elif grind:
		f = p.velocity.normalized()
	f = (f - up_s * f.dot(up_s))
	if f.length() < 0.05:
		f = fwd_s - up_s * fwd_s.dot(up_s)
	if f.length() < 0.05:
		f = up_s.cross(Vector3.RIGHT)
	f = f.normalized()
	fwd_s = _nl(fwd_s, f, dt * 18.0)
	var fz := (fwd_s - up_s * fwd_s.dot(up_s)).normalized()
	if fz.length() > 0.5:
		var right := fz.cross(up_s).normalized()
		rig.basis = Basis(right, up_s, -fz).orthonormalized()
	# lean into turns
	var turn := prev_fwd.cross(fwd_s).dot(up_s) / maxf(dt, 0.001)
	prev_fwd = fwd_s
	lean = lerpf(lean, clampf(turn * 0.12, -0.6, 0.6) * clampf(spd / 20.0, 0, 1), clampf(dt * 8.0, 0, 1))

	body_root.visible = not curled
	ball_root.visible = curled
	visible = p.invuln_t <= 0.0 or fmod(p.invuln_t, 0.12) > 0.05 or p.state == Player.St.DEAD

	if curled:
		var rate := 18.0 + spd * 0.5
		if p.state == Player.St.CHARGE:
			rate = 20.0 + p.charge * 40.0
			dust_t -= dt
			if dust_t <= 0.0:
				dust_t = 0.07
				Fx.burst(p.global_position - up_s * 0.4 - fwd_s * 0.5, Color(0.9, 0.9, 0.85, 0.7), 3, 5.0, 0.3, 0.6)
		spin += rate * dt
		ball_root.rotation = Vector3(-spin, 0, 0)
		var sq := 1.0
		if p.state == Player.St.STOMP:
			sq = 1.25
		ball_root.scale = Vector3(1.0 / sqrt(sq), sq, 1.0 / sqrt(sq)) if p.state == Player.St.STOMP else Vector3.ONE
	else:
		_animate_body(dt, spd, grounded, grind)

	# --- boost visuals
	aura.visible = p.boosting
	if aura.visible:
		var s := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.04)
		aura.scale = Vector3(1.7 * s, 2.6, 1.7 * s)
	_update_trail(spd)

	# --- running dust
	if grounded and (p.skidding or (spd > 30.0 and not curled)):
		dust_t -= dt
		if dust_t <= 0.0:
			dust_t = 0.06 if p.skidding else 0.12
			Fx.burst(p.global_position - up_s * 0.45, Color(0.92, 0.9, 0.82, 0.6), 2, 2.5, 0.35, 0.7)

func _nl(a: Vector3, b: Vector3, t: float) -> Vector3:
	if a.dot(b) < -0.95:
		return b
	var r := a.lerp(b, clampf(t, 0.0, 1.0))
	return r.normalized() if r.length() > 0.001 else b

func _animate_body(dt: float, spd: float, grounded: bool, grind: bool) -> void:
	var run := clampf(spd / Player.TOP_RUN, 0.0, 1.6)
	body_root.rotation = Vector3(0, 0, -lean)
	if grind:
		# surfing pose
		torso.rotation = Vector3(0.25, 0.9, 0)
		legs[0].rotation = Vector3(0.5, 0, 0)
		legs[1].rotation = Vector3(-0.4, 0, 0)
		arms[0].rotation = Vector3(0, 0, -1.2)
		arms[1].rotation = Vector3(0, 0, 1.2)
		body_root.position.y = -0.5
	elif grounded:
		phase += dt * (5.0 + minf(spd, 60.0) * 0.55) * (1.0 if spd > 0.4 else 0.0)
		var amp := clampf(spd / 8.0, 0.0, 1.0) * lerpf(0.75, 1.25, clampf(run, 0, 1))
		if spd < 0.4:
			# idle breathing
			var t := Time.get_ticks_msec() * 0.003
			torso.rotation = Vector3(0.03 * sin(t), 0, 0)
			legs[0].rotation = legs[0].rotation.lerp(Vector3.ZERO, dt * 10.0)
			legs[1].rotation = legs[1].rotation.lerp(Vector3.ZERO, dt * 10.0)
			arms[0].rotation = arms[0].rotation.lerp(Vector3(0, 0, -0.15), dt * 10.0)
			arms[1].rotation = arms[1].rotation.lerp(Vector3(0, 0, 0.15), dt * 10.0)
			body_root.position.y = -0.5 + 0.01 * sin(t)
		else:
			var s := sin(phase)
			legs[0].rotation = Vector3(s * amp, 0, 0)
			legs[1].rotation = Vector3(-s * amp, 0, 0)
			var fast := clampf((spd - 24.0) / 12.0, 0.0, 1.0)
			# at high speed the arms sweep back, sprint style
			arms[0].rotation = Vector3(lerpf(-s * amp * 0.9, 1.25, fast), 0, -0.2 - 0.3 * fast)
			arms[1].rotation = Vector3(lerpf(s * amp * 0.9, 1.25, fast), 0, 0.2 + 0.3 * fast)
			var brake := 0.5 if p.skidding else 0.0
			torso.rotation = Vector3(-0.12 - 0.42 * clampf(run, 0, 1.3) + brake, 0, 0)
			body_root.position.y = -0.5 + absf(cos(phase)) * 0.05 * amp
	else:
		# airborne (springs / falling)
		var vy := clampf(p.velocity.y / 20.0, -1.0, 1.0)
		torso.rotation = Vector3(-0.2 * vy, 0, 0)
		legs[0].rotation = legs[0].rotation.lerp(Vector3(0.5 - 0.3 * vy, 0, 0), dt * 10.0)
		legs[1].rotation = legs[1].rotation.lerp(Vector3(-0.3 - 0.3 * vy, 0, 0), dt * 10.0)
		arms[0].rotation = arms[0].rotation.lerp(Vector3(0, 0, -1.4 + vy), dt * 10.0)
		arms[1].rotation = arms[1].rotation.lerp(Vector3(0, 0, 1.4 - vy), dt * 10.0)
		body_root.position.y = -0.5
	# scarf streams with speed
	var flap := sin(Time.get_ticks_msec() * 0.02) * 0.25
	for i in scarf.size():
		var droop := lerpf(1.1, 0.15, clampf(spd / 20.0, 0, 1))
		scarf[i].rotation = Vector3(droop * (0.9 if i == 0 else 0.3) + flap * 0.3 * i, flap * 0.25 * i, 0)

func _update_trail(spd: float) -> void:
	var active := spd > 26.0 or p.state == Player.St.HOMING or p.boosting
	var pos := p.get_global_transform_interpolated().origin
	if active:
		trail_pts.push_front(pos)
	elif trail_pts.size() > 0:
		trail_pts.pop_back()
	while trail_pts.size() > 18:
		trail_pts.pop_back()
	trail_mesh.clear_surfaces()
	if trail_pts.size() < 3:
		return
	var col := Color(0.4, 1.0, 0.95) if p.boosting else Color(0.2, 0.8, 0.9)
	trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := trail_pts.size()
	for i in n:
		var t := float(i) / (n - 1)
		var w := 0.4 * (1.0 - t)
		var c := Color(col.r, col.g, col.b, 0.55 * (1.0 - t))
		trail_mesh.surface_set_color(c)
		trail_mesh.surface_add_vertex(trail_pts[i] + Vector3(0, w, 0))
		trail_mesh.surface_set_color(c)
		trail_mesh.surface_add_vertex(trail_pts[i] - Vector3(0, w, 0))
	trail_mesh.surface_end()
