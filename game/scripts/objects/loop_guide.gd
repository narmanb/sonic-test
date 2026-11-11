class_name LoopGuide
extends Node3D
## Keeps the player centred on a corkscrewed loop: as they travel round it the
## track shifts sideways, so the guide slides them across with it.

var radius := 10.0
var shift := 8.0
var width := 7.0

static func make(parent: Node, pos: Vector3, yaw: float, r: float, w: float, s: float) -> LoopGuide:
	var g := LoopGuide.new()
	g.position = pos
	g.rotation.y = yaw
	g.radius = r
	g.shift = s
	g.width = w
	parent.add_child(g)
	return g

func _physics_process(dt: float) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p) or p.state != Player.St.GROUND:
		return
	var l := to_local(p.global_position)
	if l.y < 1.2 or l.y > radius * 2.0 + 1.0 or absf(l.z) > radius + 1.0:
		return
	if l.x < -width or l.x > shift + width:
		return
	var a := atan2(-l.z, radius - l.y)
	if a < 0.0:
		a += TAU
	var want := shift * smoothstep(0.08, 0.92, a / TAU)
	var dx := (want - l.x) * minf(1.0, 12.0 * dt)
	p.move_and_collide(global_basis.x * dx)
