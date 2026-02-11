# base_trap.gd
extends Node3D

@export var trap_categories: Array[String] = ["wild"]  # Multiple categories allowed
@export var trigger_range: float = 1.5

var is_triggered: bool = false
var trapped_animal: Node3D = null

# Node references
@onready var door = get_node_or_null("Door")
@onready var net = get_node_or_null("Net")
@onready var rope = get_node_or_null("Rope")

func _ready():
	add_to_group("traps")
	
	# Setup trigger area
	var area = Area3D.new()
	area.name = "TriggerArea"
	add_child(area)
	area.collision_layer = 0
	area.collision_mask = 16  # Animal layer
	
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = trigger_range
	collision.shape = sphere
	area.add_child(collision)
	
	area.body_entered.connect(_on_animal_entered)
	
	print("Trap ready - Categories: ", trap_categories, " Range: ", trigger_range)

func _on_animal_entered(body):
	if is_triggered:
		return
	
	# Walk up tree to find animal
	var animal = body
	while animal and not animal.is_in_group("animals") and animal.get_parent():
		animal = animal.get_parent()
	
	if not animal.is_in_group("animals"):
		return
	
	if not "animal_id" in animal:
		return
	
	# Check if this trap can catch this animal
	var animal_data = AnimalManager.get_animal_data(animal.animal_id)
	var animal_trap_category = animal_data.get("trap_category", "")
	
	# Check if animal's category is in our accepted categories
	if not trap_categories.has(animal_trap_category):
		print("Can't catch this animal. Trap accepts: ", trap_categories, " Animal needs: ", animal_trap_category)
		return
	
	# TRAP TRIGGERED!
	trigger_trap(animal)

func trigger_trap(animal: Node3D):
	is_triggered = true
	trapped_animal = animal
	
	print("✓ Trapped: ", animal.animal_id, " (category: ", AnimalManager.get_animal_data(animal.animal_id).get("trap_category"), ")")
	
	# Stop animal movement
	if animal.has_method("become_trapped"):
		animal.become_trapped(self)
	
	# Visual feedback
	play_trap_animation()

func play_trap_animation():
	# You can make this smarter based on what categories it catches
	if trap_categories.has("hostile"):
		animate_cage()
	elif trap_categories.size() > 2:
		animate_rope_net()  # Universal trap
	else:
		animate_snare()

func animate_snare():
	if rope:
		var tween = create_tween()
		tween.tween_property(rope, "scale:x", 0.5, 0.3)

func animate_rope_net():
	if net:
		var tween = create_tween()
		tween.tween_property(net, "position:y", 0.0, 0.4)

func animate_cage():
	if door:
		var tween = create_tween()
		tween.tween_property(door, "rotation:y", deg_to_rad(-90), 0.3)

func release_animal():
	if trapped_animal and is_instance_valid(trapped_animal):
		if trapped_animal.has_method("become_free"):
			trapped_animal.become_free()
		trapped_animal = null
	
	is_triggered = false
	queue_free()

# Helper to set categories from item data
func setup_from_item(item_name: String):
	var item_data = ItemManager.get_item_data(item_name)
	trap_categories = item_data.get("trap_categories", ["wild"])
	print("Trap configured for categories: ", trap_categories)
