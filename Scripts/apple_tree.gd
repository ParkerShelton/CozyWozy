extends Node3D

var tree_health : int = 20
var current_health : int
var is_chopped : bool = false
var is_being_destroyed: bool = false

var fall_duration : float = 0.75

var min_logs : int = 2
var max_logs : int = 5
var min_plant_fiber : int = 0
var max_plant_fiber : int = 2

var has_been_hit: bool = false
var bird_spawn_chance: float = 0.1
var min_birds: int = 1
var max_birds: int = 4

@onready var trunk = $apple_tree/trunk
@onready var leaves = $apple_tree/leaves
@onready var stump = $apple_tree/stump

var hit_particles: GPUParticles3D
var bark_particles: GPUParticles3D
var leaf_particles: GPUParticles3D

@export var leaf_texture: Texture2D
var disable_drops: bool = false

func _ready():
	current_health = tree_health

	create_bark_particles()
	create_leaf_particles()

func take_damage(dmg):
	if is_chopped:
		return
	
	if not has_been_hit:
		has_been_hit = true
		try_spawn_birds()
	
	current_health -= dmg
	if current_health <= 0:
		chop_down()
	else:
		shake_tree()

func try_spawn_birds():
	if randf() > bird_spawn_chance:
		return
	
	var bird_scene = load("res://Scenes/Animals/bird.tscn")
	if not bird_scene:
		return
	
	var num_birds = randi_range(min_birds, max_birds)
	
	for i in range(num_birds):
		var bird = bird_scene.instantiate()
		get_tree().root.add_child(bird)
		
		# Spawn at the leaves with a random offset
		var offset = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-0.5, 0.5),
			randf_range(-1.0, 1.0)
		)
		bird.global_position = leaves.global_position + offset

func chop_down():
	if is_being_destroyed:
		return
	
	is_being_destroyed = true
	is_chopped = true
	
	# BROADCAST TO NETWORK (only if we're host)
	var resource_id = get_meta("resource_id", -1)
	if resource_id != -1 and Network.is_host:
		Network.broadcast_resource_destroyed(resource_id, "trees")
	
	# Create falling animation
	var falling_part = Node3D.new()
	get_parent().add_child(falling_part)
	falling_part.global_position = global_position
	
	var trunk_ref = trunk
	var leaf_ref = leaves
	trunk.reparent(falling_part)
	leaves.reparent(falling_part)
	
	var player = get_tree().get_first_node_in_group("player")
	var fall_angle = 0.0
	
	if player:
		var to_player = player.global_position - global_position
		to_player.y = 0
		fall_angle = atan2(to_player.z, to_player.x)
	
	var tween = create_tween()
	falling_part.rotation.y = fall_angle
	tween.tween_property(falling_part, "rotation:x", PI / 2, fall_duration)
	tween.parallel().tween_property(falling_part, "position:y", 0.5, fall_duration)
	tween.tween_interval(1.5)
	
	tween.tween_callback(func(): spawn_logs(trunk_ref.global_position))
	tween.tween_callback(func(): spawn_apple(trunk_ref.global_position))
	tween.tween_callback(falling_part.queue_free)
	
	tween.tween_callback(func(): create_bark_particles(trunk_ref.global_position))
	tween.tween_callback(func(): create_leaf_particles(leaf_ref.global_position))
	
	remove_from_group("tree")
	
	for child in $apple_tree.get_children():
		if child != $apple_tree/stump:
			child.queue_free()

func destroy_without_drops():
	"""Called when OTHER player destroys this tree"""
	if is_being_destroyed:
		return
	
	is_being_destroyed = true
	is_chopped = true
	
	var falling_part = Node3D.new()
	get_parent().add_child(falling_part)
	falling_part.global_position = global_position
	
	var trunk_ref = trunk
	trunk.reparent(falling_part)
	leaves.reparent(falling_part)
	
	var player = get_tree().get_first_node_in_group("player")
	var fall_angle = 0.0
	
	if player:
		var to_player = player.global_position - global_position
		to_player.y = 0
		fall_angle = atan2(to_player.z, to_player.x)
	
	var tween = create_tween()
	falling_part.rotation.y = fall_angle
	tween.tween_property(falling_part, "rotation:x", PI / 2, fall_duration)
	tween.parallel().tween_property(falling_part, "position:y", 0.5, fall_duration)
	tween.tween_interval(1.5)
	tween.tween_callback(falling_part.queue_free)
	
	remove_from_group("tree")
	$leaves2.queue_free()
	$falling_leaves.queue_free()

