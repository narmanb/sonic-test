class_name Rail
extends Node3D
## Grind rail defined by a smooth curve through control points.

var curve := Curve3D.new()
var length := 0.0
var world_aabb := AABB()

static func make(parent: Node, points: Array, color: Color = Color(1.0, 0.75, 0.2), posts: bool = false) -> Rail:
	var r := Rail.new()
	parent.add_child(r)
	r.build(points, color, posts)
	return r

func build(points: Array, color: Color, posts: bool) -> void:
	add_to_group("rails")
	var n := points.size()
	for i in n:
		var p: Vector3 = points[i]
		var prev: Vector3 = points[maxi(i - 1, 0)]
		var next: Vector3 = points[mini(i + 1, n - 1)]
		var tan := (next - prev) / 6.0
		curve.add_point(p, -tan, tan)
	curve.bake_interval = 1.0
	length = curve.get_baked_length()
	var baked := curve.get_baked_points()
	var a := AABB(to_global(baked[0]), Vector3.ZERO)
	for b in baked:
		a = a.expand(to_global(b))
	world_aabb = a.grow(2.5)
	_mesh(baked, color)
	if posts:
		var pm := Build.mat(Color(0.35, 0.37, 0.42), 0.6)
		var step := maxi(1, int(18.0 / curve.bake_interval))
		var space := get_world_3d().direct_space_state
		for i in range(0, baked.size(), step):
			var q := PhysicsRayQueryParameters3D.create(to_global(baked[i]), to_global(baked[i]) + Vector3(0, -60, 0), 1)
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				var h: float = baked[i].y - to_local(hit.position).y
				if h > 0.6:
					Build.cyl(self, baked[i] - Vector3(0, h * 0.5 + 0.1, 0), 0.12, h, pm, false, -1.0, 6)

func _mesh(baked: PackedVector3Array, color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 5
	var rad := 0.16
	var rings: Array = []
	for i in baked.size():
		var p := baked[i]
		var t := (baked[mini(i + 1, baked.size() - 1)] - baked[maxi(i - 1, 0)]).normalized()
		var side := t.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized()
		var up := side.cross(t).normalized()
		var ring: Array = []
		for s in sides:
			var ang := TAU * s / sides
			ring.append(p + (side * cos(ang) + up * sin(ang)) * rad)
		rings.append(ring)
	for i in rings.size() - 1:
		for s in sides:
			var s2 := (s + 1) % sides
			var a: Vector3 = rings[i][s]
			var b: Vector3 = rings[i][s2]
			var c: Vector3 = rings[i + 1][s2]
			var d: Vector3 = rings[i + 1][s]
			var out := (a + c) * 0.5 - (baked[i] + baked[i + 1]) * 0.5
			var v := PackedVector3Array()
			Build.tri(v, a, b, c, out)
			Build.tri(v, a, c, d, out)
			for k in v:
				st.set_normal(out.normalized())
				st.add_vertex(k)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Build.mat(color, 0.25, 0.9)
	add_child(mi)

func closest(world_pos: Vector3) -> Dictionary:
	var off := curve.get_closest_offset(to_local(world_pos))
	var pt := to_global(curve.sample_baked(off, true))
	return {"offset": off, "point": pt, "dist": pt.distance_to(world_pos)}

func sample(off: float) -> Vector3:
	return to_global(curve.sample_baked(clampf(off, 0.0, length), true))

func tangent(off: float) -> Vector3:
	var a := curve.sample_baked(clampf(off - 0.6, 0.0, length), true)
	var b := curve.sample_baked(clampf(off + 0.6, 0.0, length), true)
	var t := b - a
	return t.normalized() if t.length() > 0.001 else Vector3.FORWARD
