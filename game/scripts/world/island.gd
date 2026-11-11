class_name Island
extends WorldBase
## Aurora Isle: the open world. This file owns terrain, sea, sky dressing,
## vegetation and the building helpers; IslandAreas places every landmark,
## challenge and enemy on top of it.

var T: Terrain
var rng := RandomNumberGenerator.new()
var m_stone := Build.mat(Color(0.76, 0.73, 0.66), 0.95)
var m_stone2 := Build.mat(Color(0.6, 0.6, 0.58), 0.95)
var m_dark := Build.mat(Color(0.33, 0.34, 0.42), 0.8)
var m_glow := Build.mat(Color(0.3, 0.95, 0.85), 0.4, 1.8)
var m_gold := Build.mat(Color(1.0, 0.78, 0.3), 0.4, 0.6)
var m_wood := Build.mat(Color(0.56, 0.4, 0.26), 0.9)
var m_grass := Build.mat(Color(0.4, 0.68, 0.3), 1.0)
var m_rock := Build.mat(Color(0.5, 0.46, 0.43), 1.0)
var keep_clear: Array = []      # [Vector2 centre, radius] zones without vegetation
var places: Array = []          # [name, Vector2 centre, radius]
var spring_checks: Array = []   # [Spring, landing point] for automated verification
var hoop_checks: Array = []
var refs := {}                   # named handles for tests / scripting
var _place := ""
var _place_t := 0.0

func _build() -> void:
	rng.seed = 20261111
	water_y = Terrain.WATER_Y
	T = Terrain.new()
	T.load_or_generate()
	add_child(T)
	T.build()
	var s := Terrain.START
	spawn_point = T.at(s.x, s.y, 0.5)
	spawn_yaw = 0.0
	_sea()
	_clouds()
	IslandAreas.build_all(self)
	_vegetation()
	if Game.has_flag("guardian_defeated"):
		celebrate(true)

func _environment() -> void:
	super._environment()
	env.fog_density = 0.0007

func _process(dt: float) -> void:
	# announce landmarks as the player reaches them
	_place_t -= dt
	if _place_t > 0.0 or player == null:
		return
	_place_t = 0.5
	var pp := Vector2(player.global_position.x, player.global_position.z)
	var here := ""
	for pl in places:
		if pp.distance_to(pl[1]) < pl[2]:
			here = pl[0]
			break
	if here != _place:
		_place = here
		if here != "":
			Game.say(here, 2.5)

# ------------------------------------------------------------ helpers

func g(x: float, z: float, up: float = 0.0) -> Vector3:
	return T.at(x, z, up)

func ground_y(x: float, z: float) -> float:
	return T.h(x, z)

func clear_zone(c: Vector2, r: float) -> void:
	keep_clear.append([c, r])

func place_name(title: String, c: Vector2, r: float) -> void:
	places.append([title, c, r])

func spark_trail(a: Vector2, b: Vector2, n: int, up: float = 1.1) -> void:
	for i in n:
		var p := a.lerp(b, float(i) / maxf(1.0, n - 1.0))
		sparks.add(g(p.x, p.y, up))

func spark_ring_arc(c: Vector2, r: float, a0: float, a1: float, n: int) -> void:
	for i in n:
		var a := lerpf(a0, a1, float(i) / maxf(1.0, n - 1.0))
		sparks.add(g(c.x + cos(a) * r, c.y + sin(a) * r, 1.1))

## Spring at `from` that lands the player at `to` after `t` seconds.
func spring_to(from: Vector3, to: Vector3, t: float) -> Spring:
	var up := Vector3.UP
	var v := Vector3.ZERO
	for i in 3:
		var s := from + up * 1.2
		var d := to - s
		v = Vector3(d.x / t, (d.y + 0.5 * Player.GRAVITY * t * t) / t + 0.5 * Player.GRAVITY / 60.0, d.z / t)
		up = v.normalized()
	var sp := Spring.new()
	sp.power = v.length()
	sp.lock = maxf(0.3, t - 0.12)
	sp.position = from
	sp.basis = Basis(Quaternion(Vector3.UP, up))
	add_child(sp)
	spring_checks.append([sp, to])
	return sp

