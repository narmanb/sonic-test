class_name Checkpoint
extends Trigger

var id := ""
var lamp: MeshInstance3D
var lit := false

static func make(parent: Node, pos: Vector3, cid: String) -> Checkpoint:
	var c := Checkpoint.new()
	c.id = cid
	c.position = pos
	parent.add_child(c)
	return c

func _ready() -> void:
	setup_box(Vector3(5, 5, 5), Vector3(0, 2.5, 0))
	var m := Build.mat(Color(0.75, 0.78, 0.85), 0.4)
	for sx in [-1.0, 1.0]:
		Build.cyl(self, Vector3(2.2 * sx, 1.5, 0), 0.14, 3.0, m, false)
	var s := SphereMesh.new()
	s.radius = 0.35
	s.height = 0.7
	s.radial_segments = 10
	s.rings = 5
	lamp = MeshInstance3D.new()
	lamp.mesh = s
	lamp.position = Vector3(0, 3.2, 0)
	add_child(lamp)
	Build.box(self, Vector3(0, 3.0, 0), Vector3(4.6, 0.12, 0.12), m, Vector3.ZERO, false)
	_set_lit(Game.checkpoint_id == id and Game.has_checkpoint)

func _set_lit(v: bool) -> void:
	lit = v
	lamp.material_override = Build.mat(Color(0.3, 1.0, 0.6), 0.3, 2.5) if v else Build.mat(Color(1.0, 0.35, 0.3), 0.3, 1.0)

func _touch(_p: Player) -> void:
	if lit:
		return
	get_tree().call_group("checkpoints", "_set_lit", false)
	add_to_group("checkpoints")
	_set_lit(true)
	Game.set_checkpoint(id, global_position + Vector3(0, 0.6, 0))
	Sfx.play("check")
	Fx.burst(lamp.global_position, Color(0.4, 1.0, 0.7), 12, 5.0, 0.6)
