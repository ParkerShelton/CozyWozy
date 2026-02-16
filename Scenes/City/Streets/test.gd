# measure_street_size.gd
# Attach this to any node and run the scene, check the console output

extends Node

func _ready():
	# Load your street piece
	var street_scene = load("res://Scenes/City/Streets/street_straight.tscn")
	var street = street_scene.instantiate()
	add_child(street)
	
	await get_tree().process_frame
	
	# Find the mesh using find_child (built-in, no recursion)
	var mesh_instance = street.find_child("*", true, false)
	
	if mesh_instance is MeshInstance3D and mesh_instance.mesh:
		var aabb = mesh_instance.mesh.get_aabb()
		print("=== STREET PIECE SIZE ===")
		print("Width (X): ", aabb.size.x)
		print("Height (Y): ", aabb.size.y)
		print("Depth (Z): ", aabb.size.z)
		print("========================")
		
		# Calculate how many fit in a block
		var block_size = 40.0
		print("Pieces per block (X): ", block_size / aabb.size.x)
		print("Pieces per block (Z): ", block_size / aabb.size.z)
		print("")
		print("USE THIS NUMBER: straights_per_block = ", int(block_size / max(aabb.size.x, aabb.size.z)))
	else:
		print("ERROR: Could not find MeshInstance3D in street_straight.tscn")
		print("Children: ", street.get_children())
	
	street.queue_free()
