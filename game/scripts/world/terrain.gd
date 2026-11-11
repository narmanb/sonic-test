class_name Terrain
extends Node3D
## The island's ground. A designed height function (landmarks placed by hand,
## noise only for natural variation) is baked to res://data/island_height.bin
## by tools/bake_terrain.gd; at runtime the grid drives the collision
## heightmap, the chunked LOD meshes and object placement.

const N := 513                 # samples per side
const CELL := 2.5
const HALF := 640.0
const CHUNK := 32              # cells per chunk side
const DATA_PATH := "res://data/island_height.bin"
const WATER_Y := 0.0

# --- landmark anchors (x, z); north is -Z, east is +X
const SPIRE := Vector2(0, -20)
const PEAK := Vector2(60, -320)
const RUINS := Vector2(330, 30)
const BASIN := Vector2(-285, -285)
const COVE := Vector2(-300, 330)
const START := Vector2(0, 415)
const ISLET := Vector2(590, 40)
const STACK := Vector2(330, 470)
const LOOPSITE := Vector2(0, 238)
const TRACK_C := Vector2(0, 40)
const TRACK_R := 195.0

var H := PackedFloat32Array()
var n_low := FastNoiseLite.new()
var n_mid := FastNoiseLite.new()
var n_ridge := FastNoiseLite.new()

func _init() -> void:
	n_low.seed = 11
	n_low.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n_low.frequency = 0.0042
	n_low.fractal_octaves = 2
	n_mid.seed = 23
	n_mid.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n_mid.frequency = 0.014
	n_mid.fractal_octaves = 2
	n_ridge.seed = 5
	n_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n_ridge.frequency = 0.011
	n_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n_ridge.fractal_octaves = 3

# ------------------------------------------------------------ height design

static func _flat(h: float, d: float, r_in: float, r_out: float, target: float) -> float:
	return lerpf(h, target, smoothstep(r_out, r_in, d))

func coast_radius(ang: float) -> float:
	return 505.0 + 40.0 * n_low.get_noise_2d(cos(ang) * 260.0, sin(ang) * 260.0) + 22.0 * sin(ang * 3.0 + 1.0)

## The authored height at any point (slow; used only while baking).
func design_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var r := p.length()
	var ang := atan2(z, x)
	var d := coast_radius(ang) - r                 # metres inland from the shore
	var lo := n_low.get_noise_2d(x, z)
	var mid := n_mid.get_noise_2d(x, z)

	# rolling plains
	var h := 15.0 + 7.5 * lo + 1.6 * mid + 9.0 * maxf(0.0, n_low.get_noise_2d(x + 900.0, z - 400.0))

	# central hill crowned by the Spire
	var ds := p.distance_to(SPIRE)
	h += 17.0 * smoothstep(95.0, 22.0, ds)
	h = _flat(h, ds, 15.0, 30.0, 33.0)

	# Windcut Cliffs: western plateau
	var west := smoothstep(-235.0, -320.0, x) * smoothstep(270.0, 200.0, absf(z))
	h = lerpf(h, 58.0 + 3.0 * mid + 4.0 * lo, west)

	# Stormcrown Peak
	var dm := p.distance_to(PEAK)
	var m := maxf(0.0, 1.0 - dm / 215.0)
	h += 150.0 * pow(m, 1.55) * (0.82 + 0.3 * n_ridge.get_noise_2d(x, z) * smoothstep(0.0, 0.5, 1.0 - m))
	h = _flat(h, dm, 15.0, 30.0, 140.0)

	# Sunken Ruins: a wide stone-floored hollow
	h = _flat(h, p.distance_to(RUINS), 95.0, 150.0, 8.0)

	# Guardian's Basin: flat crater ringed by a broken rim
	var db := p.distance_to(BASIN)
	h = _flat(h, db, 64.0, 88.0, 24.0)
	var open := (p - BASIN).normalized().dot(Vector2(0.7071, 0.7071))   # gap faces the plains
	h += 11.0 * smoothstep(60.0, 76.0, db) * smoothstep(112.0, 86.0, db) * smoothstep(0.93, 0.8, open)

	# Hollow Pass: a ridge walls off the south-west cove, split by one canyon
	var dc := p.distance_to(COVE)
	var to_c := (p - COVE)
	var pass_dir := Vector2(0.7071, -0.7071)
	var lateral := absf(to_c.x * pass_dir.y - to_c.y * pass_dir.x)
	var along := to_c.dot(pass_dir)
	var ridge := smoothstep(70.0, 96.0, dc) * smoothstep(136.0, 106.0, dc)
	var canyon := 1.0 if along < 0.0 else smoothstep(5.5, 9.5, lateral)
	h += 36.0 * ridge * canyon * smoothstep(-30.0, 5.0, d)
	h = _flat(h, dc, 55.0, 80.0, 5.0)
	if along > 0.0:
		h = lerpf(lerpf(5.0, 14.0, smoothstep(60.0, 150.0, dc)), h, maxf(smoothstep(5.0, 9.5, lateral), smoothstep(150.0, 175.0, dc)))

	# level ground for the speedway's loop-the-loop
	h = _flat(h, p.distance_to(LOOPSITE), 34.0, 62.0, 15.0)

	# start beach
	h = _flat(h, p.distance_to(START), 28.0, 70.0, 4.5)

	# shoreline: sandy beaches everywhere except sheer cliffs in the west / north
	var cliffy := maxf(smoothstep(-200.0, -300.0, x) * smoothstep(300.0, 230.0, absf(z)), smoothstep(240.0, 150.0, dm))
	cliffy = maxf(cliffy, ridge)
	var beach_w := lerpf(85.0, 12.0, cliffy)
	var t := smoothstep(0.0, beach_w, d)
	h = lerpf(-1.2, h, pow(t, 1.3))
	if d < 0.0:
		h = maxf(-14.0, -1.2 + d * 0.16)

	# offshore: lantern islet (east) and the sea stack (south-east)
	var di := p.distance_to(ISLET)
	h = maxf(h, lerpf(-14.0, 9.0, smoothstep(46.0, 24.0, di)))
	var dk := p.distance_to(STACK)
	h = maxf(h, lerpf(-14.0, 34.0, smoothstep(26.0, 13.0, dk)))
	return h

