class_name Player
extends CharacterBody3D
## Momentum-based high-speed character controller.
##
## The body is a sphere driven by custom movement maths. CharacterBody3D is
## only used for swept collision (MOTION_MODE_FLOATING); ground detection,
## slope physics, surface sticking and speed preservation are all handled here
## so that small collision irregularities never eat the player's momentum.

enum St { GROUND, AIR, HOMING, STOMP, GRIND, CHARGE, DEAD }

const RADIUS := 0.5
const GRAVITY := 38.0
const TOP_RUN := 32.0          # top speed from running alone
const BOOST_SPEED := 52.0      # top speed while boosting
const MAX_SPEED := 88.0        # hard cap (slopes / spin dash can exceed boost)
const ACCEL := 19.0
const ACCEL_LOW := 38.0        # snappy start below LOW_SPEED
const LOW_SPEED := 10.0
const BOOST_ACCEL := 70.0
const DECEL := 17.0
const BRAKE := 75.0
const OVERSPEED_DECAY := 5.0   # gentle decay above top speed (keeps momentum)
const JUMP_V := 17.0
const JUMP_CUT := 7.0
const DOUBLE_JUMP_V := 14.0
const AIR_ACCEL := 24.0
const FLOOR_ANGLE := 0.92      # ~53 deg: max change between successive ground normals
const STICK_SPEED := 11.0      # below this you fall off walls / ceilings
const SLOPE_RUN := 0.55        # share of slope gravity applied while running
const SLOPE_BOOST := 0.2
const SLOPE_ROLL := 1.2
const HOMING_SPEED := 78.0
const HOMING_RANGE := 26.0
const STOMP_SPEED := 68.0
const SPIN_MIN := 36.0
const SPIN_MAX := 64.0
const BOOST_DRAIN := 20.0
const BOOST_REGEN := 13.0
const COYOTE := 0.12
const BUFFER := 0.13

signal landed(impact: float)
signal state_changed(new_state: int)

var state: int = St.AIR
var ground_normal := Vector3.UP
var facing := Vector3.FORWARD
var wish := Vector3.ZERO
var held := {"jump": false, "boost": false, "attack": false, "spin": false, "stomp": false}
var pressed := {"jump": false, "boost": false, "attack": false, "spin": false, "stomp": false}

var ball := false          # curled (jump / attack) pose in the air
var rolling := false       # ground roll after a spin dash
var boosting := false
var skidding := false
var boost := 100.0
var boost_cool := 0.0
var boost_locked := false
var charge := 0.0

var coyote_t := 0.0
var buffer_t := 0.0
var jump_lock := 0.0
var lock_t := 0.0          # steering lock (dash pads, springs, knockback)
var nograv_t := 0.0
var invuln_t := 0.0
var rail_cool := 0.0
var homing_t := 0.0
var dead_t := 0.0
var air_t := 0.0
var safe_t := 0.0
var wet_t := 0.0
var can_cut := false
var can_double := true
var can_dash := true
var air_boosted := false
var stomp_bounce := false

var target: Node3D = null
var ignore_target: Node3D = null   # the thing that just launched / bounced us
var ignore_t := 0.0
var rail = null
var rail_off := 0.0
var rail_speed := 0.0
var ground_body: Object = null
var kill_y := -40.0
var last_safe := Vector3.ZERO
var has_safe := false
var cam_yaw := 0.0
var visual: Node3D
var _ray_q := PhysicsRayQueryParameters3D.new()

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	max_slides = 5
	safe_margin = 0.01
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = RADIUS
	cs.shape = sh
	add_child(cs)
	_ray_q.collision_mask = 1
	_ray_q.exclude = [get_rid()]
	visual = preload("res://scripts/player/player_visual.gd").new()
	add_child(visual)
	Game.player = self

# ------------------------------------------------------------------ frame

func _physics_process(dt: float) -> void:
	_read_input()
	_timers(dt)
	match state:
		St.GROUND: _ground(dt)
		St.AIR: _air(dt)
		St.HOMING: _homing(dt)
		St.STOMP: _stomp(dt)
		St.GRIND: _grind(dt)
		St.CHARGE: _charge(dt)
		St.DEAD: _dead(dt)
	if state != St.DEAD:
		_common(dt)

