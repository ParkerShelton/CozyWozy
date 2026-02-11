# tilled_ground.gd
extends Node3D

var crop: Node3D = null
var tilled_id: String = ""  # Unique ID for this tilled ground

func _ready():
	add_to_group("tilled_ground")
	
	# Generate unique ID based on position
	if tilled_id == "":
		tilled_id = "tilled_" + str(global_position).replace(" ", "_").replace("(", "").replace(")", "").replace(",", "_")
	
	# Add collision if it doesn't exist
	if not has_node("StaticBody3D"):
		var static_body = StaticBody3D.new()
		add_child(static_body)
		
		static_body.collision_layer = 2
		static_body.collision_mask = 0
		
		var collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(2, 0.2, 2)
		collision_shape.shape = box_shape
		collision_shape.disabled = false
		static_body.add_child(collision_shape)

func plant_seed(plant_data: Plant):
	if crop:
		print("Already has a crop!")
		return false
	
	var crop_scene = load("res://Scenes/planted_crop.tscn")
	crop = crop_scene.instantiate()
	add_child(crop)
	crop.plant_seed(plant_data)
	print("Planted ", plant_data.plant_name)
	
	# Save after planting
	save_tilled_ground()
	
	return true

func harvest():
	if crop and crop.is_ready:
		var items = crop.harvest()
		crop = null
		
		# Save after harvesting
		save_tilled_ground()
		
		return items
	return {}

func get_save_data() -> Dictionary:
	var data = {
		"position": global_position,
		"rotation": global_rotation,
		"tilled_id": tilled_id
	}
	
	# Save crop data if exists
	if crop:
		data["has_crop"] = true
		data["crop_plant_name"] = crop.plant.plant_name if crop.plant else ""
		data["crop_growth_timer"] = crop.growth_timer if "growth_timer" in crop else 0.0
		data["crop_is_ready"] = crop.is_ready if "is_ready" in crop else false
	else:
		data["has_crop"] = false
	
	return data

func load_from_data(data: Dictionary):
	global_position = data["position"]
	global_rotation = data["rotation"]
	tilled_id = data["tilled_id"]
	
	# Load crop if it had one
	if data.get("has_crop", false):
		var plant_name = data.get("crop_plant_name", "")
		if plant_name != "":
			var plant_data = PlantManager.get_plant(plant_name)
			if plant_data:
				var crop_scene = load("res://Scenes/planted_crop.tscn")
				crop = crop_scene.instantiate()
				add_child(crop)
				crop.plant_seed(plant_data)
				
				# Restore growth progress
				if "growth_timer" in crop:
					crop.growth_timer = data.get("crop_growth_timer", 0.0)
				if "is_ready" in crop:
					crop.is_ready = data.get("crop_is_ready", false)
					
					# If it was ready, show the grown model
					if crop.is_ready and crop.plant:
						crop.show_model(crop.plant.grown_model_path)

func save_tilled_ground():
	if not WorldManager.current_world_data.has("tilled_grounds"):
		WorldManager.current_world_data["tilled_grounds"] = {}
	
	WorldManager.current_world_data["tilled_grounds"][tilled_id] = get_save_data()
	WorldManager.save_world()
