# planted_crop.gd
extends Node3D

var plant: Plant = null
var growth_timer: float = 0.0
var is_ready: bool = false
var model: Node3D = null

func _ready():
	add_to_group("planted_crops")
	
	var static_body = StaticBody3D.new()
	add_child(static_body)
	
	# Set to layer 2 (clickable but not blocking)
	static_body.collision_layer = 2
	static_body.collision_mask = 0
	
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1, 1, 1)  # Adjust size to match your plant
	collision_shape.shape = box_shape
	collision_shape.position = Vector3(0, 0.5, 0)  # Raise it up a bit
	static_body.add_child(collision_shape)	

func plant_seed(plant_data: Plant):
	plant = plant_data
	growth_timer = 0.0
	is_ready = false
	
	# Show the seed model immediately
	show_model(plant.seed_model_path)

func show_model(model_path: String):
	# Remove old model
	if model:
		model.queue_free()
		model = null
	
	# Load and show new model
	if model_path != "":
		var model_scene = load(model_path)
		if model_scene:
			model = model_scene.instantiate()
			add_child(model)
		else:
			print("Could not load model: ", model_path)

func _process(delta):
	if plant and not is_ready:
		growth_timer += delta
		var progress = growth_timer / plant.growth_time
		
		# Switch to growing model at 50% if available
		if progress >= 0.5 and progress < 1.0 and plant.growing_model_path != "":
			if model and model.scene_file_path != plant.growing_model_path:
				show_model(plant.growing_model_path)
		
		# Switch to grown model when complete
		if growth_timer >= plant.growth_time:
			is_ready = true
			show_model(plant.grown_model_path)
			print("Plant is ready to harvest!")

func harvest() -> Dictionary:
	if is_ready:
		queue_free()
		return {
			"crop": {"item": plant.harvest_item, "amount": plant.harvest_amount, "icon": plant.harvest_icon},
			"seeds": {"item": plant.plant_name, "amount": plant.seed_return_amount, "icon": plant.icon}
		}
	return {}
