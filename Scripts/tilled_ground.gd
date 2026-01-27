# tilled_ground.gd
extends Node3D

var crop: Node3D = null

func _ready():
	add_to_group("tilled_ground")
	
	# Add collision if it doesn't exist
	if not has_node("StaticBody3D"):
		var static_body = StaticBody3D.new()
		add_child(static_body)
		
		# Set to layer 2 (not layer 1 where player collides)
		static_body.collision_layer = 2  # This is what layer it's ON
		static_body.collision_mask = 0   # This is what it collides WITH (0 = nothing)
		
		var collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(2, 0.2, 2)  # Adjust size to match your tilled ground
		collision_shape.shape = box_shape
		collision_shape.disabled = false
		static_body.add_child(collision_shape)	

func plant_seed(plant_data: Plant):
	if crop:
		print("Already has a crop!")
		return false  # Return false if planting failed
	
	var crop_scene = load("res://Scenes/planted_crop.tscn")
	crop = crop_scene.instantiate()
	add_child(crop)
	crop.plant_seed(plant_data)
	print("Planted ", plant_data.plant_name)
	return true  # Return true if planting succeeded

func harvest():
	if crop and crop.is_ready:
		var items = crop.harvest()
		crop = null
		return items
	return {}
