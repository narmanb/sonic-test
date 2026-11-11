extends Node
## Island verification: terrain integrity, every aimed spring / hoop / rail,
## and bot playthroughs of each challenge, puzzle and the Guardian fight.
## Run:  godot --headless --fixed-fps 60 --path game -- --test-island

var p: Player
var w: Island
var inp := {}
var fails := 0
var total := 0
var trace := false
var _tc := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await step(5)
	p = Game.player
	w = Game.world
	Controls.override = inp
	clear()
	var names: Array = ["terrain", "tokens", "springs", "hoops", "rails", "sweeps", "loop", "rail_rush", "lantern",
			"peak_orbs", "sky_orbs", "hollow", "stack", "trial", "beacons", "vault", "guardian"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			names = Array(a.trim_prefix("--only=").split(","))
		if a == "--trace":
			trace = true
	for t in names:
		await call("t_" + t)
	print("\n==== %d checks, %d failed ====" % [total, fails])
	Game.reset_progress()
	get_tree().quit(1 if fails > 0 else 0)

func step(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		_tc += 1
		Game.sparks = maxi(Game.sparks, 30)
		if trace and p != null and _tc % 6 == 0:
			print("  f%d st=%d pos=(%.1f,%.1f,%.1f) v=(%.1f,%.1f,%.1f) tgt=%s" % [_tc, p.state, p.global_position.x, p.global_position.y, p.global_position.z, p.velocity.x, p.velocity.y, p.velocity.z, p.target])

func clear() -> void:
	inp.clear()
	inp["move"] = Vector2.ZERO
	inp["yaw"] = 0.0

func put(pos: Vector3) -> void:
	clear()
	p.teleport(pos)
	p.boost = 100.0
	p.boost_locked = false
	p.invuln_t = 0.0
	p.rail_cool = 0.0
	p.ignore_t = 0.0
	await step(2)

func settle() -> void:
	for i in 120:
		await step(1)
		if p.state == Player.St.GROUND:
			break

func check(name: String, ok: bool, detail: String = "") -> void:
	total += 1
	if not ok:
		fails += 1
	print("%s  %-36s %s" % ["PASS" if ok else "FAIL", name, detail])

func steer(to: Vector3) -> void:
	var d := to - p.global_position
	inp["yaw"] = atan2(-d.x, -d.z)
	inp["move"] = Vector2(0, 1)

## Presses attack on alternating frames whenever a homing target is offered.
func attack_pulse() -> void:
	if p.target != null and not (p.target is Spring) and p.state == Player.St.AIR and p.lock_t <= 0.0:
		inp["attack"] = not inp.get("attack", false)
	else:
		inp["attack"] = false

# ---------------------------------------------------------------- tests

func t_terrain() -> void:
	var space := w.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var worst := 0.0
	var misses := 0
	for i in 400:
		var x := rng.randf_range(-600, 600)
		var z := rng.randf_range(-600, 600)
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 400, z), Vector3(x, -50, z), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			misses += 1
		elif (hit.collider as Node).get_parent() == w.T:
			worst = maxf(worst, absf((hit.position as Vector3).y - w.T.h(x, z)))
	check("terrain: collision matches heightmap", misses == 0 and worst < 0.9, "worst %.2f m, %d misses" % [worst, misses])

func t_tokens() -> void:
	var n := 0
	var bad := ""
	for c in w.get_children():
		if c is Token:
			n += 1
			var gp: Vector3 = c.global_position
			if gp.y < w.T.h(gp.x, gp.z) + 1.0:
				bad += c.id + " "
	check("tokens: 9 placed + 1 trial reward", n == 9, "%d" % n)
	check("tokens: none buried", bad == "", bad)

func t_springs() -> void:
	for pair in w.spring_checks:
		var sp: Spring = pair[0]
		var to: Vector3 = pair[1]
		await put(sp.global_position + Vector3(0, 0.6, 0))
		var best := 999.0
		for i in 260:
			await step(1)
			best = minf(best, p.global_position.distance_to(to))
			if p.state == Player.St.GROUND and i > 20:
				break
		check("spring -> (%d,%d,%d)" % [to.x, to.y, to.z], best < 2.5, "closest %.1f m" % best)

func t_hoops() -> void:
	for pair in w.hoop_checks:
		var hp: Hoop = pair[0]
		var to: Vector3 = pair[1]
		await put(hp.global_position + Vector3(0, 0.3, 0))
		var best := 999.0
		for i in 200:
			await step(1)
			best = minf(best, p.global_position.distance_to(to))
			if p.state == Player.St.GROUND:
				break
		check("hoop -> (%d,%d,%d)" % [to.x, to.y, to.z], best < 3.0, "closest %.1f m" % best)

func t_rails() -> void:
	var i := 0
	for r in get_tree().get_nodes_in_group("rails"):
		i += 1
		var low := 999.0
		var off := 4.0
		while off < r.length - 4.0:
			var s: Vector3 = r.sample(off)
			low = minf(low, s.y - w.T.h(s.x, s.z))
			off += 3.0
		check("rail %d: clear of the ground" % i, low > 0.5, "min clearance %.1f m" % low)
		clear()
		p.teleport(r.sample(3.0) + Vector3(0, 1.5, 0))
		p.rail_cool = 0.0
		p.velocity = r.tangent(3.0) * 20.0
		p.facing = r.tangent(3.0)
		var rode := 0
		for k in 1500:
			await step(1)
			if p.state == Player.St.GRIND:
				rode += 1
			elif rode > 0:
				break
		var ended: Vector3 = r.sample(r.length)
		check("rail %d: rides start to end" % i, rode > 30 and p.global_position.distance_to(ended) < 12.0, "%d frames, %.1f m from end" % [rode, p.global_position.distance_to(ended)])

func t_sweeps() -> void:
	# boost in straight lines across the island; never clip under the terrain
	var worst := 99.0
	var stuck := 0
	for run in [[Vector3(0, 0, 380), 0.0], [Vector3(-150, 0, 100), -1.2], [Vector3(150, 0, 150), 2.4], [Vector3(-100, 0, -100), 0.8],
			[Vector3(250, 0, -80), 1.6], [Vector3(-330, 0, 100), 3.1], [Vector3(40, 0, -120), 0.1], [Vector3(-200, 0, 280), -2.0]]:
		var s: Vector3 = run[0]
		await put(w.g(s.x, s.z, 1.0))
		await settle()
		inp["yaw"] = run[1]
		inp["move"] = Vector2(0, 1)
		inp["boost"] = true
		for i in 600:
			await step(1)
			p.boost = 100.0
			var gp := p.global_position
			if gp.y > 0.0:
				worst = minf(worst, gp.y - w.T.h(gp.x, gp.z))
		if p.speed() < 1.0 and p.state == Player.St.GROUND:
			stuck += 1
	check("sweeps: never below the terrain", worst > -0.6, "min height above ground %.2f" % worst)
	check("sweeps: recovers from the sea", p.global_position.y > -2.0, "")

func t_loop() -> void:
	await put(w.g(-50, 234, 1.0))
	await settle()
	inp["yaw"] = -PI * 0.5
	inp["move"] = Vector2(0, 1)
	var top := 0.0
	var base_y := w.T.h(0, 234)
	for i in 300:
		await step(1)
		top = maxf(top, p.global_position.y - base_y)
		if p.global_position.x > 40.0:
			break
	check("speedway loop: completes", top > 17.0 and p.global_position.x > 40.0 and p.state == Player.St.GROUND, "rise %.1f x=%.1f" % [top, p.global_position.x])

func t_rail_rush() -> void:
	var a: Vector3 = w.refs["rail_rush_start"]
	await put(a + Vector3(6, 1.0, 0))
	await settle()
	inp["yaw"] = PI * 0.5
	inp["move"] = Vector2(0, 1)
	var grinds := 0
	var was := false
	for i in 2400:
		await step(1)
		var gnow := p.state == Player.St.GRIND
		if gnow and not was:
			grinds += 1
		was = gnow
		if grinds > 0:
			inp["move"] = Vector2.ZERO
		if Game.tokens.has("c1_rails"):
			break
	check("rail rush: rides all three rails", grinds >= 3, "%d grinds" % grinds)
	check("rail rush: token collected hands-free", Game.tokens.has("c1_rails"), "pos %s" % p.global_position)

func t_lantern() -> void:
	var sp: Spring = w.refs["lantern_spring"]
	await put(sp.global_position + Vector3(0, 0.6, 0))
	for i in 1500:
		await step(1)
		attack_pulse()
		steer(w.g(Terrain.ISLET.x, Terrain.ISLET.y, 2.0))
		if p.state == Player.St.GROUND and p.global_position.x > Terrain.ISLET.x - 24.0:
			break
	check("lantern hop: crosses to the islet", Game.tokens.has("c3_lantern") or p.global_position.x > Terrain.ISLET.x - 24.0, "pos %s" % p.global_position)
	for i in 240:
		await step(1)
		steer(w.g(Terrain.ISLET.x, Terrain.ISLET.y, 2.0))
		if Game.tokens.has("c3_lantern"):
			break
	check("lantern hop: token", Game.tokens.has("c3_lantern"), "")

func t_peak_orbs() -> void:
	var sp: Spring = w.refs["peak_orb_spring"]
	var st: Array = w.refs["peak_stations"]
	await put(sp.global_position + Vector3(0, 0.6, 0))
	var goal: Vector3 = st[2]
	for i in 600:
		await step(1)
		attack_pulse()
		steer(goal)
		if p.state == Player.St.GROUND and p.global_position.distance_to(goal) < 7.0:
			break
	check("peak: lantern hop reaches next ledge", p.global_position.distance_to(goal) < 7.0, "dist %.1f" % p.global_position.distance_to(goal))

func t_sky_orbs() -> void:
	var sp: Spring = w.refs["sky_spring"]
	var top: Vector3 = w.refs["sky_top"]
	await put(sp.global_position + Vector3(0, 0.6, 0))
	for i in 900:
		await step(1)
		attack_pulse()
		steer(top)
		if Game.tokens.has("c5_sky"):
			break
	check("sky garden: lantern spiral to the crown", Game.tokens.has("c5_sky"), "pos %s" % p.global_position)

func t_hollow() -> void:
	var m: Vector3 = w.refs["pass_mouth"]
	var cove := w.g(Terrain.COVE.x, Terrain.COVE.y, 1.0)
	await put(m)
	await settle()
	steer(cove)
	await step(240)
	check("hollow pass: wall stops a plain run", not Game.tokens.has("c6_hollow") and p.global_position.distance_to(cove) > 90.0, "dist %.0f" % p.global_position.distance_to(cove))
	await put(m)
	await settle()
	steer(cove)
	inp["spin"] = true
	await step(50)
	inp["spin"] = false
	for i in 900:
		await step(1)
		steer(cove)
		if Game.tokens.has("c6_hollow"):
			break
	check("hollow pass: spin dash breaks through to the cove", Game.tokens.has("c6_hollow"), "pos %s" % p.global_position)

func t_stack() -> void:
	var sp: Spring = w.refs["stack_spring"]
	await put(sp.global_position + Vector3(0, 0.6, 0))
	for i in 600:
		await step(1)
		if Game.tokens.has("h2_stack"):
			break
	check("sea stack: spring + hoop lands the token", Game.tokens.has("h2_stack"), "pos %s" % p.global_position)

func t_trial() -> void:
	var tt: TimeTrial = w.refs["trial"]
	var first: Vector3 = tt.points[0]
	await put(first + Vector3(-14, 1.0, 0))
	await settle()
	for i in 1500:
		await step(1)
		var goal: Vector3 = tt.points[tt.idx] if tt.running else first
		steer(goal)
		inp["boost"] = tt.running
		if Game.tokens.has("c4_trial"):
			break
	check("ruins dash: beatable with boost", Game.tokens.has("c4_trial"), "t=%.1f idx=%d" % [tt.t, tt.idx])
	# and a no-boost run should be too slow to trivialise it
	Game.tokens.erase("c4_trial")
	await put(first + Vector3(-14, 1.0, 0))
	await settle()
	for i in 1500:
		await step(1)
		steer(tt.points[tt.idx] if tt.running else first)
		if Game.tokens.has("c4_trial") or (not tt.running and i > 300):
			break
	print("INFO  ruins dash without boost: %s" % ("cleared" if Game.tokens.has("c4_trial") else "timed out"))
	Game.tokens["c4_trial"] = true

func t_beacons() -> void:
	var sws: Array = w.refs["beacons"]
	# a real run between the three beacons, boosting
	await put((sws[0] as Node3D).global_position + Vector3(6, 1.5, 0))
	await settle()
	var t := 0
	for k in 3:
		var goal: Vector3 = (sws[k] as Node3D).global_position
		for i in 1800:
			await step(1)
			t += 1
			steer(goal)
			inp["boost"] = true
			if sws[k].on:
				break
	check("beacons: all three lit in one run", Game.has_flag("p1_beacons"), "%.1fs of %.0fs allowed" % [t / 60.0, sws[0].hold_time])

func t_vault() -> void:
	var sws: Array = w.refs["vault_switches"]
	for sw in sws:
		await put((sw as Node3D).global_position + Vector3(0.5, 8.0, 0.5))
		await step(3)
		inp["stomp"] = true
		await step(2)
		inp["stomp"] = false
		await step(40)
	check("vault: stomping both pillar switches opens it", Game.has_flag("p2_vault"), "")

func t_guardian() -> void:
	var gd: Guardian = w.refs["guardian"]
	for i in 6:
		Game.tokens["fake%d" % i] = true
	await put(gd.centre + Vector3(30, 1.5, 30))
	await settle()
	var woke := false
	var frames := 0
	for i in 60 * 240:
		await step(1)
		frames += 1
		if gd.mode != Guardian.DORMANT:
			woke = true
		if gd.mode == Guardian.DEAD:
			break
		# simple bot: circle the arena, hop shockwaves, strike when the core is exposed
		var rel := p.global_position - gd.centre
		rel.y = 0
		var tangent := Vector3(-rel.z, 0, rel.x).normalized()
		var ring := gd.centre + rel.normalized() * 28.0 + tangent * 12.0
		inp["jump"] = false
		if gd.mode == Guardian.EXPOSED:
			steer(gd.global_position)
			if p.state == Player.St.GROUND and p.global_position.distance_to(gd.global_position) < 20.0:
				inp["jump"] = true
			attack_pulse()
		else:
			inp["attack"] = false
			steer(ring)
			for wv in gd.waves:
				if absf(rel.length() - wv[1]) < 5.0 and p.state == Player.St.GROUND:
					inp["jump"] = true
	check("guardian: wakes with enough cores", woke, "")
	check("guardian: can be defeated", gd.mode == Guardian.DEAD and Game.has_flag("guardian_defeated"), "%.0fs, hp %d" % [frames / 60.0, gd.hp])