func _read_input() -> void:
	var mv := Controls.get_move()
	if Game.camera != null and is_instance_valid(Game.camera):
		cam_yaw = Game.camera.yaw
	if Controls.override != null and Controls.override.has("yaw"):
		cam_yaw = Controls.override["yaw"]
	var f := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var r := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	wish = (r * mv.x + f * mv.y).limit_length(1.0)
	if wish.length() < 0.12:
		wish = Vector3.ZERO
	for a in held.keys():
		var h := Controls.held(a)
		pressed[a] = h and not held[a]
		held[a] = h
	if pressed["jump"]:
		buffer_t = BUFFER

func _timers(dt: float) -> void:
	buffer_t = maxf(0.0, buffer_t - dt)
	coyote_t = maxf(0.0, coyote_t - dt)
	jump_lock = maxf(0.0, jump_lock - dt)
	lock_t = maxf(0.0, lock_t - dt)
	nograv_t = maxf(0.0, nograv_t - dt)
	invuln_t = maxf(0.0, invuln_t - dt)
	rail_cool = maxf(0.0, rail_cool - dt)
	boost_cool = maxf(0.0, boost_cool - dt)
	ignore_t = maxf(0.0, ignore_t - dt)

func _set_state(s: int) -> void:
	if s != state:
		state = s
		state_changed.emit(s)

func speed() -> float:
	return velocity.length()

func hspeed() -> float:
	return Vector2(velocity.x, velocity.z).length()

# ------------------------------------------------------------------ boost

func _boost_wanted() -> bool:
	if not held["boost"]:
		boost_locked = false
		return false
	if boost_locked:
		return false
	if boost <= 0.0:
		boost_locked = true
		return false
	return true

func _update_boost(dt: float, draining: bool) -> void:
	if draining:
		boost = maxf(0.0, boost - BOOST_DRAIN * dt)
		boost_cool = 0.7
	elif boost_cool <= 0.0:
		boost = minf(100.0, boost + BOOST_REGEN * dt)

func add_boost(v: float) -> void:
	boost = minf(100.0, boost + v)

func _start_boost_fx() -> void:
	Sfx.play("boost")
	Fx.ring_wave(global_position, Color(0.4, 0.9, 1.0, 0.8), 4.0, 0.3)

# ------------------------------------------------------------------ ground

func _tangent(v: Vector3, n: Vector3) -> Vector3:
	return v - n * v.dot(n)

