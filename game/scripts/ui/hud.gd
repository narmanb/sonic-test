extends CanvasLayer
## In-game HUD: sparks, cores, boost meter, speed, objective, toasts, timers,
## boss health and the homing-attack reticle.

var root: Control
var sparks_l: Label
var tokens_l: Label
var speed_l: Label
var obj_l: Label
var msg_l: Label
var timer_l: Label
var fps_l: Label
var boost_bar: ProgressBar
var boss_bar: ProgressBar
var reticle: Control
var msg_t := 0.0
var ret_spin := 0.0

func _label(size: int, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.12))
	l.add_theme_constant_override("outline_size", maxi(4, size / 4))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _bar(col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.06, 0.12, 0.65)
	bg.set_corner_radius_all(8)
	bg.set_border_width_all(2)
	bg.border_color = Color(1, 1, 1, 0.5)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(8)
	fg.set_border_width_all(2)
	fg.border_color = Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	sparks_l = _label(34, Color(1.0, 0.9, 0.35))
	sparks_l.position = Vector2(28, 18)
	root.add_child(sparks_l)
	tokens_l = _label(26, Color(0.8, 0.7, 1.0))
	tokens_l.position = Vector2(28, 62)
	root.add_child(tokens_l)
	boost_bar = _bar(Color(0.3, 0.9, 1.0))
	boost_bar.position = Vector2(28, 104)
	boost_bar.size = Vector2(240, 18)
	root.add_child(boost_bar)

	obj_l = _label(20, Color(0.9, 0.97, 1.0))
	obj_l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	obj_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	obj_l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	obj_l.position = Vector2(-28, 18)
	root.add_child(obj_l)
	fps_l = _label(16, Color(0.7, 1.0, 0.7))
	fps_l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fps_l.position = Vector2(-28, 46)
	root.add_child(fps_l)

	timer_l = _label(40, Color(1, 1, 1))
	timer_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	timer_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_l.position.y = 54
	timer_l.visible = false
	root.add_child(timer_l)

	boss_bar = _bar(Color(1.0, 0.35, 0.4))
	boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_bar.size = Vector2(460, 20)
	boss_bar.position = Vector2(-230, 20)
	boss_bar.visible = false
	root.add_child(boss_bar)

	msg_l = _label(30)
	msg_l.set_anchors_preset(Control.PRESET_CENTER)
	msg_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	msg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_l.position.y = -190
	msg_l.modulate.a = 0.0
	root.add_child(msg_l)

	speed_l = _label(22, Color(0.8, 0.95, 1.0))
	speed_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	speed_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	speed_l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	speed_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_l.position.y = -14
	root.add_child(speed_l)

	reticle = Control.new()
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.draw.connect(_draw_reticle)
	root.add_child(reticle)

	Game.sparks_changed.connect(func(_n): _refresh())
	Game.tokens_changed.connect(func(_n): _refresh())
	Game.objective_changed.connect(func(t): obj_l.text = t)
	Game.message.connect(_on_msg)
	Game.timer_changed.connect(_on_timer)
	Game.boss_hp_changed.connect(func(a, f): boss_bar.visible = a; boss_bar.value = f * 100.0)
	_refresh()
	obj_l.text = Game.objective

func _refresh() -> void:
	sparks_l.text = "◆ %d" % Game.sparks
	tokens_l.text = "Cores %d / %d" % [Game.token_count(), Game.TOKENS_TOTAL]

func _on_msg(text: String, secs: float) -> void:
	msg_l.text = text
	msg_t = secs
	msg_l.modulate.a = 1.0

func _on_timer(active: bool, t: float, limit: float) -> void:
	timer_l.visible = active
	if active:
		timer_l.text = "%.1f / %.0f" % [t, limit]
		timer_l.add_theme_color_override("font_color", Color(1, 0.4, 0.3) if t > limit * 0.8 else Color.WHITE)

func _draw_reticle() -> void:
	var c := Color(0.3, 1.0, 0.6)
	reticle.draw_arc(Vector2.ZERO, 26.0, ret_spin, ret_spin + 1.6, 12, c, 5.0)
	reticle.draw_arc(Vector2.ZERO, 26.0, ret_spin + PI, ret_spin + PI + 1.6, 12, c, 5.0)
	reticle.draw_circle(Vector2.ZERO, 5.0, Color(1, 1, 1, 0.9))

func _process(dt: float) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p):
		return
	boost_bar.value = p.boost
	speed_l.text = "%d km/h" % int(p.speed() * 3.6)
	if msg_t > 0.0:
		msg_t -= dt
		if msg_t <= 0.5:
			msg_l.modulate.a = maxf(0.0, msg_t / 0.5)
	fps_l.visible = Game.settings["show_fps"]
	if fps_l.visible:
		fps_l.text = "%d fps" % Engine.get_frames_per_second()
	var show := false
	if p.target != null and is_instance_valid(p.target) and Game.camera != null:
		var cam: Camera3D = Game.camera.cam
		var tp: Vector3 = p.target.homing_point()
		if not cam.is_position_behind(tp):
			reticle.position = cam.unproject_position(tp)
			show = true
	reticle.visible = show
	if show:
		ret_spin += dt * 6.0
		reticle.queue_redraw()
