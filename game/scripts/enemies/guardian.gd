class_name Guardian
extends Node3D
## The island's guardian: a floating core that sleeps until enough Aurora
## Cores are gathered. Attacks are telegraphed and every one ends with the
## core exposed, so the fight rewards movement instead of waiting.

enum { DORMANT, IDLE, RISE, SLAM, VOLLEY, AIM_CHARGE, CHARGE, EXPOSED, DEAD }
const MAX_HP := 6
const ARENA_R := 62.0

var mode := DORMANT
var hp := MAX_HP
var t := 0.0
var homing_enabled := false
var centre := Vector3.ZERO
var floor_y := 0.0
var attack_i := 0
var shots := 0
var charge_dir := Vector3.FORWARD
var waves: Array = []        # [mesh, radius]
var grace := 0.0
var notice_t := 0.0
var core: MeshInstance3D
var core_mat: StandardMaterial3D
var plates: Node3D
var marker: MeshInstance3D

static func make(parent: Node, c: Vector3) -> Guardian:
	var gd := Guardian.new()
	gd.centre = c
	gd.floor_y = c.y
	gd.position = c + Vector3(0, 3.2, 0)
	parent.add_child(gd)
	return gd

func _ready() -> void:
	add_to_group("homing")
	add_to_group("respawn_listener")
	var s := SphereMesh.new()
	s.radius = 2.6
	s.height = 5.2
	s.radial_segments = 16
	s.rings = 8
	core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.3, 0.3, 0.38)
	core_mat.roughness = 0.3
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.6, 0.3, 1.0)
	core_mat.emission_energy_multiplier = 0.2
	core = Build.visual(self, s, core_mat, Vector3.ZERO)
	plates = Node3D.new()
	add_child(plates)
	var pm := Build.mat(Color(0.25, 0.26, 0.34), 0.5)
	for i in 6:
		var a := TAU * i / 6.0
		Build.box(plates, Vector3(cos(a) * 3.4, 0, sin(a) * 3.4), Vector3(0.5, 3.4, 2.6), pm, Vector3(0, -a, 0), false)
		Build.box(plates, Vector3(cos(a) * 3.7, 0, sin(a) * 3.7), Vector3(0.12, 2.2, 0.5), Build.mat(Color(0.7, 0.4, 1.0), 0.3, 2.0), Vector3(0, -a, 0), false)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(1.0, 0.25, 0.2, 0.45)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker = Build.box(self, Vector3.ZERO, Vector3(5.0, 0.1, 1.0), mm, Vector3.ZERO, false) as MeshInstance3D
	marker.top_level = true
	marker.visible = false
	if Game.has_flag("guardian_defeated"):
		_husk()

func _husk() -> void:
	mode = DEAD
	homing_enabled = false
	position = centre + Vector3(0, 1.6, 0)
	rotation = Vector3(0.5, 0.3, 0.2)
	core_mat.emission_energy_multiplier = 0.0
	core_mat.albedo_color = Color(0.2, 0.2, 0.22)

func homing_point() -> Vector3:
	return global_position

func homing_hit(p: Player) -> void:
	if mode != EXPOSED or grace > 0.0:
		return
	hp -= 1
	grace = 0.6
	Sfx.play("hit", 0.7)
	Sfx.play("break", 1.3, -4.0)
	Fx.burst(global_position, Color(0.8, 0.5, 1.0), 26, 14.0, 0.8, 0.0, 2.0)
	if Game.camera != null:
		Game.camera.shake(0.5)
	var away := p.global_position - global_position
	away.y = 0
	away = away.normalized() if away.length() > 0.1 else Vector3.BACK
	p.launch(away * 14.0 + Vector3(0, 19, 0), 0.25, 0.0, true)
	p.add_boost(30.0)
	Game.boss_hp_changed.emit(true, float(hp) / MAX_HP)
	if hp <= 0:
		_defeat()
	else:
		_go(IDLE, 1.2)

