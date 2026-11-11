class_name Build
## Static helpers for constructing level geometry in code.

static var _mats := {}

static func mat(color: Color, rough: float = 0.9, emit: float = 0.0, alpha: bool = false) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), rough, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	if alpha or color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

static func box(parent: Node, pos: Vector3, size: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, collide: bool = true) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	if not collide:
		mi.position = pos
		mi.rotation = rot
		parent.add_child(mi)
		return mi
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation = rot
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.add_child(mi)
	parent.add_child(sb)
	return sb

static func cyl(parent: Node, pos: Vector3, radius: float, height: float, m: Material, collide: bool = true, top_radius: float = -1.0, sides: int = 12, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	if not collide:
		mi.position = pos
		mi.rotation = rot
		parent.add_child(mi)
		return mi
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation = rot
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = maxf(radius, cm.top_radius)
	sh.height = height
	cs.shape = sh
	sb.add_child(cs)
	sb.add_child(mi)
	parent.add_child(sb)
	return sb

static func visual(parent: Node, mesh: Mesh, m: Material, pos: Vector3, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	parent.add_child(mi)
	return mi

## Adds triangle a,b,c wound so its front face looks toward `toward`.
static func tri(v: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, toward: Vector3) -> void:
	if Plane(a, b, c).normal.dot(toward) >= 0.0:
		v.append(a); v.append(b); v.append(c)
	else:
		v.append(a); v.append(c); v.append(b)

## Builds a visible + collidable surface from a triangle soup (flat shaded).
static func surface(parent: Node, verts: PackedVector3Array, m: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in range(0, verts.size(), 3):
		var n := Plane(verts[i], verts[i + 1], verts[i + 2]).normal
		normals[i] = n; normals[i + 1] = n; normals[i + 2] = n
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = m
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.set_faces(verts)
	cs.shape = sh
	sb.add_child(cs)
	sb.add_child(mi)
	sb.position = pos
	sb.rotation = rot
	parent.add_child(sb)
	return sb

## Vertical loop-the-loop. Enters at local origin heading -Z, exits shifted by
## `shift` on X so entry and exit lanes do not intersect.
static func loop(parent: Node, pos: Vector3, yaw: float, radius: float, width: float, shift: float, m: Material) -> StaticBody3D:
	var v := PackedVector3Array()
	var segs := 44
	var hw := width * 0.5
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var a0 := t0 * TAU
		var a1 := t1 * TAU
		var x0 := shift * smoothstep(0.08, 0.92, t0)
		var x1 := shift * smoothstep(0.08, 0.92, t1)
		var p0 := Vector3(x0, radius - radius * cos(a0), -radius * sin(a0))
		var p1 := Vector3(x1, radius - radius * cos(a1), -radius * sin(a1))
		var c := Vector3((x0 + x1) * 0.5, radius, 0)
		var l0 := p0 + Vector3(-hw, 0, 0)
		var r0 := p0 + Vector3(hw, 0, 0)
		var l1 := p1 + Vector3(-hw, 0, 0)
		var r1 := p1 + Vector3(hw, 0, 0)
		var mid := (l0 + r1) * 0.5
		tri(v, l0, r0, r1, c - mid)
		tri(v, l0, r1, l1, c - mid)
		# outer skin so the loop reads as solid from outside
		var o := (mid - c).normalized() * 0.5
		o.x = 0
		tri(v, l0 + o, r0 + o, r1 + o, mid - c)
		tri(v, l0 + o, r1 + o, l1 + o, mid - c)
		tri(v, l0, l0 + o, l1 + o, Vector3.LEFT)
		tri(v, l0, l1 + o, l1, Vector3.LEFT)
		tri(v, r0, r0 + o, r1 + o, Vector3.RIGHT)
		tri(v, r0, r1 + o, r1, Vector3.RIGHT)
	return surface(parent, v, m, pos, Vector3(0, yaw, 0))

## Quarter pipe rising from flat ground (heading -Z) to vertical.
static func quarter_pipe(parent: Node, pos: Vector3, yaw: float, radius: float, width: float, m: Material, sweep: float = PI * 0.5) -> StaticBody3D:
	var v := PackedVector3Array()
	var segs := 14
	var hw := width * 0.5
	for i in segs:
		var a0 := float(i) / segs * sweep
		var a1 := float(i + 1) / segs * sweep
		var p0 := Vector3(0, radius - radius * cos(a0), -radius * sin(a0))
		var p1 := Vector3(0, radius - radius * cos(a1), -radius * sin(a1))
		var c := Vector3(0, radius, 0)
		tri(v, p0 + Vector3(-hw, 0, 0), p0 + Vector3(hw, 0, 0), p1 + Vector3(hw, 0, 0), c - p0)
		tri(v, p0 + Vector3(-hw, 0, 0), p1 + Vector3(hw, 0, 0), p1 + Vector3(-hw, 0, 0), c - p0)
	return surface(parent, v, m, pos, Vector3(0, yaw, 0))
