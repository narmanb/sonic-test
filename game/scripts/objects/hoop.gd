class_name Hoop
extends Trigger
## Mid-air boost ring: re-centres the player and fires them along local -Z.

var hoop_speed := 48.0
var ring: MeshInstance3D

static func make(parent: Node, pos: Vector3, dir: Vector3, spd: float = 48.0) -> Hoop:
	var h := Hoop.new()
	h.hoop_speed = spd
	h.position = pos
	parent.add_child(h)
	var d := dir.normalized()
	var up := Vector3.UP if absf(d.y) < 0.95 else Vector3.FORWARD
	h.basis = Basis.looking_at(d, up)
	return h

func _ready() -> void:
	setup_sphere(2.3)
	var t := TorusMesh.new()
	t.inner_radius = 1.9
	t.outer_radius = 2.3
	t.rings = 24
	t.ring_segments = 8
	ring = Build.visual(self, t, Build.mat(Color(0.35, 0.85, 1.0), 0.3, 2.0), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0))
	var t2 := TorusMesh.new()
	t2.inner_radius = 1.45
	t2.outer_radius = 1.6
	t2.rings = 20
	t2.ring_segments = 6
	Build.visual(self, t2, Build.mat(Color(1.0, 0.8, 0.3), 0.3, 2.0), Vector3(0, 0, -0.5), Vector3.ONE, Vector3(PI / 2, 0, 0))

func _process(dt: float) -> void:
	ring.rotate_object_local(Vector3.UP, dt * 2.0)

func _touch(p: Player) -> void:
	var d := -global_basis.z.normalized()
	p.global_position = global_position
	p.launch(d * hoop_speed, 0.4, 0.32)
	p.add_boost(12.0)
	Sfx.play("pad", 1.3)
	Fx.ring_wave(global_position, Color(0.5, 0.9, 1.0, 0.8), 3.5, 0.3)
