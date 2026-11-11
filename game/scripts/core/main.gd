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