func _ground(dt: float) -> void:
	var n := ground_normal
	velocity = _tangent(velocity, n)
	var spd := velocity.length()
	var slope := n.angle_to(Vector3.UP)
	var steep := slope > 0.96
	var dir := velocity / spd if spd > 0.3 else _tangent(facing, n).normalized()
	if dir.length() < 0.5:
		dir = _tangent(Vector3.FORWARD, n).normalized()
	skidding = false

	# --- spin dash / roll entry
	if pressed["spin"] and not steep:
		if spd < 14.0:
			charge = 0.0
			rolling = false
			boosting = false
			_set_state(St.CHARGE)
			Sfx.play("charge")
			return
		rolling = true
	if rolling and (spd < 5.0 or pressed["boost"]):
		rolling = false

	# --- wish direction on the ground plane
	var wt := Vector3.ZERO
	var wl := wish.length()
	if lock_t > 0.0:
		wt = dir
		wl = 1.0
	elif wl > 0.0:
		if steep:
			wt = dir
		else:
			wt = (Quaternion(Vector3.UP, n) * wish).normalized()

	var want_boost := _boost_wanted() and not rolling
	if want_boost and not boosting:
		_start_boost_fx()
		if spd < 40.0:
			spd = 40.0
		if wl > 0.0 and not steep and lock_t <= 0.0 and spd < 45.0:
			dir = wt
	boosting = want_boost

	if rolling:
		# rolling: no drive, low friction, full slope gravity, gentle steering
		if wl > 0.0 and lock_t <= 0.0 and not steep:
			if dir.dot(wt) < -0.5:
				spd = maxf(0.0, spd - 45.0 * dt)    # pull back to brake out of a roll
			else:
				dir = _rotate_toward(dir, wt, 1.6 * dt, n)
		spd = maxf(0.0, spd - 2.2 * dt)
	elif boosting:
		if wl > 0.0 and lock_t <= 0.0:
			dir = _rotate_toward(dir, wt, lerpf(3.2, 1.9, clampf(spd / MAX_SPEED, 0, 1)) * dt, n)
		if spd < BOOST_SPEED:
			spd = minf(BOOST_SPEED, spd + BOOST_ACCEL * dt)
		else:
			spd = maxf(BOOST_SPEED, spd - OVERSPEED_DECAY * dt)
	elif wl > 0.0:
		var d := dir.dot(wt)
		if spd > 9.0 and d < -0.45 and lock_t <= 0.0:
			# hard reverse input: skid to a stop first
			skidding = true
			spd = maxf(0.0, spd - BRAKE * dt)
		elif spd < 5.0:
			# low speed: precise, immediate
			var v := (dir * spd).move_toward(wt * maxf(spd, 5.0), ACCEL_LOW * 1.5 * dt)
			spd = v.length()
			if spd > 0.01:
				dir = v / spd
			spd = minf(spd + ACCEL_LOW * dt * 0.5, maxf(spd, TOP_RUN * wl))
		else:
			var rate := lerpf(9.0, 2.3, clampf((spd - 5.0) / (TOP_RUN - 5.0), 0.0, 1.0))
			var nd := _rotate_toward(dir, wt, rate * dt, n)
			# turning sheds only a little speed, so direction changes keep momentum
			spd -= spd * dir.angle_to(nd) * 0.12
			dir = nd
			var top := TOP_RUN * wl
			if spd < top:
				var a := ACCEL_LOW if spd < LOW_SPEED else ACCEL
				spd = minf(top, spd + a * dt)
			elif spd > TOP_RUN:
				spd = maxf(TOP_RUN, spd - OVERSPEED_DECAY * dt)
			else:
				spd = maxf(top, spd - DECEL * 0.5 * dt)
	else:
		spd = maxf(0.0, spd - DECEL * dt)

	velocity = dir * spd

	# --- slope gravity along the surface
	if slope > 0.06:
		var g_t := _tangent(Vector3.DOWN * GRAVITY, n)
		var resting := wl == 0.0 and spd < 0.6 and slope < 0.55 and not rolling
		if not resting:
			var k := SLOPE_ROLL if rolling else (SLOPE_BOOST if boosting else SLOPE_RUN)
			# going downhill always gives the full benefit of the slope
			if velocity.dot(g_t) > 0.0 and not rolling:
				k = maxf(k, 0.8)
			velocity += g_t * k * dt
	velocity = velocity.limit_length(MAX_SPEED)
	if velocity.length() > 0.5:
		var fh := Vector3(velocity.x, 0, velocity.z)
		if fh.length() > 0.3:
			facing = fh.normalized()
	elif wl > 0.0 and not steep:
		facing = wish.normalized()

	_update_boost(dt, boosting)

	# --- falling off steep surfaces when too slow
	if slope > FLOOR_ANGLE and velocity.length() < STICK_SPEED:
		velocity += n * 3.0
		lock_t = 0.25
		_leave_ground(false)
		return

	# --- jump
	if buffer_t > 0.0:
		_jump(n)
		return

	# --- attack from the ground
	if pressed["attack"] and target != null:
		_start_homing()
		return

	_ground_move(dt)

func _rotate_toward(from: Vector3, to: Vector3, max_angle: float, n: Vector3) -> Vector3:
	var ang := from.angle_to(to)
	if ang < 0.0001:
		return to
	if ang <= max_angle:
		return to
	var axis := from.cross(to)
	if axis.length() < 0.0001:
		axis = n
	return from.rotated(axis.normalized(), max_angle).normalized()

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	_ray_q.from = from
	_ray_q.to = to
	return get_world_3d().direct_space_state.intersect_ray(_ray_q)