func _defeat() -> void:
	homing_enabled = false
	Game.boss_hp_changed.emit(false, 0.0)
	Game.set_flag("guardian_defeated")
	Game.add_sparks(100)
	Game.say("The Guardian falls silent. Aurora Isle is free!", 7.0)
	Sfx.play("win")
	for i in 6:
		get_tree().create_timer(i * 0.25, false).timeout.connect(func():
			Fx.burst(global_position + Vector3(randf_range(-4, 4), randf_range(-2, 4), randf_range(-4, 4)), Color(1.0, 0.8, 0.4), 20, 14.0, 0.9, 0.0, 2.2))
	_clear_waves()
	var tw := create_tween()
	tw.tween_property(self, "position", centre + Vector3(0, 1.6, 0), 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_husk)
	mode = DEAD
	if Game.world != null and Game.world.has_method("celebrate"):
		Game.world.celebrate()

func on_player_respawn() -> void:
	if mode == DEAD:
		return
	_clear_waves()
	hp = MAX_HP
	mode = DORMANT
	homing_enabled = false
	marker.visible = false
	position = centre + Vector3(0, 3.2, 0)
	core_mat.emission = Color(0.6, 0.3, 1.0)
	core_mat.emission_energy_multiplier = 0.2
	Game.boss_hp_changed.emit(false, 0.0)

func _clear_waves() -> void:
	for w in waves:
		w[0].queue_free()
	waves.clear()

func _go(m: int, time: float) -> void:
	mode = m
	t = time
	homing_enabled = m == EXPOSED
	marker.visible = m == AIM_CHARGE
	match m:
		EXPOSED:
			core_mat.emission = Color(1.0, 0.85, 0.3)
			core_mat.emission_energy_multiplier = 2.5
		RISE, AIM_CHARGE, VOLLEY:
			core_mat.emission = Color(1.0, 0.2, 0.15)
			core_mat.emission_energy_multiplier = 2.0
		_:
			core_mat.emission = Color(0.6, 0.3, 1.0)
			core_mat.emission_energy_multiplier = 1.0

