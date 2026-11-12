extends Node
## Automated movement regression suite. Drives the real player controller with
## scripted inputs inside the test arena and checks gameplay outcomes.
## Run:  godot --headless --path game -- --test

var p: Player
var arena: TestArena
var inp := {}
var fails := 0
var total := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await step(3)
	p = Game.player
	arena = Game.world
	Controls.override = inp
	var names: Array = ["run", "turn", "boost", "jump", "jump_momentum", "coyote", "buffer", "slopes", "bumps", "hills",
			"loop", "spindash", "roll_downhill", "spring_homing_chain", "los", "rail", "rail_jump", "stomp",
			"wall", "breakable", "hoops", "hurt", "grunt", "turret", "bulwark"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			names = Array(a.trim_prefix("--only=").split(","))
		if a == "--trace":
			trace = true
	for t in names:
		await call("t_" + t)
	print("\n==== %d checks, %d failed ====" % [total, fails])
	get_tree().quit(1 if fails > 0 else 0)

var trace := false
var _tc := 0
func step(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		_tc += 1
		if trace and p != null and _tc % 4 == 0:
			print("  f%d st=%d pos=(%.1f,%.1f,%.1f) v=(%.1f,%.1f,%.1f) n=(%.2f,%.2f,%.2f) tgt=%s" % [_tc, p.state, p.global_position.x, p.global_position.y, p.global_position.z, p.velocity.x, p.velocity.y, p.velocity.z, p.ground_normal.x, p.ground_normal.y, p.ground_normal.z, p.target])

func clear() -> void:
	inp.clear()
	inp["move"] = Vector2.ZERO
	inp["yaw"] = 0.0

func place(pos: Vector3, yaw: float = 0.0) -> void:
	clear()
	inp["yaw"] = yaw
	p.teleport(pos)
	p.facing = Vector3(-sin(yaw), 0, -cos(yaw))
	p.boost = 100.0
	p.boost_locked = false
	p.invuln_t = 0.0
	p.rail_cool = 0.0
	Game.sparks = 50
	for i in 90:
		await get_tree().physics_frame
		if p.state == Player.St.GROUND:
			break
	await step(2)

func check(name: String, ok: bool, detail: String = "") -> void:
	total += 1
	if not ok:
		fails += 1
	print("%s  %-34s %s" % ["PASS" if ok else "FAIL", name, detail])

func fwd() -> void:
	inp["move"] = Vector2(0, 1)

func tap(action: String, frames: int = 2) -> void:
	inp[action] = true
	await step(frames)
	inp[action] = false

# ---------------------------------------------------------------- tests

func t_run() -> void:
	await place(Vector3(0, 0.6, 0))
	fwd()
	var t20 := -1.0
	var t5 := -1.0
	for i in 240:
		await step(1)
		if t5 < 0.0 and p.speed() >= 5.0:
			t5 = i / 60.0
		if t20 < 0.0 and p.speed() >= 20.0:
			t20 = i / 60.0
	check("run: responsive start", t5 >= 0.0 and t5 < 0.2, "5 m/s in %.2fs" % t5)
	check("run: reaches 20 m/s quickly", t20 > 0.0 and t20 < 1.2, "%.2fs" % t20)
	check("run: top speed", absf(p.speed() - Player.TOP_RUN) < 1.0, "%.1f m/s" % p.speed())
	check("run: straight line", absf(p.global_position.x) < 0.2, "x=%.2f" % p.global_position.x)
	inp["move"] = Vector2.ZERO
	var frames := 0
	while p.speed() > 0.1 and frames < 300:
		await step(1)
		frames += 1
	check("run: smooth stop", frames > 40 and frames < 150, "%.2fs" % (frames / 60.0))

func t_turn() -> void:
	await place(Vector3(0, 0.6, 0))
	fwd()
	await step(200)
	var d0 := p.velocity.normalized()
	inp["move"] = Vector2(1, 0)
	await step(36)
	var ang := rad_to_deg(d0.angle_to(p.velocity.normalized()))
	check("turn: keeps momentum", p.speed() > 25.0, "%.1f m/s after %.0f deg" % [p.speed(), ang])
	check("turn: steers at speed", ang > 60.0, "%.0f deg in 0.6s" % ang)
	inp["move"] = Vector2(-1, 0)
	await step(8)
	check("turn: reversal skids", p.skidding, "")
	# low speed precision
	await place(Vector3(0, 0.6, 0))
	inp["move"] = Vector2(1, 0)
	await step(12)
	var v := p.velocity.normalized()
	check("turn: low speed is direct", v.x > 0.97, "dir.x=%.2f" % v.x)

func t_boost() -> void:
	await place(Vector3(12, 0.6, 0))
	fwd()
	inp["boost"] = true
	await step(6)
	check("boost: instant kick", p.speed() >= 40.0, "%.1f m/s" % p.speed())
	await step(50)
	check("boost: top speed", absf(p.speed() - Player.BOOST_SPEED) < 1.0, "%.1f m/s" % p.speed())
	check("boost: meter drains", p.boost < 90.0, "%.0f" % p.boost)
	await step(60 * 4 + 20)
	check("boost: runs out", not p.boosting and p.boost < 1.0, "meter %.0f" % p.boost)
	inp["boost"] = false
	await step(60 * 3)
	check("boost: meter recharges", p.boost > 20.0, "%.0f" % p.boost)

func t_jump() -> void:
	await place(Vector3(0, 0.6, 0))
	inp["jump"] = true
	var top := 0.0
	for i in 70:
		await step(1)
		top = maxf(top, p.global_position.y)
	inp["jump"] = false
	var expect := 0.5 + Player.JUMP_V * Player.JUMP_V / (2.0 * Player.GRAVITY)
	check("jump: full height", absf(top - expect) < 0.4, "%.2f m (expect %.2f)" % [top, expect])
	check("jump: lands", p.state == Player.St.GROUND, "")
	await step(5)
	await tap("jump", 2)
	top = 0.0
	for i in 60:
		await step(1)
		top = maxf(top, p.global_position.y)
	check("jump: short hop", top < expect * 0.62, "%.2f m" % top)
	# double jump
	await tap("jump", 20)
	await step(2)
	await tap("jump", 3)
	check("jump: double jump", p.velocity.y > 10.0, "vy=%.1f" % p.velocity.y)
	await step(80)

func t_jump_momentum() -> void:
	await place(Vector3(0, 0.6, 0))
	fwd()
	await step(200)
	inp["jump"] = true
	await step(3)
	var min_h := 999.0
	while p.state == Player.St.AIR:
		await step(1)
		min_h = minf(min_h, p.hspeed())
	inp["jump"] = false
	check("jump: keeps horizontal speed", min_h > 31.0, "min %.1f m/s" % min_h)
	check("jump: speed kept on landing", p.speed() > 31.0, "%.1f m/s" % p.speed())
	# air steering
	await place(Vector3(0, 0.6, 0))
	inp["jump"] = true
	inp["move"] = Vector2(1, 0)
	await step(30)
	check("jump: air control from standstill", p.velocity.x > 6.0, "vx=%.1f" % p.velocity.x)
	await step(60)

func t_coyote() -> void:
	await place(Vector3(-160, 4.6, -36))
	fwd()
	while p.state == Player.St.GROUND and p.global_position.z > -60:
		await step(1)
	await step(4)
	await tap("jump", 3)
	check("coyote: late jump works", p.velocity.y > 10.0 and p.ball, "vy=%.1f" % p.velocity.y)
	await step(90)

func t_buffer() -> void:
	await place(Vector3(0, 0.6, 0))
	await tap("jump", 30)
	while p.global_position.y > 1.6 or p.velocity.y > 0.0:
		await step(1)
	inp["jump"] = true      # pressed ~5 frames before touchdown
	var jumped := false
	for i in 16:
		await step(1)
		if p.velocity.y > 12.0:
			jumped = true
	inp["jump"] = false
	check("buffer: early press still jumps", jumped, "")
	await step(80)

func t_slopes() -> void:
	for lane in [[-50.0, 15.0, false], [-30.0, 30.0, false], [-30.0, 30.0, true], [-70.0, 45.0, false]]:
		var x: float = lane[0]
		await place(Vector3(x, 0.6, 20))
		fwd()
		inp["boost"] = lane[2]
		var pre := 0.0
		var min_s := 999.0
		var air := 0
		var max_y := 0.0
		for i in 400:
			await step(1)
			var z := p.global_position.z
			if z > -39.0:
				pre = p.speed()
			elif z > -62.0:
				min_s = minf(min_s, p.speed())
				if p.state != Player.St.GROUND:
					air += 1
			max_y = maxf(max_y, p.global_position.y)
			if z < -75.0:
				break
		var tag := "slope %d%s" % [int(lane[1]), " boost" if lane[2] else ""]
		check(tag + ": no speed loss at seam", min_s > pre * 0.8, "%.1f -> min %.1f" % [pre, min_s])
		check(tag + ": stays grounded", air == 0, "%d air frames" % air)
		check(tag + ": climbs", max_y > 7.5, "y=%.1f" % max_y)

func t_bumps() -> void:
	await place(Vector3(-100, 0.6, 0))
	fwd()
	inp["boost"] = true
	var air := 0
	var min_s := 999.0
	var n := 0
	while p.global_position.z > -125.0 and n < 400:
		await step(1)
		n += 1
		if p.global_position.z < -32.0:
			min_s = minf(min_s, p.speed())
			if p.state != Player.St.GROUND:
				air += 1
	check("bumps: momentum kept", min_s > 49.0, "min %.1f m/s" % min_s)
	check("bumps: no bouncing off", air <= 2, "%d air frames" % air)
	check("bumps: stayed on lane", absf(p.global_position.x + 100.0) < 1.0, "")

func t_hills() -> void:
	await place(Vector3(-130, 0.6, 0))
	fwd()
	var air := 0
	var min_s := 999.0
	var max_s := 0.0
	var n := 0
	while p.global_position.z > -200.0 and n < 600:
		await step(1)
		n += 1
		if p.global_position.z < -40.0:
			min_s = minf(min_s, p.speed())
			max_s = maxf(max_s, p.speed())
			if p.state != Player.St.GROUND:
				air += 1
	check("hills: follows terrain", air <= 3, "%d air frames" % air)
	check("hills: slope momentum", max_s > Player.TOP_RUN + 1.5 and min_s > 20.0, "min %.1f max %.1f" % [min_s, max_s])

func t_loop() -> void:
	await place(Vector3(30, 0.6, -5))
	fwd()
	var max_y := 0.0
	var min_s := 999.0
	var air := 0
	for i in 320:
		await step(1)
		max_y = maxf(max_y, p.global_position.y)
		if p.global_position.y > 1.5:
			min_s = minf(min_s, p.speed())
			if p.state != Player.St.GROUND:
				air += 1
		if p.global_position.z < -75.0:
			break
	check("loop: reaches the top", max_y > TestArena.LOOP_R * 2.0 - 1.5, "max y %.1f" % max_y)
	check("loop: sticks all the way", air == 0, "%d air frames" % air)
	check("loop: exits on the far lane", p.global_position.z < -70.0 and absf(p.global_position.x - 38.0) < 3.0 and p.state == Player.St.GROUND, "pos %s" % p.global_position)
	check("loop: carries speed", min_s > 25.0, "min %.1f m/s" % min_s)
	# too slow: must fall off rather than stick to the ceiling
	await place(Vector3(30, 0.6, -40))
	p.velocity = Vector3(0, 0, -17)
	await step(150)
	check("loop: slow entry falls back", p.global_position.y < 3.0, "y=%.1f" % p.global_position.y)

func t_spindash() -> void:
	await place(Vector3(0, 0.6, 0))
	inp["spin"] = true
	await step(60)
	check("spin: charging holds position", p.state == Player.St.CHARGE and p.global_position.length() < 1.5, "")
	inp["spin"] = false
	await step(3)
	var launch := p.speed()
	check("spin: full charge launch", launch > 58.0 and p.rolling, "%.1f m/s" % launch)
	await step(60)
	check("spin: roll holds speed", p.speed() > launch - 6.0, "%.1f m/s after 1s" % p.speed())
	check("spin: beats boost distance", p.global_position.z < -55.0, "z=%.1f" % p.global_position.z)
	await place(Vector3(0, 0.6, 0))
	await tap("spin", 6)
	await step(2)
	check("spin: quick tap launch", p.speed() > 34.0 and p.speed() < 45.0, "%.1f m/s" % p.speed())

func t_roll_downhill() -> void:
	await place(Vector3(-30, 18.2, -85), PI)
	await tap("spin", 4)
	await step(2)
	var v0 := p.speed()
	var max_s := 0.0
	for i in 120:
		await step(1)
		max_s = maxf(max_s, p.speed())
		if p.global_position.z > -30.0:
			break
	check("roll: gains speed downhill", max_s > v0 + 8.0, "%.1f -> %.1f m/s" % [v0, max_s])
	check("roll: reaches the bottom", p.global_position.y < 1.5 and p.state == Player.St.GROUND, "y=%.1f" % p.global_position.y)

func t_spring_homing_chain() -> void:
	await place(Vector3(90, 0.6, -18))
	fwd()
	var top := 0.0
	var hits := 0
	var saw_target := false
	for i in 420:
		await step(1)
		top = maxf(top, p.global_position.y)
		if p.state == Player.St.AIR and p.target != null and p.lock_t <= 0.0:
			saw_target = true
			inp["attack"] = not inp.get("attack", false)
		else:
			inp["attack"] = false
		hits = 0
		for o in arena.orbs:
			if not o.homing_enabled:
				hits += 1
		if hits == 3:
			break
	inp["attack"] = false
	check("spring: launch height", top > 11.5, "apex %.1f m" % top)
	check("homing: target acquired", saw_target, "")
	check("homing: chained 3 orbs", hits == 3, "%d hit" % hits)
	for i in 120:
		await step(1)
		if p.state == Player.St.GROUND:
			break
	check("homing: lands on the far platform", p.state == Player.St.GROUND and p.global_position.y > 10.0, "pos %s" % p.global_position)
	inp["move"] = Vector2.ZERO
	await step(170)

func t_los() -> void:
	await place(Vector3(180, 0.6, -30))
	inp["jump"] = true
	var seen := false
	for i in 50:
		await step(1)
		if p.target == arena.los_orb:
			seen = true
	inp["jump"] = false
	check("homing: blocked by walls", not seen, "")
	await place(Vector3(180, 0.6, -50), PI)
	await tap("jump", 12)
	check("homing: visible from open side", p.target == arena.los_orb, "")
	await step(60)

func t_rail() -> void:
	await place(Vector3(120, 0.6, -12))
	fwd()
	var attached := false
	var max_y := 0.0
	var frames := 0
	for i in 600:
		await step(1)
		if p.state == Player.St.GRIND:
			attached = true
			frames += 1
			inp["move"] = Vector2.ZERO
			max_y = maxf(max_y, p.global_position.y)
		elif attached:
			break
	check("rail: attaches when run onto", attached, "")
	check("rail: follows the curve", max_y > 8.0, "max y %.1f" % max_y)
	check("rail: exits at the end with speed", p.global_position.z < -145.0 and p.hspeed() > 14.0, "z=%.1f %.1f m/s" % [p.global_position.z, p.hspeed()])
	await step(60)

func t_rail_jump() -> void:
	await place(Vector3(120, 0.6, -12))
	fwd()
	inp["boost"] = true
	for i in 300:
		await step(1)
		if p.state == Player.St.GRIND and p.global_position.z < -55.0:
			break
	var gs := absf(p.rail_speed)
	check("rail: boost accelerates the grind", gs > 40.0, "%.1f m/s" % gs)
	inp["boost"] = false
	await tap("jump", 3)
	check("rail: jump off keeps momentum", p.state == Player.St.AIR and p.velocity.y > 8.0 and p.hspeed() > gs * 0.8, "vy %.1f h %.1f" % [p.velocity.y, p.hspeed()])
	# landing on a rail from the air
	await place(Vector3(120, 0.6, -40))
	p.teleport(arena.test_rail.sample(36.0) + Vector3(0.5, 5, 2))
	p.velocity = Vector3(0, 0, -8)
	await step(50)
	check("rail: lands onto rail from above", p.state == Player.St.GRIND, "state %d" % p.state)
	await step(200)

func t_stomp() -> void:
	await place(Vector3(0, 0.6, 0))
	p.teleport(Vector3(-20, 14, 42.5))
	await step(3)
	await tap("stomp", 2)
	check("stomp: dives", p.state == Player.St.STOMP and p.velocity.y < -50.0, "")
	await step(30)
	check("stomp: lands cleanly", p.state == Player.St.GROUND and p.global_position.y < 1.2 and p.global_position.y > 0.3, "y=%.2f" % p.global_position.y)
	check("stomp: presses switch", arena.test_switch.on and arena.test_gate.opened, "")

func t_wall() -> void:
	await place(Vector3(0, 0.6, -200))
	fwd()
	inp["boost"] = true
	p.velocity = Vector3(0, 0, -Player.MAX_SPEED)
	await step(90)
	check("wall: no tunnelling at max speed", p.global_position.z > -298.6 and p.global_position.y > 0.3, "z=%.2f" % p.global_position.z)
	# straight down at terminal velocity
	p.teleport(Vector3(10, 120, -100))
	await step(3)
	await tap("stomp", 2)
	await step(200)
	check("wall: no falling through floor", p.global_position.y > 0.3 and p.state == Player.St.GROUND, "y=%.2f" % p.global_position.y)

func t_breakable() -> void:
	await place(Vector3(150, 0.6, -40))
	fwd()
	await step(150)
	check("breakable: stops a normal run", is_instance_valid(arena.test_wall) and p.global_position.z > -80.0, "z=%.1f" % p.global_position.z)
	await place(Vector3(150, 0.6, -30))
	inp["spin"] = true
	await step(50)
	inp["spin"] = false
	await step(60)
	check("breakable: spin dash smashes through", not is_instance_valid(arena.test_wall) and p.global_position.z < -85.0 and p.speed() > 40.0, "z=%.1f %.1f m/s" % [p.global_position.z, p.speed()])

func t_hoops() -> void:
	await place(Vector3(210, 0.6, -18))
	fwd()
	var max_s := 0.0
	for i in 300:
		await step(1)
		if p.state == Player.St.AIR:
			inp["move"] = Vector2.ZERO
		max_s = maxf(max_s, p.speed())
		if p.global_position.z < -112.0:
			break
	check("hoops: spring -> hoop -> hoop chain", p.global_position.z < -112.0 and p.global_position.y > 4.0 and max_s > 45.0, "pos %s" % p.global_position)
	await step(120)

func t_hurt() -> void:
	await place(Vector3(0, 0.6, 0))
	Game.sparks = 10
	p.hurt(p.global_position + Vector3(0, 0, -1))
	await step(2)
	check("hurt: knockback + spark loss", Game.sparks == 0 and p.velocity.z > 5.0 and p.invuln_t > 1.0, "")
	check("hurt: invulnerable after hit", not p.hurt(p.global_position), "")
	await step(60)
	p.teleport(Vector3(0, -70, 0))
	await step(3)
	check("recovery: falling out respawns", p.global_position.y > -5.0, "y=%.1f" % p.global_position.y)

func _home_in(frames: int = 90) -> void:
	inp["jump"] = true
	for i in frames:
		await step(1)
		if p.state == Player.St.AIR and p.target != null:
			inp["attack"] = not inp.get("attack", false)
		else:
			inp["attack"] = false
	inp["jump"] = false
	inp["attack"] = false

func t_grunt() -> void:
	var g := arena.test_grunt
	await place(Vector3(-200, 0.6, -24))
	Game.sparks = 0
	Game.add_sparks(10)
	await _home_in(40)
	check("grunt: homing attack defeats it", not g.alive and Game.sparks > 10, "sparks %d" % Game.sparks)
	g.on_player_respawn()
	await place(Vector3(-200, 0.6, -30))
	var hurt := false
	for i in 400:
		await step(1)
		if p.invuln_t > 0.5:
			hurt = true
			break
	check("grunt: telegraphs then rams an idle player", hurt and g.alive, "")
	await step(150)
	# spin dash straight through it
	g.on_player_respawn()
	await place(g.global_position + Vector3(0, 0, 18))
	inp["spin"] = true
	await step(30)
	inp["spin"] = false
	await step(40)
	check("grunt: spin dash bowls it over", not g.alive, "")
	g.on_player_respawn()

func t_turret() -> void:
	var tr := arena.test_turret
	await place(Vector3(-230, 0.6, -14))
	Game.sparks = 20
	var hurt := false
	for i in 500:
		await step(1)
		if p.invuln_t > 0.5:
			hurt = true
			break
	check("turret: shoots a stationary player", hurt, "")
	# a moving player is not hit: strafe across its line of fire
	await step(140)
	await place(Vector3(-215, 0.6, -14))
	Game.sparks = 20
	var dodged := true
	for i in 480:
		await step(1)
		inp["move"] = Vector2(1 if (i / 120) % 2 == 0 else -1, 0)
		if p.invuln_t > 0.5:
			dodged = false
	check("turret: shots can be outrun", dodged, "")
	await place(Vector3(-230, 0.6, -26))
	await _home_in(50)
	check("turret: homing attack destroys it", not tr.alive, "")

func t_bulwark() -> void:
	var b := arena.test_bulwark
	b.on_player_respawn()
	await place(Vector3(-260, 0.6, -52), PI)
	Game.sparks = 20
	inp["jump"] = true
	var thrown := false
	for i in 40:
		await step(1)
		inp["attack"] = p.state == Player.St.AIR and p.target != null and not inp.get("attack", false)
		if p.velocity.z < -8.0:
			thrown = true
	inp["jump"] = false
	inp["attack"] = false
	check("bulwark: shield deflects a frontal attack", b.alive and b.hp == 2 and thrown, "hp %d" % b.hp)
	await step(60)
	# stomp beside it to break the shield, then strike twice
	p.teleport(b.global_position + Vector3(3.5, 9, 0))
	await step(2)
	await tap("stomp", 2)
	await step(25)
	check("bulwark: stomp shockwave stuns it", b.stun > 3.0 and not b.shield.visible, "")
	for k in 2:
		await _home_in(45)
		await step(20)
	check("bulwark: falls once the shield is down", not b.alive, "hp %d" % b.hp)
	# or simply get behind it
	b.on_player_respawn()
	await place(b.global_position + Vector3(0, -1.0, 14))
	await _home_in(40)
	check("bulwark: vulnerable from behind", b.hp < 2, "hp %d" % b.hp)
