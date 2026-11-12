class_name IslandAreas
## Hand-placed content for Aurora Isle. Each function dresses one district:
## its landmark, its traversal challenge and its residents.
##
## Compass: north = -Z, east = +X. Heights always come from the terrain.

static func yaw_of(dx: float, dz: float) -> float:
	return atan2(-dx, -dz)

static func build_all(w: Island) -> void:
	start_shore(w)
	speedway(w)
	spire(w)
	peak(w)
	cliffs(w)
	ruins(w)
	lantern_reach(w)
	sky_garden(w)
	hollow_pass(w)
	sea_stack(w)
	basin(w)
	wanderers(w)

# ------------------------------------------------------------ Landing Shore

static func start_shore(w: Island) -> void:
	var s := Terrain.START
	w.clear_zone(s, 34.0)
	w.place_name("Landing Shore", s, 55.0)
	Checkpoint.make(w, w.g(0, 400), "shore")
	# a weathered pier reaching into the bay
	for i in 9:
		var z := 446.0 + i * 6.0
		Build.box(w, Vector3(0, 1.3, z), Vector3(5.0, 0.4, 5.8), w.m_wood)
		if i % 2 == 0:
			for sx in [-2.3, 2.3]:
				Build.cyl(w, Vector3(sx, 0.2, z), 0.25, 4.0, w.m_wood, false, -1.0, 6)
	w.sparks.add_line(Vector3(0, 2.6, 450), Vector3(0, 2.6, 494), 8)
	w.hint(w.g(0, 412, 1), 14.0, "Welcome to Aurora Isle. Follow the sparks north!", 5.0)
	w.hint(w.g(0, 375, 1), 9.0, "Hold BOOST to blast forward. Sparks refill the gauge.", 5.0)
	w.spark_trail(Vector2(0, 392), Vector2(0, 268), 24)
	DashPad.make(w, w.g(0, 352, 0.05), 0.0, 48.0)
	# first taste of the homing attack: a spring and lanterns up to a lookout rock
	var rock := w.g(26, 322) + Vector3(0, 11, 0)
	Build.cyl(w, rock - Vector3(0, 6.0, 0), 5.5, 12.0, w.m_rock, true, 4.2, 9)
	Build.cyl(w, rock + Vector3(0, 0.1, 0), 4.6, 0.3, w.m_grass, false, -1.0, 9)
	w.clear_zone(Vector2(26, 322), 9.0)
	Spring.make(w, w.g(10, 334, 0.05), 27.0)
	Orb.make(w, w.g(14, 331) + Vector3(0, 9.5, 0))
	Orb.make(w, w.g(20, 326) + Vector3(0, 12.0, 0))
	w.sparks.add_circle(rock + Vector3(0, 1.4, 0), 3.0, 8)
	w.hint(w.g(8, 338, 1), 8.0, "In the air, press ATTACK to home in on the marked target.", 5.0)
	w.hint(w.g(0, 290, 1), 9.0, "Hold SPIN to charge a Spin Dash. Release to launch and roll.", 5.0)

# ------------------------------------------------------------ Greenway speedway

