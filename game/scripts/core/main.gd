extends Node
## Entry point: title menu <-> world. `-- --test` runs the automated movement
## suite headlessly; `-- --arena` / `-- --island` jump straight into a world.

var world: Node = null
var hud: Node = null
var menu: Node = null
var touch: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.apply_settings()
	var args := OS.get_cmdline_user_args()
	if "--test" in args:
		start_world("arena")
		var t: Node = load("res://scripts/tests/movement_tests.gd").new()
		add_child(t)
	elif "--test-island" in args:
		Game.reset_progress()
		start_world("island")
		var t: Node = load("res://scripts/tests/island_tests.gd").new()
		add_child(t)
	elif "--arena" in args:
		start_world("arena")
	elif "--island" in args:
		start_world("island")
	else:
		show_title()
	if "--touch" in args:
		Game.settings["touch_mode"] = 1
		Game.apply_settings()
	if "--settings" in args and menu != null:
		menu.open_settings()
	for a in args:
		if a.begins_with("--shot="):
			_shots(a.trim_prefix("--shot="), args)

## Dev helper: `--shot=dir [--at=x,y,z,yaw]...` saves screenshots and quits.
func _shots(dir: String, args: Array) -> void:
	var spots: Array = []
	for a in args:
		if a.begins_with("--at="):
			spots.append(a.trim_prefix("--at=").split_floats(","))
	if spots.is_empty():
		spots.append(PackedFloat64Array())
	var i := 0
	for sp in spots:
		if sp.size() >= 3 and Game.player != null:
			var y: float = sp[1]
			if y <= 0.0 and Game.world.has_method("ground_y"):
				y = Game.world.ground_y(sp[0], sp[2]) + 1.0 - y     # y<=0: metres above the ground
			Game.player.teleport(Vector3(sp[0], y, sp[2]))
			if sp.size() >= 4:
				Game.camera.yaw = sp[3]
			if sp.size() >= 5:
				Game.camera.pitch = sp[4]
			Game.camera.manual_t = 99.0
		for f in 50:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/shot%d.png" % [dir, i])
		i += 1
	get_tree().quit()

func show_title() -> void:
	get_tree().paused = false
	_clear()
	menu = load("res://scripts/ui/menus.gd").new()
	add_child(menu)
	menu.open_title(self)

func start_world(kind: String) -> void:
	get_tree().paused = false
	_clear()
	world = TestArena.new() if kind == "arena" else load("res://scripts/world/island.gd").new()
	add_child(world)
	hud = load("res://scripts/ui/hud.gd").new()
	add_child(hud)
	if ResourceLoader.exists("res://scripts/ui/touch_controls.gd"):
		touch = load("res://scripts/ui/touch_controls.gd").new()
		add_child(touch)
	if ResourceLoader.exists("res://scripts/ui/menus.gd"):
		menu = load("res://scripts/ui/menus.gd").new()
		add_child(menu)
		menu.attach_game(self)

func _clear() -> void:
	for n in [world, hud, menu, touch]:
		if n != null and is_instance_valid(n):
			n.queue_free()
			remove_child(n)
	world = null
	hud = null
	menu = null
	touch = null
	Game.world = null
	Game.player = null
	Game.camera = null
	Controls.touch_move = Vector2.ZERO