## Moves along the ground, then re-resolves the ground normal and restores any
## speed the collision solver removed while following the surface.
func _ground_move(_dt: float) -> void:
	var n := ground_normal
	if ground_body != null and is_instance_valid(ground_body) and ground_body.has_method("carry_velocity"):
		move_and_collide(ground_body.carry_velocity() * _dt)
	var pre := velocity.length()
	var pre_v := velocity
	move_and_slide()
	if _smash_check(pre_v):
		return
	var best := Vector3.ZERO
	var best_d := -2.0
	var wall := false
	for i in get_slide_collision_count():
		var cn := get_slide_collision(i).get_normal()
		if cn.angle_to(n) < FLOOR_ANGLE:
			var d := cn.dot(n)
			if d > best_d:
				best_d = d
				best = cn
		else:
			wall = true
	var found := best_d > -2.0
	if found:
		n = best
	var snap := 0.3 + pre * 0.016
	var hit := _ray(global_position, global_position - n * (RADIUS + snap))
	if not hit.is_empty() and (hit.normal as Vector3).angle_to(n) < FLOOR_ANGLE:
		var hn: Vector3 = hit.normal
		var gap := (global_position - (hit.position as Vector3)).dot(hn) - RADIUS
		if gap > 0.004:
			move_and_collide(-hn * gap)
		n = hn
		found = true
		ground_body = hit.collider
	if not found:
		_leave_ground(true)
		return
	ground_normal = n
	var vt := _tangent(velocity, n)
	if wall or vt.length() < 0.01:
		velocity = vt
	else:
		velocity = vt.normalized() * pre

## Spin Dash rolls and boosts plough through breakable walls without slowing.
func _smash_check(pre_v: Vector3) -> bool:
	if not (rolling or boosting) or pre_v.length() < 24.0:
		return false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i).get_collider()
		if col != null and col.is_in_group("breakable"):
			col.smash()
			velocity = pre_v
			return true
	return false

func _leave_ground(allow_coyote: bool) -> void:
	_set_state(St.AIR)
	coyote_t = COYOTE if allow_coyote else 0.0
	ball = rolling
	rolling = false
	can_cut = false
	can_double = true
	can_dash = true
	air_boosted = false
	air_t = 0.0
	ground_body = null

func _jump(n: Vector3) -> void:
	# jump along the surface normal, but never weaker than a flat-ground jump
	velocity += n * JUMP_V
	if n.y > 0.5 and velocity.y < JUMP_V * n.y:
		velocity.y = JUMP_V * n.y
	buffer_t = 0.0
	coyote_t = 0.0
	jump_lock = 0.12
	_leave_ground(false)
	ball = true
	can_cut = true
	Sfx.play("jump")

func _land(n: Vector3, impact: float) -> void:
	ground_normal = n
	velocity = _tangent(velocity, n)
	_set_state(St.GROUND)
	ball = false
	rolling = held["spin"] and velocity.length() > 12.0
	skidding = false
	if impact > 14.0:
		Fx.burst(global_position - n * RADIUS, Color(0.9, 0.88, 0.8, 0.8), 8, 4.0, 0.4, 0.3)
	landed.emit(impact)

# ------------------------------------------------------------------ air

