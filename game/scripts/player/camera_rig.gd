class_name CameraRig
extends Node3D
## Third-person chase camera: manual orbit (right stick / touch drag), gentle
## auto-follow at speed that yields to manual input, collision avoidance,
## speed-based FOV and damped vertical tracking so jumps do not bob the view.

var target: Player
var cam: Camera3D
var yaw := 0.0
var pitch := 0.3          # radians above the horizon
var manual_t := 0.0
var focus := Vector3.ZERO
var cur_dist := 7.0
var shake_t := 0.0
var _q := PhysicsRayQueryParameters3D.new()

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.15
	cam.far = 1600.0
	add_child(cam)
	cam.make_current()
	_q.collision_mask = 1
	Game.camera = self
	process_priority = 10

func snap() -> void:
	if target == null:
		return
	focus = target.global_position + Vector3(0, 0.9, 0)
	if target.facing.length() > 0.1:
		yaw = atan2(-target.facing.x, -target.facing.z)
	pitch = 0.3
	_place(1.0)

func shake(amount: float) -> void:
	shake_t = maxf(shake_t, amount)

func _process(dt: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var sens: float = Game.settings["cam_sens"]
	var inv := -1.0 if Game.settings["invert_y"] else 1.0
	var lv := Controls.get_look()
	var drag := Controls.take_drag_look()
	if lv.length() > 0.05 or drag.length() > 0.5:
		manual_t = 1.4
	yaw -= lv.x * 2.8 * sens * dt + drag.x * 0.0052 * sens
	pitch += (lv.y * 1.8 * sens * dt + drag.y * 0.004 * sens) * inv
	manual_t = maxf(0.0, manual_t - dt)

	var vel := target.velocity
	var hv := Vector3(vel.x, 0, vel.z)
	var hs := hv.length()
	var grind := target.state == Player.St.GRIND
	if manual_t <= 0.0:
		if hs > 7.0:
			var want := atan2(-hv.x, -hv.z)
			var diff := wrapf(want - yaw, -PI, PI)
			# running toward the camera: do not whip around unless really fast
			if absf(diff) < 2.5 or hs > 34.0 or grind:
				var rate := clampf(hs / 40.0, 0.25, 1.0) * (4.0 if grind else 2.4)
				yaw += diff * (1.0 - exp(-rate * dt))
		var want_pitch := 0.3 - clampf(vel.y * 0.011, -0.22, 0.4)
		if target.state == Player.St.GROUND:
			# look along slopes
			want_pitch = 0.3 - clampf(vel.y / maxf(hs, 8.0), -0.6, 0.6) * 0.5
		pitch = lerpf(pitch, want_pitch, 1.0 - exp(-1.6 * dt))
	pitch = clampf(pitch, -0.6, 1.35)
	yaw = wrapf(yaw, -PI, PI)

	var ppos := target.get_global_transform_interpolated().origin + Vector3(0, 0.9, 0)
	focus.x = ppos.x
	focus.z = ppos.z
	var airborne := target.state == Player.St.AIR
	var k := 5.0 if airborne else 14.0
	focus.y = lerpf(focus.y, ppos.y, 1.0 - exp(-k * dt))
	focus.y = clampf(focus.y, ppos.y - 2.5, ppos.y + 2.5)
	_place(dt)

	var spd := vel.length()
	var fov_t := 70.0 + clampf((spd - 20.0) / 40.0, 0.0, 1.0) * 20.0 + (6.0 if target.boosting else 0.0)
	cam.fov = lerpf(cam.fov, fov_t, 1.0 - exp(-4.0 * dt))
	if shake_t > 0.0:
		shake_t = maxf(0.0, shake_t - dt)
		cam.h_offset = randf_range(-1, 1) * shake_t * 0.3
		cam.v_offset = randf_range(-1, 1) * shake_t * 0.3
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

func _place(dt: float) -> void:
	var base: float = Game.settings["cam_dist"]
	var spd := target.velocity.length()
	var want := base + clampf(spd / 50.0, 0.0, 1.0) * 2.0
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	_q.from = focus
	_q.to = focus + dir * (want + 0.4)
	_q.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(_q)
	var allowed := want
	if not hit.is_empty():
		allowed = clampf(focus.distance_to(hit.position) - 0.4, 0.9, want)
	if allowed < cur_dist:
		cur_dist = allowed
	else:
		cur_dist = lerpf(cur_dist, allowed, 1.0 - exp(-3.5 * dt))
	global_position = focus + dir * cur_dist
	look_at(focus + Vector3(0, 0.5, 0), Vector3.UP)