static func speedway(w: Island) -> void:
	var c := Terrain.TRACK_C
	var r := Terrain.TRACK_R
	w.place_name("Greenway Plains", c, 120.0)
	# the track runs anticlockwise on the map: south -> east -> north -> west
	for a in [0.0, -PI * 0.5, PI, PI * 0.25, -PI * 0.75]:
		var pos := Vector2(c.x + cos(a) * r, c.y + sin(a) * r)
		var tan := Vector2(sin(a), -cos(a))
		DashPad.make(w, w.g(pos.x, pos.y, 0.05), yaw_of(tan.x, tan.y), 52.0)
	for seg in [[0.35, 0.05], [-0.25, -0.7], [-0.95, -1.4], [-1.75, -2.2], [3.0, 2.55], [2.2, 1.85]]:
		w.spark_ring_arc(c, r, seg[0], seg[1], 14)
	for a in [-PI * 0.25, -PI * 0.75, PI * 0.72]:
		var pos := Vector2(c.x + cos(a) * r, c.y + sin(a) * r)
		var tan := Vector2(sin(a), -cos(a))
		w.arch(pos.x, pos.y, yaw_of(tan.x, tan.y), 13.0, 11.0)
	# loop-the-loop on the southern straight
	var site := Terrain.LOOPSITE
	w.clear_zone(site, 50.0)
	var base := w.g(0, 234, 0.02)
	DashPad.make(w, w.g(-30, 234, 0.05), -PI * 0.5, 52.0)
	Build.loop(w, base, -PI * 0.5, 10.0, 7.0, 8.0, Build.mat(Color(0.8, 0.72, 0.5), 0.8))
	LoopGuide.make(w, base, -PI * 0.5, 10.0, 7.0, 8.0)
	w.sparks.add_circle(base + Vector3(10, 10, 4), 0.1, 1)
	for i in 8:
		var a := TAU * i / 8.0
		w.sparks.add(base + Vector3(sin(a) * 9.0, 10.0 - cos(a) * 9.0, 8.0 * i / 8.0))
	# standing stones mark two quiet corners of the plains
	for cc in [Vector2(-95, 135), Vector2(120, -45)]:
		w.clear_zone(cc, 16.0)
		for i in 7:
			var a := TAU * i / 7.0
			var p: Vector2 = cc + Vector2(cos(a), sin(a)) * 10.0
			Build.box(w, w.g(p.x, p.y, 2.2), Vector3(1.8, 6.0 + (i % 3), 1.2), w.m_stone2, Vector3(0.05 * (i % 3), -a, 0.06))
		w.sparks.add_circle(w.g(cc.x, cc.y, 1.2), 5.0, 8)
	# a long rail gliding from the ruins' rim over the track to the Spire's hill
	var rail_pts: Array = [w.g(232, 26, 13.0), w.g(190, 20, 16.0), w.g(130, 0, 15.0), w.g(70, -14, 10.0), w.g(34, -20, 2.0)]
	Rail.make(w, rail_pts, Color(0.4, 0.9, 1.0))
	Build.cyl(w, w.g(236, 27, 5.5), 3.2, 11.0, w.m_stone, true, 2.8, 8)
	w.clear_zone(Vector2(236, 27), 8.0)
	Spring.make(w, w.g(243, 30, 0.05), 30.0)
	for i in 10:
		var k := 0.1 + 0.8 * i / 9.0
		w.sparks.add((rail_pts[0] as Vector3).lerp(rail_pts[2], k * 0.5) + Vector3(0, 1.3, 0) if k < 0.5 else (rail_pts[2] as Vector3).lerp(rail_pts[4], (k - 0.5) * 2.0) + Vector3(0, 1.3, 0))

# ------------------------------------------------------------ Aurora Spire

static func spire(w: Island) -> void:
	var c := Terrain.SPIRE
	var base := w.g(c.x, c.y)
	w.clear_zone(c, 32.0)
	w.place_name("Aurora Spire", c, 45.0)
	Build.cyl(w, base + Vector3(0, 2.5, 0), 10.0, 5.0, w.m_stone2, true, 8.5, 12)
	Build.cyl(w, base + Vector3(0, 44.0, 0), 6.0, 78.0, w.m_stone, true, 4.0, 12)
	for i in 5:
		var tm := TorusMesh.new()
		var rr := lerpf(6.2, 4.4, i / 4.0)
		tm.inner_radius = rr
		tm.outer_radius = rr + 0.5
		tm.rings = 20
		tm.ring_segments = 5
		Build.visual(w, tm, w.m_glow, base + Vector3(0, 12.0 + i * 16.0, 0))
	Build.cyl(w, base + Vector3(0, 84.0, 0), 8.0, 1.5, w.m_stone2, true, -1.0, 12)
	var cs := SphereMesh.new()
	cs.radius = 3.0
	cs.height = 9.0
	cs.radial_segments = 6
	cs.rings = 2
	Build.visual(w, cs, Build.mat(Color(0.6, 0.45, 1.0), 0.2, 2.5), base + Vector3(0, 96.0, 0))
	w.beacon_light(base + Vector3(0, 100.0, 0), Color(0.6, 0.5, 1.0), 220.0)
	Checkpoint.make(w, w.g(18, 4), "spire")

	# the vault at its foot opens when three plains beacons are lit together
	var vz := c.y + 14.0
	for sx in [-1.0, 1.0]:
		Build.box(w, base + Vector3(sx * 4.2, 3.0, 13.5), Vector3(1.6, 7.0, 9.0), w.m_stone2)
	Build.box(w, base + Vector3(0, 7.0, 13.5), Vector3(10.0, 1.4, 9.0), w.m_stone)
	var gate := Gate.make(w, base + Vector3(0, 3.0, 17.4), 0.0, Vector3(6.8, 6.4, 1.0), w.m_dark)
	Token.make(w, Vector3(c.x, base.y + 2.2, vz - 1.0), "p1_beacons")
	if Game.has_flag("p1_beacons"):
		gate.open(true)
	var spots: Array = [Vector2(168, -66), Vector2(-150, -92), Vector2(14, 150)]
	var switches: Array = []
	for sp in spots:
		w.clear_zone(sp, 9.0)
		var p := w.g(sp.x, sp.y)
		Build.cyl(w, p + Vector3(0, -0.25, 0), 4.0, 0.8, w.m_stone2, true, -1.0, 10)
		for k in 3:
			var a := TAU * k / 3.0
			Build.cyl(w, p + Vector3(cos(a) * 3.3, 3.0, sin(a) * 3.3), 0.35, 6.0, w.m_stone, false, 0.2, 6)
		var sw := PressSwitch.make(w, p + Vector3(0, 0.15, 0), true, 36.0)
		var beam := w.beacon_light(p + Vector3(0, 1, 0), Color(0.3, 1.0, 0.7), 70.0)
		beam.visible = false
		switches.append(sw)
		sw.pressed_changed.connect(func(on):
			beam.visible = on
			if gate.opened:
				return
			var lit := 0
			for s2 in switches:
				if s2.on:
					lit += 1
			if on and lit < 3:
				Game.say("Beacon lit: %d / 3. Hurry before it fades!" % lit, 3.0)
			if lit == 3:
				gate.open()
				Game.set_flag("p1_beacons")
				Game.say("The Spire's vault grinds open!", 4.0)
				Sfx.play("win"))
	w.refs["beacons"] = switches
	w.hint(base + Vector3(0, 1, 24), 10.0, "Three beacons sleep on the plains. Wake them all before the first one fades.", 6.0)

