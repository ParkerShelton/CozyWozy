extends Node3D

var health: float = 5.0

func _ready():
	add_to_group("fences")
	add_to_group("placed_objects")

	if not has_node("StaticBody3D"):
		var static_body = StaticBody3D.new()
		add_child(static_body)
		
		static_body.collision_layer = 1
		static_body.collision_mask = 0
		
		var collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(2, 2, 0.2)  # Adjust to fence size
		collision_shape.shape = box_shape
		static_body.add_child(collision_shape)


func take_damage(damage: float):
	health -= damage
	
	if health <= 0:
		break_fence()

func break_fence():
	
	# Drop fence as item
	var dropped_item_scene = load("res://Scenes/dropped_item.tscn")
	if dropped_item_scene:
		var dropped_item = dropped_item_scene.instantiate()
		get_tree().root.add_child(dropped_item)
		
		# Position slightly above where fence was
		dropped_item.global_position = global_position + Vector3(0, 0.5, 0)
		
		# Get fence icon
		var fence_icon = ItemManager.get_item_icon("fence")
		
		# Setup dropped item
		if dropped_item.has_method("setup"):
			dropped_item.setup("fence", 1, fence_icon, true)
	
	# Remove fence from world
	queue_free()

func get_save_data() -> Dictionary:
	return {
		"item_name": "fence",
		"position": global_position,
		"rotation": global_rotation
	}