func generate() -> void:
	H.resize(N * N)
	for j in N:
		var z := -HALF + j * CELL
		for i in N:
			H[j * N + i] = design_height(-HALF + i * CELL, z)

func load_or_generate() -> void:
	if FileAccess.file_exists(DATA_PATH):
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var bytes := f.get_buffer(f.get_length())
			if bytes.size() == N * N * 2:
				H.resize(N * N)
				for i in N * N:
					H[i] = bytes.decode_u16(i * 2) / 65535.0 * 220.0 - 20.0
				return
	generate()

func save_baked(path: String) -> void:
	var bytes := PackedByteArray()
	bytes.resize(N * N * 2)
	for i in N * N:
		bytes.encode_u16(i * 2, int(clampf((H[i] + 20.0) / 220.0, 0.0, 1.0) * 65535.0))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)

# ------------------------------------------------------------ queries

func h(x: float, z: float) -> float:
	var fx := clampf((x + HALF) / CELL, 0.0, N - 1.001)
	var fz := clampf((z + HALF) / CELL, 0.0, N - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := H[j * N + i]
	var b := H[j * N + i + 1]
	var c := H[(j + 1) * N + i]
	var e := H[(j + 1) * N + i + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, e, tx), tz)

## Point on the ground, lifted by `up`.
func at(x: float, z: float, up: float = 0.0) -> Vector3:
	return Vector3(x, h(x, z) + up, z)

func normal(x: float, z: float) -> Vector3:
	var e := CELL
	return Vector3(h(x - e, z) - h(x + e, z), 2.0 * e, h(x, z - e) - h(x, z + e)).normalized()

# ------------------------------------------------------------ construction

func build() -> void:
	_collision()
	_meshes()

func _collision() -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := HeightMapShape3D.new()
	sh.map_width = N
	sh.map_depth = N
	sh.map_data = H
	cs.shape = sh
	cs.scale = Vector3(CELL, 1.0, CELL)
	sb.add_child(cs)
	add_child(sb)