# ------------------------------------------------------------ Stormcrown Peak

static func peak(w: Island) -> void:
	var pk := Terrain.PEAK
	w.place_name("Stormcrown Peak", pk, 135.0)
	w.clear_zone(pk, 26.0)
	# six ledges climb the south face
	var xs: Array = [60.0, 74.0, 54.0, 72.0, 56.0, 64.0]
	var zs: Array = [-160.0, -188.0, -216.0, -244.0, -272.0, -296.0]
	var st: Array = []
	for i in 6:
		# each ledge is flush with the slope at its back and juts out in front,
		# so everything standing on it is clear of the mountainside
		var x: float = xs[i]
		var z: float = zs[i]
		var top := -100.0
		for o in [Vector2(0, 0), Vector2(0, -5.5), Vector2(-5.5, -5.5), Vector2(5.5, -5.5), Vector2(-5.5, 0), Vector2(5.5, 0)]:
			top = maxf(top, w.T.h(x + o.x, z + o.y))
		var p := Vector3(x, top + 0.3, z)
		Build.box(w, p - Vector3(0, 8.0, 0), Vector3(11, 16.0, 11), w.m_stone)
		Build.box(w, p - Vector3(0, 0.05, 0), Vector3(9, 0.14, 9), w.m_stone2, Vector3.ZERO, false)
		w.clear_zone(Vector2(x, z), 10.0)
		st.append(p)
	var summit := w.g(60, -310) + Vector3(0, 0.6, 0)
	var front := Vector3(0, 0, 2.8)
	Checkpoint.make(w, st[0] + Vector3(0, 0, 4.0), "peak_base")
	w.hint(st[0] + Vector3(0, 1, 2), 7.0, "Cliff Climb: springs, lanterns and lifts lead to the summit.", 4.0)
	# 0 -> 1: aimed spring
	w.spring_to(st[0] + front, st[1] + front + Vector3(0, 0.8, 0), 2.1)
	w.sparks.add_arc(st[0] + front + Vector3(0, 4, 0), st[1] + front + Vector3(0, 3, 0), 9.0, 6)
	# 1 -> 2: hop three lanterns
	w.refs["peak_orb_spring"] = Spring.make(w, st[1] + Vector3(-2.5, 0.02, 3.0), 25.0)
	w.refs["peak_stations"] = st
	for k in [0.3, 0.6, 0.9]:
		Orb.make(w, ((st[1] as Vector3) + front).lerp((st[2] as Vector3) + front, k) + Vector3(0, 4.5, 0), 18.0)
	# 2 -> 3: a lift hanging off the rock face
	MovingPlatform.make(w, st[2] + Vector3(0, -0.3, 8.6), st[3] + Vector3(0, -0.3, 8.6), Vector3(6, 0.6, 6), w.m_dark, 7.0)
	Checkpoint.make(w, st[3] + Vector3(0, 0, 4.0), "peak_mid")
	# 3 -> 4: aimed spring
	w.spring_to(st[3] + front + Vector3(-3, 0, 0), st[4] + front + Vector3(0, 0.8, 0), 2.3)
	w.sparks.add_arc(st[3] + front + Vector3(-3, 4, 0), st[4] + front + Vector3(0, 3, 0), 10.0, 6)
	# 4 -> 5: lanterns, then a turret to bounce off
	Spring.make(w, st[4] + Vector3(2.5, 0.02, 3.0), 25.0)
	for k in [0.35, 0.7]:
		Orb.make(w, ((st[4] as Vector3) + front).lerp((st[5] as Vector3) + front, k) + Vector3(0, 4.5, 0), 18.0)
	Turret.make(w, st[5] + Vector3(2.5, 0, 0.5))
	# 5 -> summit
	w.spring_to(st[5] + Vector3(-2.5, 0, 3.0), summit + Vector3(0, 1.0, 4.0), 2.0)
	Checkpoint.make(w, w.g(60, -312), "summit")
	# summit shrine
	var top := w.g(pk.x, pk.y)
	for i in 4:
		var a := TAU * i / 4.0 + 0.78
		Build.cyl(w, top + Vector3(cos(a) * 7.0, 4.0, sin(a) * 7.0), 0.9, 8.0, w.m_stone, true, 0.7, 8)
	var tm := TorusMesh.new()
	tm.inner_radius = 6.4
	tm.outer_radius = 7.4
	tm.rings = 24
	tm.ring_segments = 6
	Build.visual(w, tm, w.m_gold, top + Vector3(0, 8.4, 0))
	Token.make(w, top + Vector3(0, 2.6, 0), "c2_peak")
	w.sparks.add_circle(top + Vector3(0, 1.2, 0), 4.5, 8)
	# the Skyline: a grind from the summit all the way to the Spire's crown
	var sp := w.g(Terrain.SPIRE.x, Terrain.SPIRE.y)
	var crown := sp.y + 84.75
	var pts: Array = [top + Vector3(0, 1.3, 13.0), Vector3(54, top.y - 2.0, -278), Vector3(34, crown + 13.0, -205),
			Vector3(12, crown + 8.0, -125), Vector3(2, crown + 4.5, -65), Vector3(0, crown + 3.4, -36)]
	Rail.make(w, pts, Color(1.0, 0.8, 0.3))
	for i in 14:
		var k := (i + 1) / 15.0
		var seg := mini(int(k * 5.0), 4)
		w.sparks.add((pts[seg] as Vector3).lerp(pts[seg + 1], k * 5.0 - seg) + Vector3(0, 1.4, 0))
	Token.make(w, Vector3(0, crown + 3.6, -27.0), "h1_skyline")

