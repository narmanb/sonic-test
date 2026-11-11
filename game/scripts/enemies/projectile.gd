class_name Projectile
extends Node3D
## Slow, readable energy shot. Curled / attacking players swat it away.

var vel := Vector3.ZERO
var life := 3.5

static func fire(from: Vector3, v: Vector3, color: Color = Color(1.0, 0.4, 0.9)) -> void:
	var w = Game.world
	if w == null:
		return
	var pr := Projectile.new()
	pr.vel = v
	w.add_child(pr)
	pr.global_position = from
	var s := SphereMesh.new()
	s.radius = 0.55
	s.height = 1.1
	s.radial_segments = 8
	s.rings = 4
	Build.visual(pr, s, Build.mat(color, 0.3, 3.0), Vector3.ZERO)
	pr.reset_physics_interpolation()

func _physics_process(dt: float) -> void:
	life -= dt
	position += vel * dt
	var p = Game.player
	var w = Game.world
	var dead := life <= 0.0
	if w != null and w.has_method("ground_y") and position.y < w.ground_y(position.x, position.z):
		dead = true
	if p != null and is_instance_valid(p) and p.state != Player.St.DEAD and position.distance_to(p.global_position) < 1.15:
		if p.ball or p.state == Player.St.HOMING or p.rolling:
			Sfx.play("hit", 1.6, -6.0)
		else:
			p.hurt(position - vel.normalized())
		dead = true
	if dead:
		Fx.burst(global_position, Color(1.0, 0.5, 0.9), 6, 4.0, 0.3)
		queue_free()