func _color(x: float, z: float, y: float, ny: float) -> Color:
	var mid := n_mid.get_noise_2d(x * 1.7, z * 1.7)
	var lo := n_low.get_noise_2d(x * 2.0 + 300.0, z * 2.0)
	var grass := Color(0.24, 0.55, 0.2).lerp(Color(0.42, 0.66, 0.22), 0.5 + 0.5 * lo)
	grass = grass.lerp(Color(0.2, 0.47, 0.24), clampf(mid * 1.5, 0.0, 1.0))
	var col := grass
	var p := Vector2(x, z)
	# plateau meadow is drier, the ruins hollow is mossy stone, the basin is slate
	col = col.lerp(Color(0.66, 0.72, 0.34), smoothstep(40.0, 56.0, y) * smoothstep(-230.0, -300.0, x) * 0.7)
	var dr := p.distance_to(RUINS)
	col = col.lerp(Color(0.62, 0.68, 0.6).lerp(Color(0.5, 0.62, 0.5), 0.5 + 0.5 * mid), smoothstep(140.0, 100.0, dr) * 0.85)
	var db := p.distance_to(BASIN)
	col = col.lerp(Color(0.36, 0.34, 0.46), smoothstep(92.0, 66.0, db))
	# the speedway: a worn path circling the plains
	var dt := absf(p.distance_to(TRACK_C) - TRACK_R)
	col = col.lerp(Color(0.66, 0.54, 0.36), smoothstep(7.0, 3.5, dt) * 0.85)
	# sand near sea level
	col = col.lerp(Color(0.86, 0.76, 0.52), smoothstep(5.6 + mid, 3.4 + mid, y))
	col = col.lerp(Color(0.8, 0.74, 0.55), smoothstep(0.6, -0.8, y))
	# rock on steep ground, pale stone and snow up high
	var rock := Color(0.52, 0.47, 0.43).lerp(Color(0.42, 0.4, 0.42), 0.5 + 0.5 * mid)
	col = col.lerp(rock, smoothstep(0.86, 0.7, ny))
	col = col.lerp(Color(0.6, 0.58, 0.6), smoothstep(80.0, 105.0, y) * 0.8)
	col = col.lerp(Color(0.96, 0.97, 1.0), smoothstep(112.0 + 6.0 * mid, 124.0 + 6.0 * mid, y) * smoothstep(0.55, 0.8, ny))
	return col

func _meshes() -> void:
	var tex := NoiseTexture2D.new()
	var tn := FastNoiseLite.new()
	tn.frequency = 0.03
	tn.fractal_octaves = 4
	tex.noise = tn
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.7, 0.7, 0.7))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	tex.color_ramp = ramp
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.roughness = 1.0
	mat.metallic_specular = 0.1
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	# shared per-vertex normals and colours
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	normals.resize(N * N)
	colors.resize(N * N)
	for j in N:
		var z := -HALF + j * CELL
		var j0 := maxi(j - 1, 0)
		var j1 := mini(j + 1, N - 1)
		for i in N:
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, N - 1)
			var nrm := Vector3(H[j * N + i0] - H[j * N + i1], 2.0 * CELL, H[j0 * N + i] - H[j1 * N + i]).normalized()
			normals[j * N + i] = nrm
			var y := H[j * N + i]
			colors[j * N + i] = _color(-HALF + i * CELL, z, y, nrm.y) if y > -6.0 else Color(0.6, 0.62, 0.5)

	var chunks := (N - 1) / CHUNK
	for cj in chunks:
		for ci in chunks:
			var top := -100.0
			for j in range(cj * CHUNK, (cj + 1) * CHUNK + 1, 4):
				for i in range(ci * CHUNK, (ci + 1) * CHUNK + 1, 4):
					top = maxf(top, H[j * N + i])
			if top < -3.0:
				continue
			var hi := _chunk_mesh(ci, cj, 1, normals, colors)
			var lo := _chunk_mesh(ci, cj, 4, normals, colors)
			var a := MeshInstance3D.new()
			a.mesh = hi
			a.material_override = mat
			a.visibility_range_end = 330.0
			a.visibility_range_end_margin = 20.0
			add_child(a)
			var b := MeshInstance3D.new()
			b.mesh = lo
			b.material_override = mat
			b.visibility_range_begin = 320.0
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(b)

func _chunk_mesh(ci: int, cj: int, step: int, normals: PackedVector3Array, colors: PackedColorArray) -> ArrayMesh:
	var side := CHUNK / step + 1
	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var cc := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	v.resize(side * side)
	nn.resize(side * side)
	cc.resize(side * side)
	uv.resize(side * side)
	var k := 0
	for b in side:
		var j := cj * CHUNK + b * step
		for a in side:
			var i := ci * CHUNK + a * step
			var s := j * N + i
			var x := -HALF + i * CELL
			var z := -HALF + j * CELL
			v[k] = Vector3(x, H[s], z)
			nn[k] = normals[s]
			cc[k] = colors[s]
			uv[k] = Vector2(x, z) * 0.045
			k += 1
	idx.resize((side - 1) * (side - 1) * 6)
	k = 0
	for b in side - 1:
		for a in side - 1:
			var p0 := b * side + a
			idx[k] = p0; idx[k + 1] = p0 + 1; idx[k + 2] = p0 + side
			idx[k + 3] = p0 + 1; idx[k + 4] = p0 + side + 1; idx[k + 5] = p0 + side
			k += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nn
	arr[Mesh.ARRAY_COLOR] = cc
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am