# ------------------------------------------------------------ Windcut Cliffs

static func _cliff_edge(w: Island, z: float) -> float:
	var x := -340.0
	while x > -600.0 and w.T.h(x, z) > 48.0:
		x -= 1.0
	return x

static func cliffs(w: Island) -> void:
	w.place_name("Windcut Cliffs", Vector2(-395, 0), 125.0)
	# a dash pad lane helps you charge up the plateau's eastern slope
	DashPad.make(w, w.g(-212, 10, 0.05), yaw_of(-1, 0), 56.0)
	w.spark_trail(Vector2(-222, 10), Vector2(-300, 10), 12)
	# lighthouse beacon
	var lp := w.g(-405, 20)
	w.clear_zone(Vector2(-405, 20), 14.0)
	Build.cyl(w, lp + Vector3(0, 1.0, 0), 6.0, 2.0, w.m_stone2, true, -1.0, 10)
	Build.cyl(w, lp + Vector3(0, 14.0, 0), 3.6, 24.0, w.m_stone, true, 2.6, 10)
	Build.cyl(w, lp + Vector3(0, 27.0, 0), 4.2, 1.0, w.m_stone2, true, -1.0, 10)
	Build.cyl(w, lp + Vector3(0, 29.5, 0), 1.6, 4.0, w.m_glow, false, -1.0, 8)
	Build.cyl(w, lp + Vector3(0, 32.5, 0), 4.0, 2.0, w.m_dark, false, 0.2, 10)
	w.beacon_light(lp + Vector3(0, 30.0, 0), Color(0.4, 1.0, 0.9), 120.0)

	# Rail Rush: three rails swing out over the sea and back
	var e0 := _cliff_edge(w, -110.0)
	var e1 := _cliff_edge(w, 150.0)
	var wx := minf(e0, e1)
	var a := w.g(e0 + 16.0, -110.0)
	Checkpoint.make(w, a + Vector3(8, 0, 0), "cliffs")
	w.clear_zone(Vector2(a.x, a.z), 14.0)
	w.hint(a + Vector3(4, 1, 0), 8.0, "Rail Rush: land on rails to grind. BOOST speeds you up, JUMP hops off.", 5.0)
	DashPad.make(w, a + Vector3(0, 0.05, 0), yaw_of(-1, 0), 40.0)
	# wooden jetties carry the rails clear of the cliff's lip at both ends
	Build.box(w, Vector3(e0 + 2.0, a.y - 0.5, -110.0), Vector3(30.0, 1.0, 6.0), w.m_wood)
	var j0 := Vector3(e0 - 12.0, a.y, -110.0)
	var r1: Array = [j0 + Vector3(0, 1.0, 0), j0 + Vector3(-12, -1.0, 1.5), Vector3(wx - 38, 50, -100), Vector3(wx - 60, 45, -78), Vector3(wx - 70, 41.5, -50), Vector3(wx - 72, 39.5, -22)]
	w.refs["rail_rush_start"] = a
	w.refs["rail_rush"] = Rail.make(w, r1)
	var r2: Array = [Vector3(wx - 72, 35.0, -15), Vector3(wx - 72, 34.0, 22), Vector3(wx - 66, 35.5, 48), Vector3(wx - 50, 38.0, 66)]
	Rail.make(w, r2, Color(0.4, 0.9, 1.0))
	var d2 := ((r2[3] as Vector3) - (r2[2] as Vector3)).normalized()
	var s3: Vector3 = (r2[3] as Vector3) + d2 * 6.0 + Vector3(0, -4.5, 0)
	var b := w.g(e1 + 16.0, 150.0)
	Build.box(w, Vector3(e1 + 2.0, b.y - 0.5, 150.0), Vector3(30.0, 1.0, 6.0), w.m_wood)
	var r3: Array = [s3, s3 + d2 * 34.0, Vector3(e1 - 40, b.y - 9.0, 132), Vector3(e1 - 22, b.y + 0.5, 149), Vector3(e1 - 8, b.y + 1.2, 150)]
	var rail3 := Rail.make(w, r3)
	for rr in [r1, r2, r3]:
		for i in rr.size() - 1:
			w.sparks.add_line((rr[i] as Vector3).lerp(rr[i + 1], 0.25) + Vector3(0, 1.4, 0), (rr[i] as Vector3).lerp(rr[i + 1], 0.75) + Vector3(0, 1.4, 0), 3)
	w.hoop_to((r2[3] as Vector3) + d2 * 2.5 + Vector3(0, 0.6, 0), rail3.sample(17.0) + Vector3(0, 0.9, 0), 40.0)
	Token.make(w, Vector3(e1 + 3.0, b.y + 1.6, 150.0), "c1_rails")
	w.sparks.add_line(Vector3(e1 + 10.0, b.y + 1.2, 150.0), Vector3(e1 + 34.0, b.y + 1.2, 150.0), 6)
	Turret.make(w, w.g(-360, -40))
	Turret.make(w, w.g(-380, 90))
	Grunt.make(w, w.g(-350, 30))
	Grunt.make(w, w.g(-342, 40))

