extends Node
## One-shot particle bursts and shared effect helpers.

var _mesh: Mesh
var _mats := {}

func _ready() -> void:
	var m := SphereMesh.new()
	m.radius = 0.12
	m.height = 0.24
	m.radial_segments = 6
	m.rings = 3
	_mesh = m

func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = color
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
		_mats[key] = mt
	return _mats[key]

func burst(pos: Vector3, color: Color, amount: int = 12, speed: float = 6.0, life: float = 0.5, up: float = 0.5, size: float = 1.0) -> void:
	var root: Node = Game.world
	if root == null or not is_instance_valid(root):
		return
	var p := CPUParticles3D.new()
	p.mesh = _mesh
	p.material_override = _mat(color)
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = lerpf(180.0, 40.0, clampf(up, 0.0, 1.0))
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.6 * size
	p.scale_amount_max = 1.4 * size
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	p.scale_amount_curve = c
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.add_child(p)
	p.global_position = pos
	get_tree().create_timer(life + 0.3, false).timeout.connect(p.queue_free)

func ring_wave(pos: Vector3, color: Color, radius: float = 5.0, time: float = 0.35) -> void:
	var root: Node = Game.world
	if root == null or not is_instance_valid(root):
		return
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	t.rings = 24
	t.ring_segments = 6
	mi.mesh = t
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = color
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mt
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.3, 0.3, 0.3)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.4, radius), time)
	tw.tween_property(mt, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(mi.queue_free)
