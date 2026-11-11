class_name Breakable
extends StaticBody3D
## Cracked wall: only a Spin Dash roll or a boost at speed smashes it.

var size := Vector3(6, 6, 1.5)

static func make(parent: Node, pos: Vector3, yaw: float, sz: Vector3 = Vector3(6, 6, 1.5)) -> Breakable:
	var b := Breakable.new()
	b.size = sz
	b.position = pos
	b.rotation.y = yaw
	parent.add_child(b)
	return b

func _ready() -> void:
	add_to_group("breakable")
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)
	var m := Build.mat(Color(0.62, 0.5, 0.4), 0.95)
	Build.box(self, Vector3.ZERO, size, m, Vector3.ZERO, false)
	var crack := Build.mat(Color(0.2, 0.15, 0.12), 1.0)
	for i in 5:
		Build.box(self, Vector3(randf_range(-0.35, 0.35) * size.x, randf_range(-0.35, 0.35) * size.y, 0), Vector3(size.x * 0.35, 0.12, size.z + 0.06), crack, Vector3(0, 0, randf_range(-1.2, 1.2)), false)

func smash() -> void:
	Sfx.play("break")
	Fx.burst(global_position, Color(0.62, 0.5, 0.4), 28, 14.0, 0.9, 0.3, 3.0)
	if Game.camera != null:
		Game.camera.shake(0.4)
	queue_free()