# ------------------------------------------------------------ Sunken Ruins

static func ruins(w: Island) -> void:
	var c := Terrain.RUINS
	var base := w.g(c.x, c.y)
	w.clear_zone(c, 132.0)
	w.place_name("Sunken Ruins", c, 100.0)
	Checkpoint.make(w, w.g(c.x - 92, c.y + 14), "ruins")
	# outer colonnade, some pillars long since fallen
	for i in 16:
		var a := TAU * i / 16.0 + 0.2
		var broken := i % 3 == 1
		w.pillar(c.x + cos(a) * 86.0, c.y + sin(a) * 86.0, 6.0 if broken else 13.0, 1.7, broken)
	for i in 8:
		var a := TAU * i / 8.0 + 0.4
		w.arch(c.x + cos(a) * 44.0, c.y + sin(a) * 44.0, -a, 8.0, 8.0, 1.8)
	# ziggurat
	Build.box(w, base + Vector3(0, 1.5, 0), Vector3(34, 3, 34), w.m_stone)
	Build.box(w, base + Vector3(0, 4.5, 0), Vector3(24, 3, 24), w.m_stone2)
	Build.box(w, base + Vector3(0, 7.5, 0), Vector3(14, 3, 14), w.m_stone)
	Build.box(w, base + Vector3(0, 9.1, 0), Vector3(8, 0.2, 8), w.m_glow, Vector3.ZERO, false)
	w.sparks.add_circle(base + Vector3(0, 10.4, 0), 4.0, 8)
	# vault built against the ziggurat's east face
	for sz in [-1.0, 1.0]:
		Build.box(w, base + Vector3(21, 3.0, sz * 4.4), Vector3(8, 6.4, 1.4), w.m_stone2)
	Build.box(w, base + Vector3(21, 6.6, 0), Vector3(8, 1.2, 10.2), w.m_stone)
	var gate := Gate.make(w, base + Vector3(24.6, 3.0, 0), PI * 0.5, Vector3(7.4, 6.0, 0.9), w.m_dark)
	Token.make(w, base + Vector3(20.5, 2.4, 0), "p2_vault")
	if Game.has_flag("p2_vault"):
		gate.open(true)
	# two watch-pillars carry the vault's switches; stomp them
	var switches: Array = []
	for sz in [-1.0, 1.0]:
		var top := w.pillar(c.x + 4.0, c.y + sz * 52.0, 15.0, 3.6)
		var sw := PressSwitch.make(w, top)
		switches.append(sw)
		Spring.make(w, w.g(c.x - 4.0, c.y + sz * 52.0, 0.05), 37.0)
		w.sparks.add_line(w.g(c.x - 4.0, c.y + sz * 52.0, 6.0), w.g(c.x - 4.0, c.y + sz * 52.0, 18.0), 4)
		sw.pressed_changed.connect(func(_on):
			if gate.opened:
				return
			if switches[0].on and switches[1].on:
				gate.open()
				Game.set_flag("p2_vault")
				Game.say("The ruin vault unseals!", 4.0)
				Sfx.play("win")
			else:
				Game.say("One seal released. Its twin stands across the ruins.", 4.0))
	w.refs["vault_switches"] = switches
	w.hint(base + Vector3(34, 1, 0), 9.0, "Sealed. Two watch-pillars hold the locks: STOMP the switches on top.", 6.0)
	# time trial: one lap of the colonnade
	var pts: Array = []
	for i in 9:
		var a := PI + TAU * i / 8.0
		pts.append(w.g(c.x + cos(a) * 66.0, c.y + sin(a) * 66.0))
	w.refs["trial"] = TimeTrial.make(w, pts, 12.0, "c4_trial", "Ruins Dash")
	for i in 8:
		var a0 := PI + TAU * (i + 0.25) / 8.0
		var a1 := PI + TAU * (i + 0.75) / 8.0
		w.spark_ring_arc(c, 66.0, a0, a1, 4)
	# low walls on the lap to hop or weave around
	for a in [PI * 1.25, PI * 0.25]:
		var p := w.g(c.x + cos(a) * 66.0, c.y + sin(a) * 66.0)
		Build.box(w, p + Vector3(0, 0.8, 0), Vector3(1.4, 1.8, 9.0), w.m_stone2, Vector3(0, -a, 0))
	Bulwark.make(w, w.g(c.x + 36, c.y + 14))
	Bulwark.make(w, w.g(c.x - 30, c.y - 20))
	Grunt.make(w, w.g(c.x - 20, c.y + 30))
	Grunt.make(w, w.g(c.x + 10, c.y - 34))
	Grunt.make(w, w.g(c.x + 30, c.y + 38))

