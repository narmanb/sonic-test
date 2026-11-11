class_name DashPad
extends Trigger
## Ground pad that fires the player along its local -Z at a set speed.

var pad_speed := 55.0

static func make(parent: Node, pos: Vector3, yaw: float, spd: float = 55.0, pitch: float = 0.0) -> DashPad:
	var d := DashPad.new()
	d.pad_speed = spd
	d.position = pos
	d.rotation = Vector3(pitch, yaw, 0)
	parent.add_child(d)
	return d

func _ready() -> void:
	setup_box(Vector3(3.0, 1.6, 3.4), Vector3(0, 0.7, 0))
	Build.box(self, Vector3(0, 0.06, 0), Vector3(3.0, 0.12, 3.4), Build.mat(Color(0.16, 0.18, 0.24), 0.5), Vector3.ZERO, false)
	var m := Build.mat(Color(0.3, 1.0, 0.9), 0.4, 1.6)
	for i in 3:
		var z := 1.0 - i * 1.0
		Build.box(self, Vector3(-0.45, 0.14, z), Vector3(1.2, 0.05, 0.28), m, Vector3(0, -0.7, 0), false)
		Build.box(self, Vector3(0.45, 0.14, z), Vector3(1.2, 0.05, 0.28), m, Vector3(0, 0.7, 0), false)

func _touch(p: Player) -> void:
	p.dash(-global_basis.z, pad_speed)
	p.add_boost(10.0)
	Sfx.play("pad")