## Hoop at `pos` aimed so the player arrives at `to`.
func hoop_to(pos: Vector3, to: Vector3, spd: float = 48.0) -> Hoop:
	var flat := Vector3(to.x - pos.x, 0, to.z - pos.z)
	var dist := flat.length()
	var hd := flat / dist
	var dy := to.y - pos.y
	var lo := -0.6
	var hi := 1.0
	for i in 24:
		var th := (lo + hi) * 0.5
		var x1 := spd * cos(th) * 0.32
		var tb := maxf(0.0, (dist - x1) / (spd * cos(th)))
		var y := spd * sin(th) * (0.32 + tb) - 0.5 * Player.GRAVITY * tb * tb
		if y < dy:
			lo = th
		else:
			hi = th
	var th2 := (lo + hi) * 0.5
	var hp := Hoop.make(self, pos, hd * cos(th2) + Vector3.UP * sin(th2), spd)
	hoop_checks.append([hp, to])
	return hp

## After the Guardian falls the island settles into a golden evening.
func celebrate(instant: bool = false) -> void:
	var sm: ProceduralSkyMaterial = env.sky.sky_material
	var tw := create_tween().set_parallel(true)
	var d := 0.01 if instant else 4.0
	tw.tween_property(sm, "sky_top_color", Color(0.22, 0.25, 0.6), d)
	tw.tween_property(sm, "sky_horizon_color", Color(1.0, 0.72, 0.5), d)
	tw.tween_property(sm, "ground_horizon_color", Color(1.0, 0.72, 0.5), d)
	tw.tween_property(sun, "light_color", Color(1.0, 0.8, 0.6), d)
	tw.tween_property(sun, "rotation", Vector3(deg_to_rad(-24), deg_to_rad(-60), 0), d)
	tw.tween_property(env, "fog_light_color", Color(1.0, 0.78, 0.62), d)

func pillar(x: float, z: float, height: float, radius: float = 1.6, broken: bool = false) -> Vector3:
	var base := g(x, z)
	Build.cyl(self, base + Vector3(0, 0.4, 0), radius * 1.35, 1.4, m_stone2, true, -1.0, 8)
	Build.cyl(self, base + Vector3(0, height * 0.5, 0), radius, height, m_stone, true, radius * 0.88, 10)
	if not broken:
		Build.cyl(self, base + Vector3(0, height + 0.35, 0), radius * 1.4, 0.7, m_stone2, true, -1.0, 8)
		return base + Vector3(0, height + 0.7, 0)
	return base + Vector3(0, height, 0)

func arch(x: float, z: float, yaw: float, width: float, height: float, thick: float = 2.2) -> Node3D:
	var root := Node3D.new()
	root.position = g(x, z)
	root.rotation.y = yaw
	add_child(root)
	for sx in [-1.0, 1.0]:
		Build.box(root, Vector3(sx * (width * 0.5 + thick * 0.5), height * 0.5 - 1.0, 0), Vector3(thick, height + 2.0, thick), m_stone)
	Build.box(root, Vector3(0, height + thick * 0.5, 0), Vector3(width + thick * 3.0, thick, thick * 1.2), m_stone2)
	Build.box(root, Vector3(0, height + thick * 0.5, 0), Vector3(width * 0.6, thick * 0.3, thick * 1.25), m_glow, Vector3.ZERO, false)
	return root

## Floating rock with a flat grassy top at `top` height.
func sky_island(c: Vector3, radius: float, m_top: Material = null) -> void:
	Build.cyl(self, c - Vector3(0, 0.6, 0), radius, 1.2, m_top if m_top != null else m_grass, true, -1.0, 14)
	Build.cyl(self, c - Vector3(0, 1.2 + radius * 0.6, 0), radius * 0.15, radius * 1.2, m_rock, false, radius * 0.96, 9)
	Build.cyl(self, c - Vector3(0, 1.25, 0), radius * 1.04, 0.3, m_stone2, false, -1.0, 14)

