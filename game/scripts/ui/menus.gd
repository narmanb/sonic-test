extends CanvasLayer
## Title screen, pause menu and settings. Everything is built in code, sized
## for touch and fully navigable with a gamepad (focus) or keyboard.

var main: Node
var panel: Control
var backdrop: ColorRect
var in_game := false
var showing := ""
var theme_res: Theme

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme_res = _make_theme()

func _notification(what: int) -> void:
	# Android back button / gesture behaves like the pause button
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if in_game:
			if showing == "":
				open_pause()
			elif showing == "settings":
				open_pause()
			else:
				resume()
		elif showing == "settings":
			Game.save_settings()
			open_title(main)

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.2, 0.32, 0.92)
	normal.set_corner_radius_all(14)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.3, 0.85, 0.9, 0.7)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	var hover := normal.duplicate()
	hover.bg_color = Color(0.1, 0.42, 0.5, 0.96)
	hover.border_color = Color(1.0, 0.8, 0.3)
	hover.set_border_width_all(3)
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.9, 0.6, 0.15)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_font_size("font_size", "Button", 26)
	t.set_font_size("font_size", "Label", 22)
	t.set_color("font_color", "Label", Color(0.9, 0.97, 1.0))
	return t

func _clear() -> void:
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	panel = null
	if backdrop != null and is_instance_valid(backdrop):
		backdrop.queue_free()
	backdrop = null
	showing = ""

func _frame(dim: float, title: String, title_size: int = 44) -> VBoxContainer:
	_clear()
	backdrop = ColorRect.new()
	backdrop.color = Color(0.02, 0.07, 0.14, dim)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.theme = theme_res
	add_child(centre)
	panel = centre
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(440, 0)
	centre.add_child(box)
	var l := Label.new()
	l.text = title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", title_size)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.2))
	l.add_theme_constant_override("outline_size", 10)
	box.add_child(l)
	return box

func _button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	b.pressed.connect(func():
		Sfx.play("switch", 1.4, -6.0)
		cb.call())
	box.add_child(b)
	return b

# ------------------------------------------------------------ title

func open_title(m: Node) -> void:
	main = m
	in_game = false
	var box := _frame(1.0, "AURORA RUSH", 72)
	showing = "title"
	var sub := Label.new()
	sub.text = "A high-speed open-world platformer prototype"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(_gap(10))
	var first: Button
	if Game.has_progress():
		first = _button(box, "Continue  (%d / %d cores)" % [Game.token_count(), Game.TOKENS_TOTAL], func(): _load("island"))
		_button(box, "New Game", func():
			Game.reset_progress()
			_load("island"))
	else:
		first = _button(box, "Start Adventure", func(): _load("island"))
	_button(box, "Movement Lab", func(): _load("arena"))
	_button(box, "Settings", func(): open_settings())
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		_button(box, "Quit", func(): get_tree().quit())
	first.grab_focus()

func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _load(kind: String) -> void:
	var box := _frame(1.0, "Loading…", 48)
	var l := Label.new()
	l.text = "Raising the island" if kind == "island" else "Opening the lab"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	await get_tree().process_frame
	await get_tree().process_frame
	main.start_world(kind)

# ------------------------------------------------------------ in game

func attach_game(m: Node) -> void:
	main = m
	in_game = true
	_clear()

func _process(_dt: float) -> void:
	if not in_game:
		return
	if Input.is_action_just_pressed("pause"):
		if showing == "":
			open_pause()
		elif showing == "pause":
			resume()
		elif showing == "settings":
			open_pause()

func open_pause() -> void:
	get_tree().paused = true
	var box := _frame(0.72, "PAUSED")
	showing = "pause"
	var info := Label.new()
	info.text = "Cores %d / %d      Sparks %d" % [Game.token_count(), Game.TOKENS_TOTAL, Game.sparks]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	var first := _button(box, "Resume", resume)
	_button(box, "Return to Checkpoint", func():
		resume()
		if Game.player != null:
			Game.player.respawn())
	_button(box, "Settings", func(): open_settings())
	_button(box, "Save & Quit to Title", func():
		Game.save_game()
		get_tree().paused = false
		main.show_title())
	first.grab_focus()

func resume() -> void:
	_clear()
	get_tree().paused = false

# ------------------------------------------------------------ settings

func _row(box: Container, label: String, control: Control) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(250, 40)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size = Vector2(300, 40)
	if control is Button:
		for st in ["normal", "hover", "focus", "pressed"]:
			var sb: StyleBoxFlat = theme_res.get_stylebox(st, "Button").duplicate()
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
			control.add_theme_stylebox_override(st, sb)
		control.add_theme_font_size_override("font_size", 20)
	h.add_child(control)
	box.add_child(h)

func _slider(key: String, lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Game.settings[key])
	s.value_changed.connect(func(v):
		Game.settings[key] = v
		Game.apply_settings())
	return s

func _cycle(key: String, names: Array) -> Button:
	var b := Button.new()
	b.text = names[int(Game.settings[key]) % names.size()]
	b.pressed.connect(func():
		var v := (int(Game.settings[key]) + 1) % names.size()
		Game.settings[key] = v
		b.text = names[v]
		Game.apply_settings())
	return b

func _toggle(key: String) -> Button:
	var b := Button.new()
	b.text = "On" if Game.settings[key] else "Off"
	b.pressed.connect(func():
		Game.settings[key] = not Game.settings[key]
		b.text = "On" if Game.settings[key] else "Off"
		Game.apply_settings())
	return b

func open_settings() -> void:
	var box := _frame(0.9 if in_game else 1.0, "SETTINGS", 36)
	showing = "settings"
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size = Vector2(640, 0)
	var first := _cycle("quality", ["Graphics: Low", "Graphics: Medium", "Graphics: High"])
	_row(box, "Graphics quality", first)
	_row(box, "Camera distance", _slider("cam_dist", 4.5, 11.0, 0.5))
	_row(box, "Camera sensitivity", _slider("cam_sens", 0.4, 2.0, 0.1))
	_row(box, "Invert camera Y", _toggle("invert_y"))
	_row(box, "Volume", _slider("volume", 0.0, 1.0, 0.05))
	_row(box, "Touch controls", _cycle("touch_mode", ["Auto", "Always shown", "Hidden"]))
	_row(box, "Touch button size", _slider("touch_scale", 0.7, 1.5, 0.05))
	_row(box, "Touch opacity", _slider("touch_opacity", 0.2, 1.0, 0.05))
	_row(box, "Left-handed touch layout", _toggle("touch_swap"))
	_row(box, "Show FPS", _toggle("show_fps"))
	var help := Label.new()
	help.text = "Gamepad:  A jump (again: double jump)  ·  X homing attack / air dash  ·  RT or RB boost\nB or LT: Spin Dash on the ground, Stomp in the air  ·  Right stick: camera  ·  Start: pause\nKeyboard:  WASD move · Space jump · J attack · Shift boost · K spin/stomp · arrows or right-drag camera"
	help.add_theme_font_size_override("font_size", 14)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.modulate = Color(0.75, 0.9, 1.0)
	box.add_child(help)
	var back := _button(box, "Back", func():
		Game.save_settings()
		if in_game:
			open_pause()
		else:
			open_title(main))
	back.custom_minimum_size = Vector2(0, 50)
	first.grab_focus()
