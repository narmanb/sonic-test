class_name MovingPlatform
extends AnimatableBody3D
## Platform gliding between two points; carries the player.

var a := Vector3.ZERO
var b := Vector3.ZERO
var period := 5.0
var phase := 0.0
var active := true
var _vel := Vector3.ZERO
var _t := 0.0

static func make(parent: Node, from: Vector3, to: Vector3, size: Vector3, m: Material, secs: float = 5.0, ph: float = 0.0) -> MovingPlatform:
	var p := MovingPlatform.new()
	p.a = from
	p.b = to
	p.period = secs
	p.phase = ph
	p.position = from
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	p.add_child(cs)
	Build.box(p, Vector3.ZERO, size, m, Vector3.ZERO, false)
	Build.box(p, Vector3(0, size.y * 0.5 + 0.03, 0), Vector3(size.x * 0.8, 0.06, size.z * 0.8), Build.mat(Color(0.4, 0.9, 1.0), 0.4, 1.0), Vector3.ZERO, false)
	parent.add_child(p)
	return p

func _ready() -> void:
	sync_to_physics = false
	_t = phase * period

func _physics_process(dt: float) -> void:
	if not active:
		_vel = Vector3.ZERO
		return
	_t += dt
	var k := 0.5 - 0.5 * cos(_t / period * TAU)
	var np := a.lerp(b, k)
	_vel = (np - position) / dt
	position = np

func carry_velocity() -> Vector3:
	return _vel
