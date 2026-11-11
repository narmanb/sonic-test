class_name Trigger
extends Area3D
## Base for things the player touches. Subclasses implement _touch(player).

func setup_sphere(radius: float, offset: Vector3 = Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	cs.position = offset
	add_child(cs)
	_init_area()

func setup_box(size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = offset
	add_child(cs)
	_init_area()

func _init_area() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body)

func _on_body(b: Node) -> void:
	if b is Player and b.state != Player.St.DEAD:
		_touch(b)

func _touch(_p: Player) -> void:
	pass