# ------------------------------------------------------------ Lantern Reach

static func lantern_reach(w: Island) -> void:
	var z := 40.0
	var sx := 440.0
	while sx < 580.0 and w.T.h(sx, z) > 2.2:
		sx += 1.0
	var isl := Terrain.ISLET
	w.place_name("Lantern Reach", Vector2(sx - 10.0, z), 40.0)
	w.clear_zone(Vector2(sx - 14.0, z), 12.0)
	Checkpoint.make(w, w.g(sx - 24.0, z + 6.0), "east_shore")
	w.hint(w.g(sx - 18.0, z, 1), 8.0, "Lantern Hop: chain homing attacks across the water. Don't touch the sea!", 5.0)
	var from := w.g(sx - 10.0, z, 0.05)
	var first := Vector3(sx + 8.0, 9.5, z)
	w.refs["lantern_spring"] = w.spring_to(from, first + Vector3(-5.0, 3.0, 0), 1.0)
	var last := Vector3(isl.x - 22.0, 12.5, isl.y)
	var n := int(ceilf(first.distance_to(last) / 11.5))
	for i in n + 1:
		var k := float(i) / n
		Orb.make(w, first.lerp(last, k) + Vector3(0, 2.2 * sin(k * PI), sin(k * 9.0) * 2.5), 16.5)
	var it := w.g(isl.x, isl.y)
	Build.cyl(w, it + Vector3(0, -0.25, 0), 4.0, 0.8, w.m_stone2, true, -1.0, 10)
	for i in 3:
		var a := TAU * i / 3.0
		Build.cyl(w, it + Vector3(cos(a) * 6.0, 3.0, sin(a) * 6.0), 0.5, 6.0, w.m_stone, true, 0.3, 6)
	Token.make(w, it + Vector3(0, 1.9, 0), "c3_lantern")
	w.sparks.add_circle(it + Vector3(0, 1.4, 0), 8.0, 10)
	w.spring_to(w.g(isl.x + 9.0, isl.y + 9.0, 0.05), w.g(sx - 30.0, z + 12.0, 1.0), 2.6)

# ------------------------------------------------------------ Sky Garden

