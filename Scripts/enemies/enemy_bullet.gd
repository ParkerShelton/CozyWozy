extends Area3D

var speed: float = 9.0  # Slow projectile
var damage: float = 10.0
var lifetime: float = 5.0  # Despawn after 5 seconds
var direction: Vector3 = Vector3.FORWARD

func _ready():
	# Visual - big glowing ball
	var mesh_instance = $MeshInstance3D
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mesh_instance.mesh = sphere
	
	# Make it glow
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.0, 0.6, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.2, 0.8, 1.0)
	material.emission_energy_multiplier = 2.0
	mesh_instance.material_override = material
	
	# Collision
	var collision = $CollisionShape3D
	var shape = SphereShape3D.new()
	shape.radius = 0.3
	collision.shape = shape
	
	collision_layer = 0
	collision_mask = 1 | 8 # Only detect layer 1 (terrain) and layer 4 (player)
	
	# Connect hit detection
	body_entered.connect(_on_body_entered)
	
	# Auto-despawn timer
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	# Move forward
	global_position += direction * speed * delta

func _on_body_entered(body):
	# Hit the player
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	
	# Hit terrain or other objects
	elif body.is_in_group("ground") or body.collision_layer & 1:
		queue_free()