func _air(dt: float) -> void:
	air_t += dt
	if nograv_t <= 0.0:
		velocity.y = maxf(velocity.y - GRAVITY * dt, -75.0)
	if can_cut and not held["jump"] and velocity.y > JUMP_CUT:
		velocity.y = JUMP_CUT
		can_cut = false
	if velocity.y <= 0.0:
		can_cut = false

	# --- air steering: turn and accelerate without throwing away momentum
	var hv := Vector3(velocity.x, 0, velocity.z)
	var hs := hv.length()
	if lock_t <= 0.0 and wish != Vector3.ZERO:
		var wd := wish.normalized()
		if hs > 6.0:
			var hd := hv / hs
			if hd.dot(wd) < -0.3:
				hs = maxf(0.0, hs - 34.0 * dt)
			else:
				hd = _rotate_toward(hd, wd, 2.6 * dt, Vector3.UP)
				if hs < TOP_RUN * wish.length():
					hs = minf(TOP_RUN, hs + AIR_ACCEL * 0.6 * dt)
			hv = hd * hs
		else:
			hv = hv.move_toward(wd * TOP_RUN * 0.5, AIR_ACCEL * dt)
		velocity.x = hv.x
		velocity.z = hv.z
		hs = hv.length()
	if hs > 0.5:
		facing = hv / hs

	# --- boost in the air: one burst per jump
	var want_boost := _boost_wanted()
	if pressed["boost"] and want_boost and not air_boosted and boost >= 6.0:
		air_boosted = true
		boost = maxf(0.0, boost - 8.0)
		boost_cool = 0.7
		var bd := wish.normalized() if wish != Vector3.ZERO else facing
		var bs := maxf(hs, 42.0)
		velocity = Vector3(bd.x * bs, maxf(velocity.y, 4.0), bd.z * bs)
		facing = bd
		nograv_t = 0.15
		_start_boost_fx()
	boosting = want_boost and hspeed() > 30.0
	_update_boost(dt, false)

	# --- actions
	if buffer_t > 0.0:
		if coyote_t > 0.0:
			velocity.y = 0.0
			_jump(Vector3.UP)
			return
		elif can_double and pressed["jump"] and not _ground_close():
			can_double = false
			buffer_t = 0.0
			velocity.y = DOUBLE_JUMP_V
			ball = true
			can_cut = true
			Sfx.play("djump")
			Fx.ring_wave(global_position - Vector3(0, 0.4, 0), Color(1, 1, 1, 0.7), 1.6, 0.25)
	if pressed["attack"]:
		if target != null:
			_start_homing()
			return
		elif can_dash:
			can_dash = false
			var dd := wish.normalized() if wish != Vector3.ZERO else facing
			var ds := maxf(hs, 34.0)
			velocity = Vector3(dd.x * ds, 2.5, dd.z * ds)
			nograv_t = 0.12
			ball = true
			Sfx.play("homing", 0.8)
	if pressed["stomp"] and air_t > 0.08:
		_set_state(St.STOMP)
		velocity = Vector3(velocity.x * 0.2, -STOMP_SPEED, velocity.z * 0.2)
		ball = true
		Sfx.play("homing", 0.6)
		return

	var pre := velocity
	move_and_slide()
	if _smash_check(pre):
		return
	for i in get_slide_collision_count():
		var cn := get_slide_collision(i).get_normal()
		if jump_lock <= 0.0 and cn.angle_to(Vector3.UP) < FLOOR_ANGLE and pre.dot(cn) < 1.0:
			_land(cn, -pre.dot(cn))
			return

## About to land: keep the press buffered for a full jump instead of spending
## the weaker double jump a few centimetres above the floor.
func _ground_close() -> bool:
	if velocity.y > -2.0:
		return false
	var hit := _ray(global_position, global_position + Vector3(0, -(RADIUS + 0.25) + velocity.y * BUFFER, 0))
	return not hit.is_empty() and (hit.normal as Vector3).y > 0.6

# ------------------------------------------------------------------ homing

func _aim_dir() -> Vector3:
	var hv := Vector3(velocity.x, 0, velocity.z)
	var a := hv.normalized() if hv.length() > 4.0 else facing
	if wish != Vector3.ZERO:
		a = (a + wish.normalized() * 0.9).normalized()
	return a if a.length() > 0.5 else facing

func _find_target() -> Node3D:
	if state != St.AIR and state != St.GROUND:
		return target if state == St.HOMING else null
	var aim := _aim_dir()
	var best: Node3D = null
	var best_score := INF
	var here := global_position
	var grounded := state == St.GROUND
	for t in get_tree().get_nodes_in_group("homing"):
		if not t.homing_enabled or (t == ignore_target and ignore_t > 0.0):
			continue
		var p: Vector3 = t.homing_point()
		var to := p - here
		var d := to.length()
		if d > HOMING_RANGE or d < 0.6 or to.y > 9.0:
			continue
		if grounded and (d > 16.0 or to.y < 0.8):
			continue
		var flat := Vector3(to.x, 0, to.z)
		var dot := flat.normalized().dot(aim) if flat.length() > 1.5 else 1.0
		if dot < 0.2:
			continue
		var score := d * (1.7 - dot)
		if score < best_score:
			var hit := _ray(here, p)
			if hit.is_empty() or hit.collider == t or (hit.position as Vector3).distance_to(p) < 0.6:
				best = t
				best_score = score
	return best

