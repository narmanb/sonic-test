extends Node
## Unified input layer: keyboard, gamepad and touchscreen all feed the same
## actions. Tests can set `override` to drive the player deterministically.

signal input_mode_changed(touch: bool)

var touch_move := Vector2.ZERO      # set by TouchControls (x right, y forward)
var touch_look := Vector2.ZERO      # accumulated drag in pixels, consumed by camera
var override = null                 # Dictionary or null
var using_touch := false
var mouse_look := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	using_touch = DisplayServer.is_touchscreen_available()
	_act("jump", [KEY_SPACE], [JOY_BUTTON_A])
	_act("attack", [KEY_J, KEY_E], [JOY_BUTTON_X])
	_act("boost", [KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER], [JOY_AXIS_TRIGGER_RIGHT])
	_act("spin", [KEY_K, KEY_CTRL], [JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER], [JOY_AXIS_TRIGGER_LEFT])
	_act("stomp", [KEY_K, KEY_CTRL], [JOY_BUTTON_B, JOY_BUTTON_Y])
	_act("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_axis("move_left", KEY_A, JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", KEY_D, JOY_AXIS_LEFT_X, 1.0)
	_axis("move_fwd", KEY_W, JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", KEY_S, JOY_AXIS_LEFT_Y, 1.0)
	_axis("look_left", KEY_LEFT, JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", KEY_RIGHT, JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", KEY_UP, JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", KEY_DOWN, JOY_AXIS_RIGHT_Y, 1.0)

func _act(action: String, keys: Array, buttons: Array, axes: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.4)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(action, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = a
		e.axis_value = 1.0
		InputMap.action_add_event(action, e)

func _axis(action: String, key: int, axis: int, value: float) -> void:
	InputMap.add_action(action, 0.18)
	var k := InputEventKey.new()
	k.physical_keycode = key
	InputMap.action_add_event(action, k)
	var m := InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = value
	InputMap.action_add_event(action, m)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_touch(true)
	elif event is InputEventJoypadButton or event is InputEventKey:
		_set_touch(false)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_set_touch(false)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		mouse_look += event.relative

func _set_touch(t: bool) -> void:
	if t != using_touch:
		using_touch = t
		input_mode_changed.emit(t)

func get_move() -> Vector2:
	if override != null:
		return override.get("move", Vector2.ZERO)
	var v := Input.get_vector("move_left", "move_right", "move_back", "move_fwd")
	if touch_move.length() > v.length():
		v = touch_move
	return v.limit_length(1.0)

func get_look() -> Vector2:
	if override != null:
		return Vector2.ZERO
	return Input.get_vector("look_left", "look_right", "look_up", "look_down")

func take_drag_look() -> Vector2:
	var v := touch_look + mouse_look
	touch_look = Vector2.ZERO
	mouse_look = Vector2.ZERO
	return v

func held(action: String) -> bool:
	if override != null:
		return override.get(action, false)
	return Input.is_action_pressed(action)
