class_name Orb
extends Node3D
## Floating lantern: a pure homing-attack stepping stone. Pops and regrows.

var homing_enabled := true
var body: Node3D
var bounce_power := 16.0

static func make(parent: Node, pos: Vector3, pwr: float = 16.0) -> Orb:
	var o := Orb.new()
	o.position = pos
	o.bounce_power = pwr
	parent.add_child(o)
	return o

func _ready() -> void:
	add_to_group("homing")
	add_to_group("respawn_listener")
	body = Node3D.new()
	add_child(body)
	var s := SphereMesh.new()
	s.radius = 0.7
	s.height = 1.4
	s.radial_segments = 12
	s.rings = 6
	Build.visual(body, s, Build.mat(Color(1.0, 0.55, 0.85), 0.3, 1.2), Vector3.ZERO)
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.3
	c.height = 0.6
	c.radial_segments = 6
	Build.visual(body, c, Build.mat(Color(1.0, 0.9, 0.5), 0.3, 1.0), Vector3(0, -0.85, 0), Vector3.ONE, Vector3(PI, 0, 0))

func _process(_dt: float) -> void:
	body.position.y = sin(Time.get_ticks_msec() * 0.003 + position.x) * 0.15

func homing_point() -> Vector3:
	return global_position

func homing_hit(p: Player) -> void:
	p.velocity.y = bounce_power
	p.add_boost(6.0)
	Sfx.play("hit", 1.5)
	homing_enabled = false
	body.visible = false
	get_tree().create_timer(2.5, false).timeout.connect(on_player_respawn)

func on_player_respawn() -> void:
	homing_enabled = true
	body.visible = true