static func sky_garden(w: Island) -> void:
	w.place_name("Sky Garden", Vector2(268, -232), 80.0)
	var g0 := w.g(204, -118, 0.05)
	w.clear_zone(Vector2(204, -118), 12.0)
	Build.cyl(w, g0 + Vector3(0, -0.15, 0), 4.5, 0.6, w.m_stone2, true, -1.0, 10)
	for i in 4:
		var a := TAU * i / 4.0
		Build.cyl(w, g0 + Vector3(cos(a) * 5.5, 2.5, sin(a) * 5.5), 0.4, 5.0, w.m_glow, false, 0.1, 6)
	var i1 := Vector3(228, 50, -162)
	var i2 := Vector3(274, 58, -206)
	var i3 := Vector3(322, 72, -268)
	var i4 := Vector3(262, 88, -302)
	w.sky_island(i1, 10.0)
	w.sky_island(i2, 9.0)
	w.sky_island(i3, 9.0)
	w.sky_island(i4, 11.0)
	w.spring_to(g0 + Vector3(0, 0.4, 0), i1 + Vector3(0, 1.2, 2.0), 2.1)
	w.hint(g0 + Vector3(0, 1, 6), 8.0, "Sky Garden: an ancient course hangs in the clouds above.", 4.0)
	Checkpoint.make(w, i1 + Vector3(0, 0, 4.0), "sky")
	w.sparks.add_circle(i1 + Vector3(0, 1.2, 0), 6.0, 8)
	# lift between the first two islands
	MovingPlatform.make(w, i1 + Vector3(11, -0.3, -12), i2 + Vector3(-12, -0.3, 10), Vector3(6, 0.6, 6), w.m_dark, 6.5)
	Turret.make(w, i2 + Vector3(-3, 0, -4))
	# hoops fling you across the widest gap
	var ha := i2 + Vector3(7.5, 4.0, -9.5)
	var hb := Vector3(303, 70, -244)
	w.hoop_to(ha, hb)
	w.hoop_to(hb, i3 + Vector3(0, 1.5, 3.0), 40.0)
	w.sparks.add_line(ha.lerp(hb, 0.2), ha.lerp(hb, 0.8) + Vector3(0, 2, 0), 5)
	# lanterns spiral up to the garden's crown
	var chain: Array = [Vector3(312, 77, -280), Vector3(300, 81, -289), Vector3(288, 85, -295), Vector3(277, 89, -299)]
	for cpos in chain:
		Orb.make(w, cpos, 17.0)
	w.refs["sky_spring"] = Spring.make(w, i3 + Vector3(-4, 0.02, -5), 24.0)
	w.refs["sky_top"] = i4
	Token.make(w, i4 + Vector3(0, 1.9, 0), "c5_sky")
	for i in 4:
		var a := TAU * i / 4.0 + 0.5
		Build.cyl(w, i4 + Vector3(cos(a) * 8.5, 3.0, sin(a) * 8.5), 0.5, 6.0, w.m_stone, true, 0.3, 6)
	# glide home on a rail that drops back to the plains
	var pts: Array = [i4 + Vector3(-9, 1.2, 5), Vector3(228, 72, -232), Vector3(182, 50, -172), Vector3(122, 34, -124), w.g(66, -104, 1.6)]
	Rail.make(w, pts, Color(0.4, 0.9, 1.0))
	for i in pts.size() - 1:
		w.sparks.add_line((pts[i] as Vector3).lerp(pts[i + 1], 0.3) + Vector3(0, 1.4, 0), (pts[i] as Vector3).lerp(pts[i + 1], 0.7) + Vector3(0, 1.4, 0), 4)

# ------------------------------------------------------------ Hollow Pass

static func hollow_pass(w: Island) -> void:
	var cove := Terrain.COVE
	var dir := Vector2(0.7071, -0.7071)
	var side := Vector2(0.7071, 0.7071)
	var yaw := yaw_of(-dir.x, -dir.y)      # facing into the cove
	w.place_name("Hollow Pass", cove + dir * 118.0, 34.0)
	w.place_name("Hidden Cove", cove, 52.0)
	for dc in range(60, 180, 10):
		w.clear_zone(cove + dir * dc, 12.0)
	# rock slabs roof the canyon into a tunnel
	for i in 9:
		var dc := 70.0 + i * 8.0
		var p2 := cove + dir * dc
		var fl := w.T.h(p2.x, p2.y)
		Build.box(w, Vector3(p2.x, fl + 12.5 + (i % 2) * 0.8, p2.y), Vector3(26.0, 4.0, 9.5), w.m_rock, Vector3(0, yaw, 0.04 * (i % 3 - 1)))
	# glowing crystals light the way
	for i in 5:
		var dc := 76.0 + i * 13.0
		var p2 := cove + dir * dc + side * (5.2 if i % 2 == 0 else -5.2)
		var cp := Vector3(p2.x, w.T.h(p2.x, p2.y) + 1.5, p2.y)
		var cm := SphereMesh.new()
		cm.radius = 0.6
		cm.height = 2.6
		cm.radial_segments = 5
		cm.rings = 2
		Build.visual(w, cm, w.m_glow, cp, Vector3.ONE, Vector3(0.3 * (i % 2), 0, 0.3))
		if i % 2 == 0:
			var l := OmniLight3D.new()
			l.light_color = Color(0.4, 1.0, 0.9)
			l.omni_range = 16.0
			l.light_energy = 2.0
			l.position = cp + Vector3(0, 1.5, 0)
			w.add_child(l)
	var wp := cove + dir * 104.0
	Breakable.make(w, Vector3(wp.x, w.T.h(wp.x, wp.y) + 5.0, wp.y), yaw, Vector3(20.0, 11.0, 1.8))
	var mouth := cove + dir * 158.0
	w.refs["pass_mouth"] = w.g(mouth.x + dir.x * 14.0, mouth.y + dir.y * 14.0, 0.6)
	w.arch(mouth.x, mouth.y, yaw, 12.0, 9.0)
	w.hint(w.g(mouth.x, mouth.y, 1), 10.0, "A cracked wall blocks the pass. Smash it with a Spin Dash or a Boost!", 6.0)
	w.spark_trail(cove + dir * 172.0, cove + dir * 112.0, 12)
	w.spark_trail(cove + dir * 96.0, cove + dir * 40.0, 10)
	Checkpoint.make(w, w.g(mouth.x + 10.0, mouth.y - 10.0), "pass")
	# the cove's shrine
	var cp2 := w.g(cove.x, cove.y)
	Build.cyl(w, cp2 + Vector3(0, -0.25, 0), 5.0, 0.8, w.m_stone2, true, -1.0, 10)
	for i in 5:
		var a := TAU * i / 5.0
		Build.cyl(w, cp2 + Vector3(cos(a) * 7.0, 2.5, sin(a) * 7.0), 0.6, 5.0 + (i % 2) * 2.0, w.m_stone, true, 0.4, 6)
	Token.make(w, cp2 + Vector3(0, 1.9, 0), "c6_hollow")
	w.sparks.add_circle(cp2 + Vector3(0, 1.3, 0), 12.0, 14)

