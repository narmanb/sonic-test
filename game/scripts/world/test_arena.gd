class_name TestArena
extends WorldBase
## Controlled playground for tuning and regression-testing every movement
## mechanic. Lanes run along -Z from the spawn; see tests/movement_tests.gd.

const LOOP_POS := Vector3(30, 0, -45)
const LOOP_R := 10.0

var m_ground := Build.mat(Color(0.42, 0.62, 0.38))
var m_stone := Build.mat(Color(0.72, 0.7, 0.66))
var m_dark := Build.mat(Color(0.35, 0.38, 0.45))
var m_blue := Build.mat(Color(0.3, 0.5, 0.8))
var orbs: Array = []
var test_switch: PressSwitch
var test_gate: Gate
var test_wall: Breakable
var test_rail: Rail
var los_orb: Orb

func _build() -> void:
	is_test = true
	spawn_point = Vector3(0, 0.5, 0)
	Build.box(self, Vector3(0, -1, -100), Vector3(700, 2, 700), m_ground)
	# checker stripes for speed reference
	for i in 30:
		Build.box(self, Vector3(0, 0.01, -i * 20.0), Vector3(8, 0.02, 1), m_stone, Vector3.ZERO, false)
	sparks.add_line(Vector3(0, 1, -20), Vector3(0, 1, -120), 26)
	# end wall for high speed impact tests
	Build.box(self, Vector3(0, 6, -300), Vector3(120, 12, 3), m_dark)

	# --- slope lanes
	_ramp(Vector3(-30, 0, -40), 30.0, 30.0, 10.0, 24.0)
	_ramp(Vector3(-50, 0, -40), 15.0, 30.0, 10.0, 24.0)
	_ramp(Vector3(-70, 0, -40), 45.0, 15.0, 10.0, 24.0)
	# --- bumps and rolling hills
	var prof: Array = [Vector2(0, 0)]
	var z := 0.0
	for i in 14:
		var up := 0.25 if i % 3 != 2 else 0.5
		var run := 3.0 if i % 3 != 2 else 2.0
		prof.append(Vector2(z + run, up))
		prof.append(Vector2(z + run * 2.0, 0))
		z += run * 2.0 + (2.0 if i % 2 == 0 else 0.5)
		prof.append(Vector2(z, 0))
	_strip(Vector3(-100, 0, -30), 10.0, prof)
	prof = []
	for i in 121:
		var d := i * 1.5
		prof.append(Vector2(d, 2.6 - 2.6 * cos(d / 40.0 * TAU)))
	_strip(Vector3(-130, 0, -30), 12.0, prof)

	# --- loop
	DashPad.make(self, Vector3(30, 0, -22), 0.0, 50.0)
	Build.loop(self, LOOP_POS, 0.0, LOOP_R, 7.0, 8.0, m_blue)
	LoopGuide.make(self, LOOP_POS, 0.0, LOOP_R, 7.0, 8.0)
	sparks.add_circle(Vector3(34, LOOP_R, -45), 0.1, 1)
	# --- quarter pipe
	Build.quarter_pipe(self, Vector3(60, 0, -40), 0.0, 10.0, 12.0, m_blue)

	# --- spring + homing chain
	Spring.make(self, Vector3(90, 0, -30), 30.0)
	orbs = [Orb.make(self, Vector3(90, 10, -42)), Orb.make(self, Vector3(90, 11, -54)), Orb.make(self, Vector3(90, 12, -66))]
	Build.box(self, Vector3(90, 9.5, -80), Vector3(12, 1, 14), m_stone)
	Token.make(self, Vector3(90, 12, -80), "test_token")
	Spring.make(self, Vector3(90, 10, -85), 34.0, Vector3(-0.6, 0, 0))

	# --- rails
	test_rail = Rail.make(self, [Vector3(120, 1, -30), Vector3(120, 4, -60), Vector3(128, 8, -90), Vector3(120, 6, -120), Vector3(120, 1.2, -150)])
	Rail.make(self, [Vector3(126, 9, -30), Vector3(134, 12, -70), Vector3(126, 9, -110)], Color(0.4, 0.9, 1.0))
	sparks.add_line(Vector3(120, 5.5, -60), Vector3(120, 7.5, -120), 10)

	# --- breakable wall lane
	test_wall = Breakable.make(self, Vector3(150, 3, -80), 0.0, Vector3(10, 6, 1.5))
	Build.box(self, Vector3(144, 3, -80), Vector3(2, 6, 1.5), m_dark)
	Build.box(self, Vector3(156, 3, -80), Vector3(2, 6, 1.5), m_dark)

	# --- coyote ledge
	Build.box(self, Vector3(-160, 2, -40), Vector3(10, 4, 20), m_stone)
	# --- line-of-sight check
	los_orb = Orb.make(self, Vector3(180, 2.5, -44))
	Build.box(self, Vector3(180, 3, -38), Vector3(8, 6, 1), m_dark)
	# --- hoops
	Spring.make(self, Vector3(210, 0, -30), 26.0, Vector3(-0.5, 0, 0))
	Hoop.make(self, Vector3(210, 8, -40), Vector3(0, 0.15, -1))
	Hoop.make(self, Vector3(210, 10.5, -75), Vector3(0, 0.1, -1))
	Build.box(self, Vector3(210, 5, -128), Vector3(12, 1, 24), m_stone)

	# --- stomp switch + gate + moving platform (behind spawn)
	Build.box(self, Vector3(-20, 4, 30), Vector3(8, 8, 8), m_stone)
	Build.box(self, Vector3(-20, 0.5, 21), Vector3(8, 1, 10), m_stone, Vector3(deg_to_rad(-0), 0, 0))
	test_switch = PressSwitch.make(self, Vector3(-20, 0, 42))
	test_gate = Gate.make(self, Vector3(-20, 3.5, 52), 0.0, Vector3(8, 7, 1.2), m_dark)
	test_switch.pressed_changed.connect(func(on): if on: test_gate.open())
	MovingPlatform.make(self, Vector3(20, 1, 30), Vector3(20, 8, 50), Vector3(6, 0.6, 6), m_dark, 6.0)
	Checkpoint.make(self, Vector3(0, 0, -8), "arena_start")

