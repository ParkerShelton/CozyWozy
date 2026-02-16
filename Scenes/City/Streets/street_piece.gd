# street_piece.gd
extends Node3D

@export var clear_radius: float = 20.0  # How far to clear around this street piece

func _ready():
	
	var rand = randi_range(0,200)
	if rand < 150:
		$street_straight2.visible = true
		$street_straight_2.visible = false
		$street_straight_3.visible = false
	elif rand > 150 and rand < 175:
		$street_straight_2.visible = true
		$street_straight2.visible = false
		$street_straight_3.visible = false
	elif rand > 175:
		$street_straight_3.visible = true
		$street_straight2.visible = false
		$street_straight_2.visible = false
	
	# Clear once on spawn
	call_deferred("clear_foliage")
	
	# Set up Area3D to catch anything that spawns later
	call_deferred("setup_clearing_area")

func setup_clearing_area():
	var area = Area3D.new()
	area.name = "FoliageClearer"
	add_child(area)
	
	# Large box covering the street
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(clear_radius * 2, 10, clear_radius * 2)
	collision.shape = box
	area.add_child(collision)
	
	# IMPORTANT: Set collision layers to detect trees
	area.collision_layer = 0  # This area is on no layers (invisible to others)
	area.collision_mask = 1   # Detect layer 1 (where trees/rocks are)
	
	# Monitor for bodies entering
	area.monitoring = true
	area.monitorable = false
	
	# Connect to detect foliage
	area.body_entered.connect(_on_body_entered)
	area.area_entered.connect(_on_area_entered)

func _on_body_entered(body: Node):
	# Delete any foliage that enters
	if body.is_in_group("trees") or body.is_in_group("rocks") or body.is_in_group("grass") or body.is_in_group("apple_tree"):
		body.queue_free()

func _on_area_entered(area: Node):
	# Some foliage might use Area3D - check parent
	var parent = area.get_parent()
	if parent and (parent.is_in_group("trees") or parent.is_in_group("rocks") or parent.is_in_group("grass") or parent.is_in_group("apple_tree")):
		parent.queue_free()

func clear_foliage():
	if not is_inside_tree():
		return
	
	var trees = get_tree().get_nodes_in_group("trees")
	for tree in trees:
		if is_instance_valid(tree) and tree.global_position.distance_to(global_position) < clear_radius:
			tree.queue_free()
	
	var rocks = get_tree().get_nodes_in_group("rocks")
	for rock in rocks:
		if is_instance_valid(rock) and rock.global_position.distance_to(global_position) < clear_radius:
			rock.queue_free()
	
	var apple_trees = get_tree().get_nodes_in_group("apple_tree")
	for apple_tree in apple_trees:
		if is_instance_valid(apple_tree) and apple_tree.global_position.distance_to(global_position) < clear_radius:
			apple_tree.queue_free()
	
	var grass = get_tree().get_nodes_in_group("grass")
	for grass_item in grass:
		if is_instance_valid(grass_item) and grass_item.global_position.distance_to(global_position) < clear_radius:
			grass_item.queue_free()