func spawn_logs(spawn_position: Vector3):
	if disable_drops:
		return
	var num_logs = randi_range(min_logs, max_logs)
	
	var player = get_tree().get_first_node_in_group("player")
	var fall_angle = 0.0
	if player:
		var to_player = player.global_position - global_position
		to_player.y = 0
		to_player = to_player.normalized()
		fall_angle = atan2(to_player.x, to_player.z) + PI
	
	var fall_direction = Vector3(sin(fall_angle), 0, cos(fall_angle))
	
	var dropped_item_scene = load("res://Scenes/dropped_item.tscn")
	var log_icon = load("res://Assets/Icons/log.png")
	
	for i in range(num_logs):
		if dropped_item_scene:
			var trunk_length = 3.0
			var distance_along_trunk = randf_range(0, trunk_length)
			var side_offset = Vector3(
				randf_range(-0.3, 0.3),
				0,
				randf_range(-0.3, 0.3)
			)
			
			var log_position = spawn_position + (fall_direction * distance_along_trunk) + side_offset
			log_position.y = 0.3
			
			var log_drop = dropped_item_scene.instantiate()
			get_parent().add_child(log_drop)
			log_drop.global_position = log_position
			log_drop.rotation.y = randf_range(0, TAU)
			
			if log_drop.has_method("setup"):
				log_drop.setup("log", 1, log_icon)
			
			if Network.is_host:
				Network.broadcast_item_spawned("log", log_position, 1)

func spawn_apple(spawn_position: Vector3):
	if disable_drops:
		return
	var num_plant_fiber = randi_range(min_plant_fiber, max_plant_fiber)

	var dropped_item_scene = load("res://Scenes/dropped_item.tscn")
	var apple_icon = load("res://Assets/Icons/Craftables/Food/apple.png")

	for i in range(num_plant_fiber):
		if dropped_item_scene:
			var side_offset = Vector3(
				randf_range(-0.3, 0.3),
				0,
				randf_range(-0.3, 0.3)
			)
			var item_position = spawn_position + side_offset
			item_position.y = 0.3
			

			
			var apple = dropped_item_scene.instantiate()
			get_parent().add_child(apple)
			apple.global_position = item_position
			
			if apple.has_method("setup"):
				apple.setup("apple", 1, apple_icon)
			
			if Network.is_host:
				Network.broadcast_item_spawned("apple", item_position, 1)

func shake_tree():
	#hit_pause()

	var tween = create_tween()
	tween.tween_property(self, "rotation:z", 0.1, 0.1)
	tween.tween_property(self, "rotation:z", -0.1, 0.1)
	tween.tween_property(self, "rotation:z", 0, 0.1)
	
	#play_hit_particles()
	play_hit_effects()
	
	
func play_hit_effects():
	if bark_particles:
		bark_particles.restart()

	if leaf_particles:
		leaf_particles.restart()

	# Optional: randomize burst direction slightly
	leaf_particles.rotation.y = randf() * TAU
	bark_particles.rotation.y = randf() * TAU

	



func create_bark_particles(_pos:Vector3 = Vector3(0, 1.2, 0)):
	bark_particles = GPUParticles3D.new()
	add_child(bark_particles)

	bark_particles.amount = 18
	bark_particles.lifetime = 0.6
	bark_particles.one_shot = true
	bark_particles.explosiveness = 1.0
	bark_particles.local_coords = true
	bark_particles.emitting = false
	bark_particles.position = _pos

	var mat = ParticleProcessMaterial.new()
	bark_particles.process_material = mat

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.15

	mat.direction = Vector3(0, 0.5, 0)
	mat.spread = 120.0

	mat.initial_velocity_min = 2.5
	mat.initial_velocity_max = 5.0

	mat.gravity = Vector3(0, -9.0, 0)

	mat.scale_min = 0.05
	mat.scale_max = 0.12

	mat.angular_velocity_min = -10.0
	mat.angular_velocity_max = 10.0

	# Bark colors
	mat.color = Color(0.269, 0.122, 0.07, 1.0)

	var quad = QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	bark_particles.draw_pass_1 = quad

	var draw_mat = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	bark_particles.material_override = draw_mat

func hit_pause():
	Engine.time_scale = 0.01
	await get_tree().create_timer(0.05, true).timeout
	Engine.time_scale = 1.0

func create_leaf_particles(_pos : Vector3 = Vector3(0, 5.0, 0)):
	leaf_particles = GPUParticles3D.new()
	add_child(leaf_particles)

	leaf_particles.amount = 14
	leaf_particles.lifetime = 5.0
	leaf_particles.one_shot = true
	leaf_particles.explosiveness = 1.0
	leaf_particles.local_coords = true
	leaf_particles.emitting = false
	leaf_particles.position = _pos

	var mat = ParticleProcessMaterial.new()
	leaf_particles.process_material = mat

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3

	mat.direction = Vector3(0, 1, 0)
	mat.spread = 360.0

	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5

	mat.gravity = Vector3(0, -2.5, 0)

	mat.scale_min = 0.1
	mat.scale_max = 0.18

	mat.angular_velocity_min = -8.0
	mat.angular_velocity_max = 0.0

	# Leaf colors
	mat.color = Color(0.2, 0.5, 0.15, 1.0)
	var quad = QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	leaf_particles.draw_pass_1 = quad

	var draw_mat = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	if leaf_texture:
		draw_mat.albedo_texture = leaf_texture
	else:
		push_warning("No leaf_texture assigned - particles may appear as solid color!")

	leaf_particles.material_override = draw_mat
