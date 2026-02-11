extends RigidBody3D

var damage: float = 5.0
var lifetime: float = 5.0
var thrown_by_slingshot: bool = false
var has_hit: bool = false

func _ready():
	# Set physics properties
	gravity_scale = 1.0
	contact_monitor = true
	max_contacts_reported = 5
	
	# Connect collision signal
	body_entered.connect(_on_body_entered)
	
	# If you have a 3D model, load it here
	# The model should already be in your scene as a child (MeshInstance3D)
	# Or load it programmatically:
	# var model_scene = load("res://Models/pebble_model.tscn")
	# var model = model_scene.instantiate()
	# add_child(model)
	
	# Auto-despawn timer
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	# Rotate for visual effect while flying
	if not has_hit:
		rotate(linear_velocity.normalized(), delta * 10.0)

func _on_body_entered(body):
	if has_hit:
		return
	
	# Hit an enemy
	var target = body
	while target and target.get_groups().size() == 0 and target.get_parent():
		target = target.get_parent()
	
	if target.is_in_group("enemies"):
		if target.has_method("take_damage"):
			var actual_damage = damage * 2.0 if thrown_by_slingshot else damage
			target.take_damage(actual_damage)
			print("Rock hit enemy for ", actual_damage, " damage!")
		
		has_hit = true
		# Optional: stick to enemy or fall to ground
		queue_free()
	
	# Hit the ground or other objects
	elif body.is_in_group("ground") or body.collision_layer & 1:
		has_hit = true
		# Rock bounces/rolls on ground naturally with RigidBody physics
		# Despawn after a moment
		await get_tree().create_timer(2.0).timeout
		queue_free()
