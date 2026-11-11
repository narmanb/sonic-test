extends CanvasLayer
## On-screen controls for phones: a floating movement stick on one side,
## action buttons on the other, and camera drag anywhere else on the button
## side. Size, opacity and handedness come from the settings menu.

class Pad extends Control:
	var owner_layer: CanvasLayer
	func _draw() -> void:
		owner_layer.draw_pad(self)

var pad: Pad
var buttons: Array = []       # {name, actions, pos, radius, label, down}
var touches := {}             # finger index -> "stick" | "look" | button index
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var stick_on := false
var stick_r := 95.0
var active := false

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	pad = Pad.new()
	pad.owner_layer = self
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pad)
	Game.settings_changed.connect(_layout)
	Controls.input_mode_changed.connect(func(_t): _refresh())
	get_viewport().size_changed.connect(_layout)
	_layout()

func _size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _layout() -> void:
	var sz := _size()
	var s: float = float(Game.settings["touch_scale"]) * clampf(sz.y / 720.0, 0.75, 1.6)
	var swap: bool = Game.settings["touch_swap"]
	stick_r = 95.0 * s
	var defs: Array = [
		["jump", ["jump"], Vector2(-135, -125), 66.0, "JUMP"],
		["attack", ["attack"], Vector2(-285, -95), 52.0, "ATK"],
		["boost", ["boost"], Vector2(-105, -285), 58.0, "BOOST"],
		["spin", ["spin", "stomp"], Vector2(-255, -235), 50.0, "SPIN"],
		["pause", ["pause"], Vector2(-46, 110), 26.0, "II"],
	]
	_release_all()
	buttons.clear()
	for d in defs:
		var off: Vector2 = d[2]
		var pos := Vector2(sz.x + off.x * s, (sz.y + off.y * s) if off.y < 0.0 else off.y)
		if d[0] == "pause":
			pos = Vector2(sz.x - 46.0, 110.0)
		elif swap:
			pos.x = sz.x - pos.x
		buttons.append({"name": d[0], "actions": d[1], "pos": pos, "radius": float(d[3]) * (s if d[0] != "pause" else 1.0), "label": d[4], "down": false})
	_refresh()

func _refresh() -> void:
	var mode := int(Game.settings["touch_mode"])
	var want := mode == 1 or (mode == 0 and Controls.using_touch)
	if want != active:
		active = want
		if not active:
			_release_all()
	pad.visible = active
	pad.queue_redraw()

func _release_all() -> void:
	for b in buttons:
		if b.down:
			for a in b.actions:
				Input.action_release(a)
			b.down = false
	touches.clear()
	stick_on = false
	Controls.touch_move = Vector2.ZERO

func _stick_side(x: float) -> bool:
	var sz := _size()
	return (x > sz.x * 0.58) if Game.settings["touch_swap"] else (x < sz.x * 0.42)

func _input(event: InputEvent) -> void:
	if not active:
		# the first touch flips Controls.using_touch; pick it up next frame
		if event is InputEventScreenTouch:
			_refresh.call_deferred()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_down(event.index, event.position)
		else:
			_up(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position, event.relative)
	elif int(Game.settings["touch_mode"]) == 1:
		# desktop testing: the mouse acts as a single finger
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_down(99, event.position)
			else:
				_up(99)
		elif event is InputEventMouseMotion and touches.has(99):
			_drag(99, event.position, event.relative)

func _down(idx: int, pos: Vector2) -> void:
	for i in buttons.size():
		var b: Dictionary = buttons[i]
		if pos.distance_to(b.pos) < b.radius * 1.25:
			touches[idx] = i
			b.down = true
			for a in b.actions:
				Input.action_press(a)
			pad.queue_redraw()
			return
	if _stick_side(pos.x) and not stick_on and pos.y > _size().y * 0.2:
		touches[idx] = "stick"
		stick_on = true
		stick_origin = pos
		stick_pos = pos
	else:
		touches[idx] = "look"
	pad.queue_redraw()

func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	if not touches.has(idx):
		return
	var role = touches[idx]
	if role is String and role == "stick":
		stick_pos = pos
		var d := (pos - stick_origin) / stick_r
		# the base follows the thumb so the stick never "runs out"
		if d.length() > 1.25:
			stick_origin = pos - d.normalized() * stick_r * 1.25
			d = d.normalized() * 1.25
		var v := d.limit_length(1.0)
		Controls.touch_move = Vector2(v.x, -v.y)
		pad.queue_redraw()
	elif role is String and role == "look":
		Controls.touch_look += rel
	else:
		# sliding off one button onto a neighbour (e.g. jump -> boost) transfers the press
		var cur: Dictionary = buttons[role]
		if pos.distance_to(cur.pos) > cur.radius * 1.6:
			for i in buttons.size():
				var b: Dictionary = buttons[i]
				if i != role and b.name != "pause" and pos.distance_to(b.pos) < b.radius * 1.1:
					_up(idx)
					_down(idx, pos)
					return

func _up(idx: int) -> void:
	if not touches.has(idx):
		return
	var role = touches[idx]
	touches.erase(idx)
	if role is String:
		if role == "stick":
			stick_on = false
			Controls.touch_move = Vector2.ZERO
	else:
		var b: Dictionary = buttons[role]
		var still := false
		for other in touches.values():
			if not (other is String) and other == role:
				still = true
		if not still:
			b.down = false
			for a in b.actions:
				Input.action_release(a)
	pad.queue_redraw()

func draw_pad(c: Control) -> void:
	var alpha: float = Game.settings["touch_opacity"]
	var font := ThemeDB.fallback_font
	for b in buttons:
		var col := Color(0.2, 0.9, 0.95, alpha * 0.9) if b.down else Color(0.05, 0.15, 0.25, alpha * 0.55)
		if b.name == "boost" and not b.down:
			col = Color(0.5, 0.3, 0.05, alpha * 0.6)
		c.draw_circle(b.pos, b.radius, col)
		c.draw_arc(b.pos, b.radius, 0.0, TAU, 40, Color(1, 1, 1, alpha), 3.0, true)
		var fs := int(b.radius * 0.36)
		var tw := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		c.draw_string(font, b.pos + Vector2(-tw * 0.5, fs * 0.36), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))
	if stick_on:
		c.draw_circle(stick_origin, stick_r, Color(0.05, 0.15, 0.25, alpha * 0.4))
		c.draw_arc(stick_origin, stick_r, 0.0, TAU, 48, Color(1, 1, 1, alpha * 0.8), 3.0, true)
		var k := stick_origin + (stick_pos - stick_origin).limit_length(stick_r)
		c.draw_circle(k, stick_r * 0.42, Color(0.3, 0.95, 0.95, alpha))
	else:
		var sz := _size()
		var home := Vector2(sz.x - 170.0 * stick_r / 95.0, sz.y - 170.0 * stick_r / 95.0) if Game.settings["touch_swap"] else Vector2(170.0 * stick_r / 95.0, sz.y - 170.0 * stick_r / 95.0)
		c.draw_arc(home, stick_r, 0.0, TAU, 48, Color(1, 1, 1, alpha * 0.35), 3.0, true)
		c.draw_circle(home, stick_r * 0.42, Color(1, 1, 1, alpha * 0.2))
