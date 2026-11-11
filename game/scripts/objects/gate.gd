class_name Gate
extends StaticBody3D
## Stone slab that sinks into the ground when opened.

var size := Vector3(6, 7, 1.2)
var opened := false

static func make(parent: Node, pos: Vector3, yaw: float, sz: Vector3, m: Material) -> Gate:
	var g := Gate.new()
	g.size = sz
	g.position = pos
	g.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = sz
	cs.shape = sh
	g.add_child(cs)
	Build.box(g, Vector3.ZERO, sz, m, Vector3.ZERO, false)
	Build.box(g, Vector3(0, sz.y * 0.2, 0), Vector3(sz.x * 0.5, 0.3, sz.z + 0.1), Build.mat(Color(0.5, 1.0, 0.9), 0.4, 1.5), Vector3.ZERO, false)
	parent.add_child(g)
	return g

func open(instant: bool = false) -> void:
	if opened:
		return
	opened = true
	var to := position - Vector3(0, size.y + 0.5, 0)
	if instant:
		position = to
		return
	Sfx.play("break", 0.6)
	var tw := create_tween()
	tw.tween_property(self, "position", to, 1.6).set_trans(Tween.TRANS_SINE)