# ------------------------------------------------------------ Sea stack

static func sea_stack(w: Island) -> void:
	var st := Terrain.STACK
	var top := w.g(st.x, st.y)
	# a spring tucked behind a boulder on the south-east beach
	var from := w.g(286, 392, 0.05)
	w.clear_zone(Vector2(286, 392), 10.0)
	Build.cyl(w, w.g(279, 386, 1.5), 3.5, 5.0, w.m_rock, true, 2.2, 7)
	var mid := Vector3(308, 30, 430)
	w.refs["stack_spring"] = w.spring_to(from, mid, 1.25)
	w.hoop_to(mid, top + Vector3(0, 2.0, 0), 44.0)
	Build.cyl(w, top + Vector3(0, -0.15, 0), 3.5, 0.6, w.m_stone2, true, -1.0, 8)
	Token.make(w, top + Vector3(0, 1.9, 0), "h2_stack")
	w.sparks.add_circle(top + Vector3(0, 1.3, 0), 6.0, 8)
	w.spring_to(top + Vector3(-7, 0.05, -6), w.g(280, 400, 1.0), 2.3)

# ------------------------------------------------------------ Guardian's Basin

static func basin(w: Island) -> void:
	var c := Terrain.BASIN
	var base := w.g(c.x, c.y)
	w.clear_zone(c, 100.0)
	w.place_name("Guardian's Basin", c, 70.0)
	for i in 12:
		var a := TAU * i / 12.0
		var p := base + Vector3(cos(a) * 58.0, 5.0, sin(a) * 58.0)
		Build.box(w, p, Vector3(2.6, 13.0, 2.6), w.m_dark, Vector3(0.06 * sin(i * 2.0), -a, 0.05 * cos(i * 3.0)))
		Build.box(w, p + Vector3(0, 2.0, 0), Vector3(2.7, 5.0, 0.5), Build.mat(Color(0.7, 0.4, 1.0), 0.3, 1.6), Vector3(0, -a, 0), false)
	var tm := TorusMesh.new()
	tm.inner_radius = 16.0
	tm.outer_radius = 16.6
	tm.rings = 40
	tm.ring_segments = 4
	Build.visual(w, tm, Build.mat(Color(0.7, 0.4, 1.0), 0.3, 1.2), base + Vector3(0, 0.1, 0))
	var gate_pos := c + Vector2(0.7071, 0.7071) * 100.0
	Checkpoint.make(w, w.g(gate_pos.x, gate_pos.y), "basin")
	w.refs["guardian"] = Guardian.make(w, base)
	Bulwark.make(w, w.g(gate_pos.x + 14.0, gate_pos.y - 6.0))
	Bulwark.make(w, w.g(gate_pos.x - 6.0, gate_pos.y + 14.0))

# ------------------------------------------------------------ Roaming enemies

static func wanderers(w: Island) -> void:
	for p in [Vector2(40, 190), Vector2(48, 198), Vector2(-120, 60), Vector2(-128, 52), Vector2(-112, 50),
			Vector2(150, 120), Vector2(158, 112), Vector2(90, -110), Vector2(-60, -120), Vector2(-52, -128),
			Vector2(-200, 200), Vector2(210, -40)]:
		Grunt.make(w, w.g(p.x, p.y))
	for p in [Vector2(-40, 100), Vector2(120, 60), Vector2(-170, -150), Vector2(170, 240)]:
		Turret.make(w, w.g(p.x, p.y))
	Bulwark.make(w, w.g(-70, 30))
