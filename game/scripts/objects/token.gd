class_name Token
extends Trigger
## Aurora Core: the island's main collectible.

var id := ""
var gem: Node3D

static func make(parent: Node, pos: Vector3, tid: String) -> Token:
	if Game.tokens.has(tid) and not (Game.world != null and Game.world.get("is_test")):
		return null
	var t := Token.new()
	t.id = tid
	t.position = pos
	parent.add_child(t)
	return t

func _ready() -> void:
	setup_sphere(1.6)
	gem = Node3D.new()
	add_child(gem)
	var s := SphereMesh.new()
	s.radius = 0.8
	s.height = 1.9
	s.radial_segments = 6
	s.rings = 2
	Build.visual(gem, s, Build.mat(Color(0.55, 0.4, 1.0), 0.15, 1.8), Vector3.ZERO)
	var t := TorusMesh.new()
	t.inner_radius = 1.05
	t.outer_radius = 1.2
	t.rings = 20
	t.ring_segments = 6
	Build.visual(gem, t, Build.mat(Color(0.5, 1.0, 0.9), 0.3, 2.0), Vector3.ZERO, Vector3.ONE, Vector3(0.5, 0, 0.3))
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.5, 1.0)
	l.omni_range = 9.0
	l.light_energy = 1.5
	add_child(l)

func _process(dt: float) -> void:
	gem.rotate_y(dt * 1.8)
	gem.position.y = sin(Time.get_ticks_msec() * 0.002) * 0.25

func _touch(p: Player) -> void:
	Game.collect_token(id)
	p.add_boost(100.0)
	Sfx.play("token")
	Fx.burst(global_position, Color(0.7, 0.55, 1.0), 24, 10.0, 0.9, 0.0, 1.5)
	Fx.ring_wave(global_position, Color(0.6, 1.0, 0.9, 0.9), 8.0, 0.6)
	queue_free()
