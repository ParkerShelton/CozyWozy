# building_piece.gd
# Attach this to the ROOT NODE of every building piece scene
extends Node3D
class_name BuildingPiece

@export var piece_name: String = ""  # e.g. "wood_floor", "wood_wall"
var piece_data: Dictionary = {}
var snap_points: Array = []  # Local snap point positions
var is_preview: bool = false

func _ready():
	if piece_name != "":
		load_piece_data()
	
	# Set collision layers for any StaticBody3D children
	if not is_preview:
		for child in get_children():
			if child is StaticBody3D:
				child.collision_layer = 2  # Building layer
				child.collision_mask = 0

func load_piece_data():
	piece_data = BuildingManager.get_piece_data(piece_name)
	if piece_data.is_empty():
		push_error("BuildingPiece: No data found for '%s'" % piece_name)
		return
	
	# Parse snap points from JSON
	var snap_data = piece_data.get("snap_points", [])
	for snap in snap_data:
		var pos_dict = snap.get("position", {})
		var position = Vector3(
			pos_dict.get("x", 0.0),
			pos_dict.get("y", 0.0),
			pos_dict.get("z", 0.0)
		)
		snap_points.append({
			"position": position,
			"type": snap.get("type", ""),
			"direction": snap.get("direction", "")
		})

# Get world-space snap points
func get_world_snap_points() -> Array:
	var world_points = []
	for snap in snap_points:
		world_points.append({
			"position": global_transform * snap.position,
			"type": snap.type,
			"direction": snap.direction
		})
	return world_points

# Visual feedback for preview mode
func set_valid(valid: bool):
	if not is_preview:
		return
	
	# Change material to show valid/invalid
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0, 1, 0, 0.5) if valid else Color(1, 0, 0, 0.5)
	
	# Apply to all mesh children
	for child in get_children():
		if child is MeshInstance3D:
			child.material_override = material
