class_name WorldBase
extends Node3D
## Shared scaffolding for playable spaces: lighting, sky, player and camera.

var is_test := false
var spawn_point := Vector3(0, 2, 0)
var spawn_yaw := 0.0
var sparks: SparkField
var player: Player
var cam: CameraRig
var env: Environment
var sun: DirectionalLight3D
var water_y := -1000.0

func _ready() -> void:
	Game.world = self
	_environment()
	sparks = SparkField.new()
	add_child(sparks)
	_build()
	sparks.build()
	_spawn_player()
	Game.settings_changed.connect(_apply_quality)
	_apply_quality()
	Game.update_objective()

func _build() -> void:
	pass

func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.16, 0.38, 0.78)
	sky_mat.sky_horizon_color = Color(0.72, 0.84, 0.95)
	sky_mat.ground_bottom_color = Color(0.12, 0.3, 0.45)
	sky_mat.ground_horizon_color = Color(0.72, 0.84, 0.95)
	sky_mat.sun_angle_max = 12.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.82, 0.95)
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-42), deg_to_rad(-35), 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.35
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_bias = 0.06
	add_child(sun)

func _apply_quality() -> void:
	var q := int(Game.settings["quality"])
	sun.shadow_enabled = q >= 1
	sun.directional_shadow_max_distance = 110.0 if q == 1 else 180.0
	env.glow_enabled = q >= 2
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	if cam != null:
		cam.cam.far = [700.0, 1200.0, 1800.0][q]

func _spawn_player() -> void:
	player = Player.new()
	add_child(player)
	cam = CameraRig.new()
	add_child(cam)
	cam.target = player
	player.kill_y = water_y - 1.5 if water_y > -999.0 else -60.0
	var p := spawn_point
	if Game.has_checkpoint and not is_test:
		p = Game.checkpoint_pos
	player.facing = Vector3(-sin(spawn_yaw), 0, -cos(spawn_yaw))
	player.teleport(p + Vector3(0, 1.0, 0))
