class_name Enemy
extends Node3D
## Shared enemy behaviour: homing-attack target, contact resolution, defeat
## and revival. Subclasses build visuals in _make() and act in _think().

var hp := 1
var max_hp := 1
var alive := true
var homing_enabled := true
var hit_radius := 1.5
var home := Vector3.ZERO
var hover := 0.0            # > 0: stays at fixed height above `home` (platform enemies)
var grace := 0.0
var flash_t := 0.0
var body: Node3D
var reward := 3

func _ready() -> void:
	add_to_group("homing")
	add_to_group("enemy")
	add_to_group("respawn_listener")
	home = position
	body = Node3D.new()
	add_child(body)
	_make()

func _make() -> void:
	pass

func _think(_dt: float, _p: Player, _dist: float) -> void:
	pass

func ground(x: float, z: float) -> float:
	if hover > 0.0:
		return home.y - hover
	var w = Game.world
	return w.ground_y(x, z) if w != null and w.has_method("ground_y") else 0.0

func homing_point() -> Vector3:
	return global_position + Vector3(0, 0.3, 0)

func homing_hit(p: Player) -> void:
	_struck(p)

var dead_t := 0.0

func _physics_process(dt: float) -> void:
	if not alive:
		# quietly return once the player has moved on, so the island stays lively
		dead_t += dt
		var pl = Game.player
		if dead_t > 40.0 and pl != null and is_instance_valid(pl) and home.distance_to(pl.global_position) > 70.0:
			on_player_respawn()
		return
	grace = maxf(0.0, grace - dt)
	if flash_t > 0.0:
		flash_t -= dt
		body.scale = Vector3.ONE * (1.0 + 0.25 * sin(flash_t * 40.0))
		if flash_t <= 0.0:
			body.scale = Vector3.ONE
	var p = Game.player
	if p == null or not is_instance_valid(p) or p.state == Player.St.DEAD:
		return
	var d: float = global_position.distance_to(p.global_position)
	if d > 110.0:
		return
	_think(dt, p, d)
	if alive and grace <= 0.0 and d < hit_radius + 0.55:
		if p.is_attacking():
			_struck(p)
		else:
			p.hurt(global_position)

func can_be_hit(_p: Player) -> bool:
	return true

func _struck(p: Player) -> void:
	if not alive or grace > 0.0:
		return
	if can_be_hit(p):
		damage(p)
	else:
		deflect(p)

func deflect(p: Player) -> void:
	grace = 0.4
	Sfx.play("switch", 0.5)
	var away := p.global_position - global_position
	away.y = 0
	away = away.normalized() if away.length() > 0.1 else Vector3.BACK
	p.launch(away * 15.0 + Vector3(0, 9, 0), 0.35, 0.0, true)
	Fx.burst(global_position + away, Color(0.5, 0.9, 1.0), 8, 6.0, 0.3)

func damage(p: Player) -> void:
	hp -= 1
	grace = 0.35
	flash_t = 0.3
	Sfx.play("hit")
	if Game.camera != null:
		Game.camera.shake(0.15)
	p.bounce(14.0)
	if hp <= 0:
		die(p)

func die(p: Player) -> void:
	alive = false
	dead_t = 0.0
	homing_enabled = false
	visible = false
	Fx.burst(global_position, Color(1.0, 0.6, 0.2), 16, 9.0, 0.6, 0.0, 1.4)
	Fx.burst(global_position, Color(0.3, 0.3, 0.35), 8, 5.0, 0.8, 0.3, 1.8)
	Game.add_sparks(reward)
	p.add_boost(18.0)

func on_player_respawn() -> void:
	alive = true
	homing_enabled = true
	visible = true
	hp = max_hp
	position = home
	body.scale = Vector3.ONE
	_reset()

func _reset() -> void:
	pass

func _sphere(r: float, segs: int = 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = segs / 2
	return s

func face(dir: Vector3, dt: float, rate: float) -> void:
	var want := atan2(-dir.x, -dir.z)
	rotation.y = rotate_toward(rotation.y, want, rate * dt)

func forward() -> Vector3:
	return Vector3(-sin(rotation.y), 0, -cos(rotation.y))