func _start_homing() -> void:
	_set_state(St.HOMING)
	homing_t = 0.0
	ball = true
	rolling = false
	boosting = false
	can_cut = false
	Sfx.play("homing")

func _homing(dt: float) -> void:
	if target == null or not is_instance_valid(target) or not target.homing_enabled:
		_end_homing(0.4)
		return
	homing_t += dt
	var p: Vector3 = target.homing_point()
	var to := p - global_position
	var d := to.length()
	if d <= 1.1 + HOMING_SPEED * dt:
		var dir := to / maxf(d, 0.001)
		global_position = p - dir * 0.9
		_homing_impact(dir)
		return
	velocity = to / d * HOMING_SPEED
	facing = Vector3(velocity.x, 0, velocity.z).normalized() if hspeed() > 1.0 else facing
	move_and_slide()
	if (get_slide_collision_count() > 0 and homing_t > 0.06) or homing_t > 0.9:
		_end_homing(0.3)

func _homing_impact(dir: Vector3) -> void:
	var t := target
	_set_state(St.AIR)
	air_t = 0.1
	ball = true
	can_double = true
	can_dash = true
	air_boosted = false
	can_cut = false
	jump_lock = 0.1
	# default rebound; the target may override it (springs launch, etc.)
	velocity = Vector3(dir.x * 5.0, 15.5, dir.z * 5.0)
	Fx.burst(t.homing_point(), Color(1, 0.95, 0.6), 10, 8.0, 0.35, 0.0)
	ignore_target = t
	ignore_t = 0.45
	t.homing_hit(self)

func _end_homing(keep: float) -> void:
	_set_state(St.AIR)
	velocity *= keep
	can_dash = false
	air_t = 0.1

# ------------------------------------------------------------------ stomp

func _stomp(_dt: float) -> void:
	velocity = Vector3(velocity.x * 0.9, -STOMP_SPEED, velocity.z * 0.9)
	move_and_slide()
	for i in get_slide_collision_count():
		var cn := get_slide_collision(i).get_normal()
		if cn.angle_to(Vector3.UP) < 1.2:
			velocity = Vector3.ZERO
			_land(cn if cn.angle_to(Vector3.UP) < FLOOR_ANGLE else Vector3.UP, 0.0)
			stomp_impact()
			return

func stomp_impact() -> void:
	var p := global_position - Vector3(0, RADIUS, 0)
	Sfx.play("stomp")
	Fx.ring_wave(p + Vector3(0, 0.15, 0), Color(1.0, 0.8, 0.4, 0.9), 6.0, 0.4)
	Fx.burst(p, Color(0.85, 0.8, 0.7, 0.9), 14, 7.0, 0.5, 0.2)
	if Game.camera != null:
		Game.camera.shake(0.35)
	get_tree().call_group("stomp_listener", "on_stomp", p, 5.0)

# ------------------------------------------------------------------ spin dash

func _charge(dt: float) -> void:
	var n := ground_normal
	velocity = _tangent(velocity, n).move_toward(Vector3.ZERO, 60.0 * dt)
	charge = minf(1.0, charge + dt / 0.75)
	if wish != Vector3.ZERO:
		facing = _rotate_toward(facing, wish.normalized(), 7.0 * dt, Vector3.UP)
	_update_boost(dt, false)
	if buffer_t > 0.0:
		_set_state(St.GROUND)
		_jump(n)
		return
	if not held["spin"]:
		var d := (Quaternion(Vector3.UP, n) * facing).normalized() if n.angle_to(Vector3.UP) < 1.4 else facing
		velocity = d * lerpf(SPIN_MIN, SPIN_MAX, charge)
		rolling = true
		_set_state(St.GROUND)
		Sfx.play("release")
		Fx.burst(global_position - n * 0.4, Color(0.9, 0.9, 1.0, 0.8), 12, 6.0, 0.4, 0.2)
		return
	_set_state(St.GROUND)   # reuse ground resolution, then restore
	_ground_move(dt)
	if state == St.GROUND:
		state = St.CHARGE

