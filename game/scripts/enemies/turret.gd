class_name Turret
extends Enemy
## Ranged sentry: charges up visibly, then fires a dodgeable shot.

enum { IDLE, AIM, COOL }
var mode := IDLE
var t := 0.0
var core: MeshInstance3D
var shot_speed := 30.0
var sight := 48.0

static func make(parent: Node, pos: Vector3) -> Turret:
	var e := Turret.new()
	e.position = pos + Vector3(0, 2.2, 0)
	parent.add_child(e)
	return e

func _make() -> void:
	hit_radius = 1.3
	Build.cyl(self, Vector3(0, -1.5, 0), 0.25, 1.6, Build.mat(Color(0.3, 0.3, 0.36), 0.5), false, -1.0, 6)
	Build.cyl(self, Vector3(0, -2.15, 0), 0.9, 0.3, Build.mat(Color(0.3, 0.3, 0.36), 0.5), false, -1.0, 8)
	Build.visual(body, _sphere(0.95), Build.mat(Color(0.55, 0.3, 0.75), 0.4), Vector3.ZERO, Vector3(1, 0.8, 1))
	Build.cyl(body, Vector3(0, 0, -0.9), 0.3, 1.0, Build.mat(Color(0.2, 0.2, 0.25), 0.4), false, 0.4, 8, Vector3(PI / 2, 0, 0))
	core = Build.visual(body, _sphere(0.3, 8), Build.mat(Color(1.0, 0.4, 0.9), 0.3, 3.0), Vector3(0, 0, -1.45))
	core.scale = Vector3.ONE * 0.3

func _reset() -> void:
	mode = IDLE
	t = 1.0
	core.scale = Vector3.ONE * 0.3

func _think(dt: float, p: Player, d: float) -> void:
	t -= dt
	var to_p: Vector3 = p.global_position - global_position
	if d < sight * 1.3:
		face(to_p, dt, 3.5)
	match mode:
		IDLE:
			if d < sight and t <= 0.0 and _sees(p):
				mode = AIM
				t = 0.8
				Sfx.play("warn", 1.3, -6.0)
		AIM:
			core.scale = Vector3.ONE * lerpf(2.2, 0.3, t / 0.8)
			if t <= 0.0:
				# lead the target a little so standing still is punished, speed is rewarded
				var lead: Vector3 = p.global_position + p.velocity * (d / shot_speed) * 0.45
				var muzzle := global_position + forward() * 1.5
				Projectile.fire(muzzle, (lead - muzzle).normalized() * shot_speed)
				Sfx.play("shoot", 1.0, -4.0)
				core.scale = Vector3.ONE * 0.3
				mode = COOL
				t = 1.9
		COOL:
			if t <= 0.0:
				mode = IDLE

func _sees(p: Player) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position, p.global_position, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
