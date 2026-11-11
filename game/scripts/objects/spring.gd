class_name Spring
extends Trigger
## Launches the player along its local +Y. Also a homing-attack target, so
## springs can be chained from the air.

var power := 30.0
var lock := 0.35
var homing_enabled := true
var pad: Node3D

static func make(parent: Node, pos: Vector3, pwr: float = 30.0, tilt: Vector3 = Vector3.ZERO, lock_time: float = -1.0) -> Spring:
	var s := Spring.new()
	s.power = pwr
	s.position = pos
	s.rotation = tilt
	s.lock = lock_time if lock_time >= 0.0 else (0.3 if tilt == Vector3.ZERO else 0.75)
	parent.add_child(s)
	return s

func _ready() -> void:
	setup_sphere(1.15, Vector3(0, 0.5, 0))
	add_to_group("homing")
	Build.cyl(self, Vector3(0, 0.12, 0), 0.75, 0.24, Build.mat(Color(0.25, 0.27, 0.33), 0.5), false)
	Build.cyl(self, Vector3(0, 0.35, 0), 0.3, 0.3, Build.mat(Color(0.8, 0.8, 0.85), 0.3), false)
	pad = Build.cyl(self, Vector3(0, 0.56, 0), 0.9, 0.16, Build.mat(Color(1.0, 0.25, 0.2), 0.4, 0.4), false)
	Build.cyl(self, Vector3(0, 0.65, 0), 0.45, 0.04, Build.mat(Color(1.0, 0.9, 0.3), 0.4, 0.8), false)

func homing_point() -> Vector3:
	return global_position + global_basis.y * 0.7

func homing_hit(p: Player) -> void:
	_touch(p)

func _touch(p: Player) -> void:
	var up := global_basis.y.normalized()
	p.global_position = global_position + up * 1.2
	p.launch(up * power, lock)
	p.ignore_target = self
	p.ignore_t = 1.0
	Sfx.play("spring")
	pad.position.y = 0.95
	var tw := create_tween()
	tw.tween_property(pad, "position:y", 0.56, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