# ------------------------------------------------------------------ rails

func _try_rail() -> void:
	if rail_cool > 0.0 or (state != St.AIR and state != St.GROUND):
		return
	if velocity.y > 4.0 and state == St.AIR:
		return
	var foot := global_position - Vector3(0, RADIUS, 0)
	for r in get_tree().get_nodes_in_group("rails"):
		if not r.world_aabb.has_point(foot):
			continue
		var c: Dictionary = r.closest(foot)
		if c.dist < (1.5 if state == St.AIR else 1.2):
			_attach_rail(r, c.offset)
			return

func _attach_rail(r, off: float) -> void:
	rail = r
	rail_off = off
	var tan: Vector3 = r.tangent(off)
	rail_speed = velocity.dot(tan)
	if absf(rail_speed) < 14.0:
		var s := signf(rail_speed) if absf(rail_speed) > 2.0 else signf(facing.dot(tan))
		if s == 0.0:
			s = 1.0
		rail_speed = s * 14.0
	_set_state(St.GRIND)
	ball = false
	rolling = false
	Sfx.play("pad", 1.4, -6.0)
	Fx.burst(global_position - Vector3(0, RADIUS, 0), Color(1, 0.9, 0.5), 8, 5.0, 0.3, 0.3)

func _grind(dt: float) -> void:
	if rail == null or not is_instance_valid(rail):
		_leave_ground(false)
		return
	var tan: Vector3 = rail.tangent(rail_off)
	var s := signf(rail_speed)
	rail_speed += -GRAVITY * tan.y * 0.85 * dt
	boosting = _boost_wanted()
	_update_boost(dt, boosting)
	if boosting and absf(rail_speed) < BOOST_SPEED:
		rail_speed = move_toward(rail_speed, s * BOOST_SPEED, 55.0 * dt)
	elif absf(rail_speed) < 16.0:
		rail_speed = move_toward(rail_speed, s * 16.0, 45.0 * dt)
	rail_speed = clampf(rail_speed, -MAX_SPEED, MAX_SPEED)
	rail_off += rail_speed * dt
	var ended: bool = rail_off < 0.0 or rail_off > rail.length
	rail_off = clampf(rail_off, 0.0, rail.length)
	tan = rail.tangent(rail_off)
	velocity = tan * rail_speed
	var fh := Vector3(velocity.x, 0, velocity.z)
	if fh.length() > 0.5:
		facing = fh.normalized()
	global_position = rail.sample(rail_off) + Vector3(0, RADIUS + 0.12, 0)
	if ended:
		rail_cool = 0.3
		rail = null
		_leave_ground(false)
		return
	if buffer_t > 0.0:
		rail_cool = 0.35
		rail = null
		velocity.y = maxf(velocity.y, 0.0) * 0.5
		_jump(Vector3.UP)

# ------------------------------------------------------------------ shared

func _common(dt: float) -> void:
	target = _find_target()
	_try_rail()
	if global_position.y < kill_y:
		fall_out()
		return
	# safety net: if anything ever pushes us beneath the terrain, pop back up
	var wd = Game.world
	if wd != null and wd.has_method("ground_y") and state != St.GRIND:
		var gy: float = wd.ground_y(global_position.x, global_position.z)
		if global_position.y < gy - 2.5:
			global_position.y = gy + 1.0
			velocity = Vector3.ZERO
			reset_physics_interpolation()
	# wading is fine for a moment, but nobody gets stranded at the foot of a sea cliff
	if global_position.y < kill_y + 0.9:
		wet_t += dt
		if wet_t > 2.5:
			wet_t = 0.0
			fall_out()
			return
	else:
		wet_t = 0.0
	if state == St.GROUND and ground_normal.y > 0.85 and global_position.y > kill_y + 2.2 and not (ground_body != null and ground_body.has_method("carry_velocity")):
		safe_t += dt
		if safe_t > 0.4:
			safe_t = 0.0
			last_safe = global_position
			has_safe = true
	Sfx.loop("wind", clampf((speed() - 24.0) / 50.0, 0.0, 0.5), 0.8 + speed() / 90.0)
	Sfx.loop("grind", 0.35 if state == St.GRIND else 0.0, 0.8 + absf(rail_speed) / 80.0)