func hint(pos: Vector3, radius: float, text: String, secs: float = 5.0) -> void:
	var t := Trigger.new()
	t.position = pos
	add_child(t)
	t.setup_sphere(radius)
	var shown := [false]
	t.body_entered.connect(func(b):
		if b is Player and not shown[0]:
			shown[0] = true
			Game.say(text, secs))

func beacon_light(pos: Vector3, color: Color, height: float = 60.0) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := Build.cyl(self, pos + Vector3(0, height * 0.5, 0), 0.9, height, m, false, 0.25, 8) as MeshInstance3D
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# ------------------------------------------------------------ scenery

func _sea() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	pm.subdivide_width = 1
	pm.subdivide_depth = 1
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz * 0.06;
	float n = noise(p + TIME * 0.25) * 0.6 + noise(p * 2.3 - TIME * 0.35) * 0.4;
	float d = length(wp.xz);
	float shallow = smoothstep(640.0, 470.0, d);
	vec3 deep = vec3(0.05, 0.3, 0.55);
	vec3 teal = vec3(0.1, 0.62, 0.68);
	vec3 col = mix(deep, teal, shallow * 0.8);
	col += vec3(0.25) * smoothstep(0.72, 0.9, n) * (0.3 + shallow);
	ALBEDO = col;
	ROUGHNESS = 0.18;
	SPECULAR = 0.6;
	ALPHA = 0.9;
	NORMAL_MAP = vec3(0.5 + (n - 0.5) * 0.25, 0.5 + (noise(p.yx * 1.7 + TIME * 0.3) - 0.5) * 0.25, 1.0);
}
"""
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = sm
	mi.position.y = water_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _clouds() -> void:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 8
	sm.rings = 4
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(1, 1, 1, 0.92)
	cm.disable_fog = true
	sm.material = cm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	var blobs: Array[Transform3D] = []
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(350.0, 1500.0)
		var c := Vector3(cos(a) * r, rng.randf_range(260.0, 420.0), sin(a) * r)
		var sz := rng.randf_range(40.0, 90.0)
		for k in rng.randi_range(3, 6):
			var off := Vector3(rng.randf_range(-1.0, 1.0) * sz, rng.randf_range(-0.08, 0.1) * sz, rng.randf_range(-0.5, 0.5) * sz)
			var s := sz * rng.randf_range(0.4, 0.8)
			blobs.append(Transform3D(Basis().scaled(Vector3(s, s * 0.32, s * 0.7)), c + off))
	mm.instance_count = blobs.size()
	for i in blobs.size():
		mm.set_instance_transform(i, blobs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _blocked(p: Vector2) -> bool:
	for kz in keep_clear:
		if p.distance_to(kz[0]) < kz[1]:
			return true
	return absf(p.distance_to(Terrain.TRACK_C) - Terrain.TRACK_R) < 11.0

func _multi(mesh: Mesh, xforms: Array, shadows: bool, colors: Array = []) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 520.0 if shadows else 190.0
	add_child(mi)

## Vegetation follows the land: groves where noise says so, palms on the
## beaches, boulders on steep rock, flowers on open meadow. Split into grid
## cells so distant cells can be culled.
func _vegetation() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.4
	trunk.height = 3.2
	trunk.radial_segments = 6
	trunk.rings = 1
	trunk.material = Build.mat(Color(0.45, 0.32, 0.22), 1.0)
	var crown := SphereMesh.new()
	crown.radius = 2.4
	crown.height = 4.6
	crown.radial_segments = 7
	crown.rings = 4
	var crown_m := StandardMaterial3D.new()
	crown_m.vertex_color_use_as_albedo = true
	crown_m.roughness = 1.0
	crown.material = crown_m
	var pine := CylinderMesh.new()
	pine.top_radius = 0.0
	pine.bottom_radius = 2.0
	pine.height = 6.5
	pine.radial_segments = 7
	pine.rings = 1
	pine.material = crown_m
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 1.5
	rock.radial_segments = 6
	rock.rings = 3
	rock.material = m_rock
	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.28
	tuft.height = 0.7
	tuft.radial_segments = 4
	tuft.rings = 1
	var tuft_m := StandardMaterial3D.new()
	tuft_m.vertex_color_use_as_albedo = true
	tuft_m.roughness = 1.0
	tuft.material = tuft_m

	var grove := FastNoiseLite.new()
	grove.seed = 77
	grove.frequency = 0.006
	var cell := 256.0
	for cz in 5:
		for cx in 5:
			var x0 := -640.0 + cx * cell
			var z0 := -640.0 + cz * cell
			var trunks: Array = []
			var crowns: Array = []
			var crown_c: Array = []
			var pines: Array = []
			var pine_c: Array = []
			var rocks: Array = []
			var tufts: Array = []
			var tuft_c: Array = []
			for i in 620:
				var x := x0 + rng.randf() * cell
				var z := z0 + rng.randf() * cell
				var y := T.h(x, z)
				if y < 1.0:
					continue
				var p := Vector2(x, z)
				var n := T.normal(x, z)
				var kind := rng.randf()
				if n.y < 0.8:
					if kind < 0.25 and not _blocked(p):
						var s := rng.randf_range(1.0, 3.6)
						rocks.append(Transform3D(Basis.from_euler(Vector3(rng.randf() * 3.0, rng.randf() * 6.0, 0)).scaled(Vector3(s, s * 0.8, s)), Vector3(x, y, z)))
					continue
				if _blocked(p):
					continue
				var gv := grove.get_noise_2d(x, z)
				if y < 5.5:
					# palms dot the beaches
					if kind < 0.06:
						var s := rng.randf_range(1.0, 1.5)
						trunks.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))).scaled(Vector3(0.7, s * 1.7, 0.7)), Vector3(x, y + 2.6 * s, z)))
						crowns.append(Transform3D(Basis().scaled(Vector3(1.3, 0.3, 1.3) * s), Vector3(x, y + 5.4 * s, z)))
						crown_c.append(Color(0.3, 0.62, 0.25))
				elif y > 62.0:
					# pines on the mountain's lower slopes
					if kind < 0.3 and y < 105.0 and gv > -0.25:
						var s := rng.randf_range(0.9, 1.7)
						pines.append(Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(x, y + 3.6 * s, z)))
						pine_c.append(Color(0.16, 0.4, 0.26).lerp(Color(0.24, 0.5, 0.3), rng.randf()))
						trunks.append(Transform3D(Basis().scaled(Vector3(0.6, 0.5, 0.6) * s), Vector3(x, y + 0.6 * s, z)))
				elif gv > 0.22:
					if kind < 0.42:
						var s := rng.randf_range(0.9, 1.6)
						trunks.append(Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(x, y + 1.5 * s, z)))
						crowns.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * 6.0, 0)).scaled(Vector3(s, s * rng.randf_range(0.8, 1.1), s)), Vector3(x, y + 4.6 * s, z)))
						crown_c.append(Color(0.22, 0.52, 0.22).lerp(Color(0.42, 0.66, 0.24), rng.randf()))
				elif kind < 0.5:
					# meadow flowers and grass tufts in loose drifts
					var drift := grove.get_noise_2d(x * 4.0 + 500.0, z * 4.0)
					if drift > 0.05:
						for k in 8:
							var fx := x + rng.randf_range(-4.0, 4.0)
							var fz := z + rng.randf_range(-4.0, 4.0)
							var s := rng.randf_range(0.5, 1.0)
							tufts.append(Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(fx, T.h(fx, fz) + 0.3 * s, fz)))
							var flower := rng.randf() < 0.35
							tuft_c.append([Color(1.0, 0.85, 0.3), Color(1.0, 0.5, 0.6), Color(0.9, 0.9, 1.0)][rng.randi() % 3] if flower else Color(0.3, 0.6, 0.22))
				elif kind > 0.985:
					var s := rng.randf_range(0.8, 2.2)
					rocks.append(Transform3D(Basis.from_euler(Vector3(rng.randf(), rng.randf() * 6.0, 0)).scaled(Vector3(s, s * 0.7, s)), Vector3(x, y + 0.1, z)))
			_multi(trunk, trunks, true)
			_multi(crown, crowns, true, crown_c)
			_multi(pine, pines, true, pine_c)
			_multi(rock, rocks, true)
			_multi(tuft, tufts, false, tuft_c)
