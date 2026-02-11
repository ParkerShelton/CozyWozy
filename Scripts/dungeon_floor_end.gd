# dungeon_floor_end.gd
extends Node3D

@onready var area = $Area3D
var player_nearby = false

func _ready():
	add_to_group("dungeon_exit")
	
	# Create Area3D for detection if it doesn't exist
	if not has_node("Area3D"):
		area = Area3D.new()
		add_child(area)
		
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(2, 0.5, 2)
		collision.shape = shape
		area.add_child(collision)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	
	# Visual indicator - make it glow or different color
	var mesh = get_node_or_null("MeshInstance3D")
	if mesh:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 1.0, 0.2)  # Green
		material.emission_enabled = true
		material.emission = Color(0.1, 0.5, 0.1)
		material.emission_energy_multiplier = 2.0
		mesh.material_override = material

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		print("Press E to exit dungeon")

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false

func _input(event):
	if player_nearby and event.is_action_pressed("interact"):
		exit_dungeon()

func exit_dungeon():
	print("Exiting dungeon...")
	# Teleport player back to overworld or next area
	#get_tree().change_scene_to_file("res://Scenes/main.tscn")