func is_attacking() -> bool:
	return ball or rolling or boosting or state == St.HOMING or state == St.STOMP or state == St.CHARGE

## External launch (springs, hoops, cannons). Steering is locked for `lock`.
func launch(vel: Vector3, lock: float = 0.3, nograv: float = 0.0, curl: bool = false) -> void:
	if state == St.DEAD:
		return
	rail = null
	_leave_ground(false)
	velocity = vel
	lock_t = lock
	nograv_t = nograv
	jump_lock = 0.15
	ball = curl
	rail_cool = 0.15
	var fh := Vector3(vel.x, 0, vel.z)
	if fh.length() > 1.0:
		facing = fh.normalized()

## Dash pad: force speed along a direction while staying grounded.
func dash(dir: Vector3, spd: float, lock: float = 0.35) -> void:
	if state == St.DEAD:
		return
	var d := dir.normalized()
	if state == St.GROUND or state == St.CHARGE:
		d = _tangent(d, ground_normal).normalized()
		state = St.GROUND
	velocity = d * maxf(spd, velocity.length())
	lock_t = lock
	rolling = false
	var fh := Vector3(d.x, 0, d.z)
	if fh.length() > 0.3:
		facing = fh.normalized()

## Rebound after defeating something from the air.
func bounce(strength: float = 13.0) -> void:
	if state == St.GROUND or state == St.CHARGE or state == St.GRIND:
		return
	if state == St.STOMP:
		_set_state(St.AIR)
	velocity.y = strength
	can_double = true
	can_dash = true
	can_cut = false
	jump_lock = 0.1

func hurt(from: Vector3) -> bool:
	if invuln_t > 0.0 or state == St.DEAD:
		return false
	if Game.sparks <= 0 and not (Game.world != null and Game.world.get("is_test")):
		die()
		return true
	var lost := mini(Game.sparks, 25)
	Game.add_sparks(-lost)
	Fx.burst(global_position, Color(1.0, 0.85, 0.2), clampi(lost, 4, 20), 9.0, 0.8, 0.5, 1.4)
	Sfx.play("hurt")
	var away := global_position - from
	away.y = 0
	away = away.normalized() if away.length() > 0.1 else -facing
	rail = null
	_leave_ground(false)
	velocity = away * 10.0 + Vector3(0, 11.0, 0)
	lock_t = 0.5
	invuln_t = 2.0
	jump_lock = 0.15
	boosting = false
	if Game.camera != null:
		Game.camera.shake(0.4)
	return true

func die() -> void:
	Sfx.play("hurt", 0.7)
	Fx.burst(global_position, Color(0.3, 0.9, 0.9), 20, 9.0, 0.8, 0.0, 1.5)
	_set_state(St.DEAD)
	dead_t = 1.1
	velocity = Vector3.ZERO
	boosting = false
	visual.visible = false

func fall_out() -> void:
	# missed jumps over the sea put you back on the last solid ground
	if has_safe and Game.sparks >= 0:
		Sfx.play("hurt", 1.2)
		teleport(last_safe + Vector3(0, 0.6, 0))
		invuln_t = 1.5
	else:
		respawn()

func _dead(dt: float) -> void:
	dead_t -= dt
	if dead_t <= 0.0:
		respawn()

func respawn() -> void:
	var p: Vector3 = Game.checkpoint_pos if Game.has_checkpoint else (Game.world.spawn_point if Game.world != null else Vector3(0, 5, 0))
	teleport(p + Vector3(0, 1.0, 0))
	invuln_t = 2.0
	boost = 100.0
	get_tree().call_group("respawn_listener", "on_player_respawn")

func teleport(p: Vector3) -> void:
	global_position = p
	velocity = Vector3.ZERO
	rail = null
	target = null
	_set_state(St.AIR)
	ball = false
	rolling = false
	boosting = false
	lock_t = 0.0
	visual.visible = true
	reset_physics_interpolation()
	if Game.camera != null and is_instance_valid(Game.camera):
		Game.camera.snap()