func _physics_process(dt: float) -> void:
	var p = Game.player
	if mode == DEAD or p == null or not is_instance_valid(p):
		return
	grace = maxf(0.0, grace - dt)
	var pp: Vector3 = p.global_position
	var to_p: Vector3 = pp - global_position
	var flat := Vector3(to_p.x, 0, to_p.z)
	var pd := Vector3(pp.x - centre.x, 0, pp.z - centre.z).length()
	plates.rotate_y(dt * (0.6 if mode == DORMANT else 2.2))
	plates.scale = plates.scale.lerp(Vector3.ONE * (1.5 if mode == EXPOSED else 1.0), dt * 6.0)
	_update_waves(dt, p)
	t -= dt

	if mode == DORMANT:
		notice_t -= dt
		if pd < 50.0:
			if Game.token_count() >= Game.TOKENS_FOR_GUARDIAN:
				Game.say("The Guardian awakens!", 3.0)
				Sfx.play("warn", 0.5)
				Game.boss_hp_changed.emit(true, 1.0)
				_go(IDLE, 2.0)
			elif notice_t <= 0.0:
				notice_t = 15.0
				Game.say("The Guardian sleeps behind a seal: %d more Aurora Cores needed." % (Game.TOKENS_FOR_GUARDIAN - Game.token_count()), 4.0)
		return

	if pd > ARENA_R + 45.0:
		# the player walked away: go back to sleep
		on_player_respawn()
		return

	var phase2 := hp <= 3
	match mode:
		IDLE:
			var hover_to := centre + Vector3(sin(Time.get_ticks_msec() * 0.0006) * 14.0, 7.0, cos(Time.get_ticks_msec() * 0.0005) * 14.0)
			position = position.lerp(hover_to, dt * 1.5)
			if t <= 0.0:
				var order: Array = [RISE, VOLLEY, AIM_CHARGE] if phase2 else [RISE, VOLLEY]
				var pick: int = order[attack_i % order.size()]
				attack_i += 1
				shots = 6 if phase2 else 4
				Sfx.play("warn", 0.8)
				if pick == AIM_CHARGE:
					charge_dir = flat.normalized() if flat.length() > 1.0 else Vector3.FORWARD
				_go(pick, 0.9 if pick != VOLLEY else 0.7)
		RISE:
			position.y = lerpf(position.y, floor_y + 13.0, dt * 5.0)
			core.scale = Vector3.ONE * (1.0 + 0.1 * sin(t * 40.0))
			if t <= 0.0:
				core.scale = Vector3.ONE
				_go(SLAM, 0.22)
		SLAM:
			position.y = lerpf(position.y, floor_y + 2.4, dt * 30.0)
			if t <= 0.0:
				position.y = floor_y + 2.4
				_spawn_wave(0.0)
				if phase2:
					get_tree().create_timer(0.7, false).timeout.connect(func(): if mode != DEAD and mode != DORMANT: _spawn_wave(0.0))
				Sfx.play("stomp", 0.7)
				if Game.camera != null:
					Game.camera.shake(0.5)
				_go(EXPOSED, 4.2)
		VOLLEY:
			position = position.lerp(Vector3(position.x, floor_y + 6.0, position.z), dt * 3.0)
			if t <= 0.0:
				if shots > 0:
					shots -= 1
					t = 0.38
					var lead: Vector3 = pp + p.velocity * 0.35
					Projectile.fire(global_position, (lead - global_position).normalized() * 34.0, Color(1.0, 0.3, 0.3))
					Sfx.play("shoot", 0.8, -3.0)
				else:
					_go(EXPOSED, 3.8)
		AIM_CHARGE:
			position.y = lerpf(position.y, floor_y + 2.6, dt * 6.0)
			# keep tracking for the first part of the wind-up, then commit
			if t > 0.35 and flat.length() > 1.0:
				charge_dir = flat.normalized()
			marker.global_position = Vector3(global_position.x, floor_y + 0.15, global_position.z) + charge_dir * 30.0
			marker.global_rotation = Vector3(0, atan2(-charge_dir.x, -charge_dir.z), 0)
			marker.scale = Vector3(1.0, 1.0, 60.0)
			if t <= 0.0:
				_go(CHARGE, 1.5)
				Sfx.play("release", 0.6)
		CHARGE:
			position += charge_dir * 50.0 * dt
			var off := Vector3(position.x - centre.x, 0, position.z - centre.z)
			if off.length() > ARENA_R - 6.0 or t <= 0.0:
				Sfx.play("stomp", 1.2)
				_go(EXPOSED, 4.5)
		EXPOSED:
			position.y = lerpf(position.y, floor_y + 2.4, dt * 6.0)
			if t <= 0.0:
				_go(IDLE, 1.6 if phase2 else 2.2)

	# body contact while shielded
	if mode != EXPOSED and to_p.length() < 4.4 and grace <= 0.0:
		grace = 0.5
		if not p.hurt(global_position):
			var away := flat.normalized() if flat.length() > 0.1 else Vector3.BACK
			p.launch(away * 14.0 + Vector3(0, 8, 0), 0.3)

func _spawn_wave(r0: float) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 5
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.35, 0.25, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.material_override = m
	mi.top_level = true
	add_child(mi)
	mi.global_position = Vector3(global_position.x, floor_y + 0.5, global_position.z)
	waves.append([mi, maxf(r0, 1.0)])

func _update_waves(dt: float, p: Player) -> void:
	for i in range(waves.size() - 1, -1, -1):
		var w: Array = waves[i]
		w[1] += 24.0 * dt
		var mi: MeshInstance3D = w[0]
		mi.scale = Vector3(w[1], 1.4, w[1])
		var pp: Vector3 = p.global_position
		var d := Vector2(pp.x - mi.global_position.x, pp.z - mi.global_position.z).length()
		if absf(d - w[1]) < 1.3 and pp.y < floor_y + 1.9:
			p.hurt(mi.global_position)
		if w[1] > ARENA_R + 8.0:
			mi.queue_free()
			waves.remove_at(i)