func _ramp(pos: Vector3, deg: float, run: float, width: float, top: float) -> void:
	var h := run * tan(deg_to_rad(deg))
	_strip(pos, width, [Vector2(0, 0), Vector2(run, h), Vector2(run + top, h)])

## Ground strip following a height profile [(distance along -Z, height)].
func _strip(pos: Vector3, width: float, profile: Array) -> void:
	var v := PackedVector3Array()
	var hw := width * 0.5
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		var l0 := Vector3(-hw, a.y, -a.x)
		var r0 := Vector3(hw, a.y, -a.x)
		var l1 := Vector3(-hw, b.y, -b.x)
		var r1 := Vector3(hw, b.y, -b.x)
		Build.tri(v, l0, r0, r1, Vector3.UP)
		Build.tri(v, l0, r1, l1, Vector3.UP)
		for s in [[l0, l1, Vector3.LEFT], [r0, r1, Vector3.RIGHT]]:
			var p0: Vector3 = s[0]
			var p1: Vector3 = s[1]
			Build.tri(v, p0, p1, Vector3(p1.x, -0.5, p1.z), s[2])
			Build.tri(v, p0, Vector3(p1.x, -0.5, p1.z), Vector3(p0.x, -0.5, p0.z), s[2])
	var last: Vector2 = profile[profile.size() - 1]
	if last.y > 0.1:
		Build.tri(v, Vector3(-hw, last.y, -last.x), Vector3(hw, last.y, -last.x), Vector3(hw, -0.5, -last.x), Vector3.FORWARD)
		Build.tri(v, Vector3(-hw, last.y, -last.x), Vector3(hw, -0.5, -last.x), Vector3(-hw, -0.5, -last.x), Vector3.FORWARD)
	Build.surface(self, v, m_stone, pos)
