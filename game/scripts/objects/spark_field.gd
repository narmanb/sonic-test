class_name SparkField
extends Node3D
## All "sparks" (the basic pickup) in the world, drawn with one MultiMesh and
## collected with a spatial hash instead of hundreds of physics areas.

const CELL := 8.0
var pts: Array[Vector3] = []
var alive: PackedByteArray = PackedByteArray()
var grid := {}
var mm: MultiMesh
var chain := 0
var chain_t := 0.0

func add(p: Vector3) -> void:
	pts.append(p)

func add_line(a: Vector3, b: Vector3, n: int) -> void:
	for i in n:
		pts.append(a.lerp(b, float(i) / maxf(1.0, n - 1.0)))

func add_arc(a: Vector3, b: Vector3, height: float, n: int) -> void:
	for i in n:
		var t := float(i) / maxf(1.0, n - 1.0)
		pts.append(a.lerp(b, t) + Vector3(0, 4.0 * height * t * (1.0 - t), 0))

func add_circle(c: Vector3, r: float, n: int) -> void:
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector3(cos(a) * r, 0, sin(a) * r))

func build() -> void:
	alive.resize(pts.size())
	alive.fill(1)
	var mesh := SphereMesh.new()
	mesh.radius = 0.38
	mesh.height = 0.95
	mesh.radial_segments = 4
	mesh.rings = 1
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = """
shader_type spatial;
render_mode unshaded;
void vertex() {
	float a = TIME * 3.0 + INSTANCE_CUSTOM.x;
	float c = cos(a); float s = sin(a);
	VERTEX.xz = mat2(vec2(c, -s), vec2(s, c)) * VERTEX.xz;
	VERTEX.y += sin(TIME * 2.0 + INSTANCE_CUSTOM.x) * 0.12;
	NORMAL.xz = mat2(vec2(c, -s), vec2(s, c)) * NORMAL.xz;
}
void fragment() {
	float f = 0.55 + 0.45 * abs(NORMAL.x) + 0.3 * NORMAL.y;
	ALBEDO = vec3(1.0, 0.82, 0.18) * f + vec3(0.25) * pow(max(NORMAL.z, 0.0), 6.0);
}
"""
	mesh.material = sm
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis(), pts[i]))
		mm.set_instance_custom_data(i, Color(float(i % 17), 0, 0, 0))
		var key := _key(pts[i])
		if not grid.has(key):
			grid[key] = PackedInt32Array()
		grid[key].append(i)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-2000, -200, -2000), Vector3(4000, 800, 4000))
	add_child(mi)

func _key(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))

func _physics_process(dt: float) -> void:
	chain_t -= dt
	if chain_t <= 0.0:
		chain = 0
	var pl = Game.player
	if pl == null or not is_instance_valid(pl) or pl.state == Player.St.DEAD:
		return
	var pp: Vector3 = pl.global_position
	# sweep along this tick's motion so nothing is skipped at high speed
	var back: Vector3 = pp - pl.velocity * dt
	var k0 := _key(pp)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				var k := k0 + Vector3i(dx, dy, dz)
				if not grid.has(k):
					continue
				for i in grid[k]:
					if alive[i] == 0:
						continue
					var c := Geometry3D.get_closest_point_to_segment(pts[i], back, pp)
					if c.distance_squared_to(pts[i]) < 2.9:
						_collect(i, pl)

func _collect(i: int, pl: Player) -> void:
	alive[i] = 0
	mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), pts[i]))
	Game.add_sparks(1)
	pl.add_boost(2.5)
	chain = mini(chain + 1, 12)
	chain_t = 0.5
	Sfx.play("spark", 1.0 + chain * 0.04, -4.0)
	Fx.burst(pts[i], Color(1.0, 0.9, 0.4), 4, 3.0, 0.3, 0.0, 0.7)
