class_name PressSwitch
extends Node3D
## Floor switch. Pressed by a stomp nearby (or by rolling/stepping on it when
## `touch` is true).

signal pressed_changed(on: bool)

var on := false
var touch := false
var cap: Node3D
var hold_time := 0.0     # >0: switch pops back up after this many seconds
var _t := 0.0

static func make(parent: Node, pos: Vector3, by_touch: bool = false, hold: float = 0.0) -> PressSwitch:
	var s := PressSwitch.new()
	s.position = pos
	s.touch = by_touch
	s.hold_time = hold
	parent.add_child(s)
	return s

func _ready() -> void:
	add_to_group("stomp_listener")
	Build.cyl(self, Vector3(0, 0.1, 0), 1.5, 0.2, Build.mat(Color(0.3, 0.32, 0.38), 0.6), false)
	cap = Build.cyl(self, Vector3(0, 0.3, 0), 1.1, 0.3, Build.mat(Color(1.0, 0.35, 0.25), 0.4, 0.8), false)
	if touch:
		var t := Trigger.new()
		add_child(t)
		t.setup_sphere(1.4, Vector3(0, 0.5, 0))
		t.body_entered.connect(func(b): if b is Player: press())

func on_stomp(pos: Vector3, radius: float) -> void:
	if pos.distance_to(global_position) < radius:
		press()

func press() -> void:
	if on:
		return
	on = true
	_t = hold_time
	Sfx.play("switch")
	cap.position.y = 0.16
	(cap as MeshInstance3D).material_override = Build.mat(Color(0.3, 1.0, 0.5), 0.4, 1.5)
	pressed_changed.emit(true)

func release() -> void:
	if not on:
		return
	on = false
	cap.position.y = 0.3
	(cap as MeshInstance3D).material_override = Build.mat(Color(1.0, 0.35, 0.25), 0.4, 0.8)
	pressed_changed.emit(false)

func _process(dt: float) -> void:
	if on and hold_time > 0.0:
		_t -= dt
		if _t <= 0.0:
			release()
