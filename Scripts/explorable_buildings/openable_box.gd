# openable_box.gd
extends Node3D

@export var box_type: String = "scavenger_crate"  # Type of box (matches loot_tables key)
@export var interaction_radius: float = 3.0
@export var open_animation_name: String = "open"  # Name of animation to play
@export var animation_player_path: NodePath = ""

var player_in_range: bool = false
var is_opened: bool = false
var player: Node3D = null

@onready var area_3d: Area3D = $Area3D
var animation_player: AnimationPlayer = null

@onready var label

var was_opened = false

signal box_opened

func _ready():
	add_to_group("openable_boxes")
	
	if box_type == "broken_car":
		label = $Label3D
	else:
		label = $openable_box/Label3D
	
	# Setup AnimationPlayer - try custom path first, then child
	if animation_player_path != NodePath(""):
		animation_player = get_node_or_null(animation_player_path)
		if not animation_player:
			push_error("AnimationPlayer not found at path: " + str(animation_player_path))
	else:
		# Try to find as child
		animation_player = get_node_or_null("AnimationPlayer")
	
	# Setup Area3D if it doesn't exist
	if not area_3d:
		area_3d = Area3D.new()
		add_child(area_3d)
		
		var collision = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = interaction_radius
		collision.shape = sphere
		area_3d.add_child(collision)
	
	# Set collision layers
	area_3d.collision_layer = 0
	area_3d.collision_mask = 8  # Player layer
	
	# Connect signals
	area_3d.body_entered.connect(_on_body_entered)
	area_3d.body_exited.connect(_on_body_exited)
	
	# Validate box type
	if not BoxInventoryManager.box_type_exists(box_type):
		push_error("Invalid box_type: " + box_type)
		box_type = "wooden_crate"  # Fallback to default

func _process(_delta):
	# Check for open input
	if player_in_range and not is_opened and Input.is_action_just_pressed("click"):
		if player and player.has_method("hide_inventory_left_section"):
			player.hide_inventory_left_section()
		open_box()
	if player_in_range and is_opened and Input.is_action_just_pressed("inventory"):
		close_box()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player = body
		player_in_range = true
		show_interaction_prompt(true)

func _on_body_exited(body: Node3D):
	if body == player:
		player = null
		player_in_range = false
		show_interaction_prompt(false)

func open_box():
	if is_opened:
		return
		
	is_opened = true
	
	if animation_player and animation_player.has_animation(open_animation_name):
		animation_player.play(open_animation_name)
		await animation_player.animation_finished
	
	# Generate loot and open UI
	BoxInventoryManager.open_box(box_type)
	box_opened.emit()
	
	# Show box inventory UI
	was_opened = true
	show_box_ui()

func close_box():
	if not is_opened:
		return
	
	if animation_player and animation_player.has_animation(open_animation_name):
		animation_player.play_backwards(open_animation_name)
		await animation_player.animation_finished
		
	is_opened = true
	hide_box_ui()
	get_viewport().set_input_as_handled()

func show_box_ui():
	# Get the BoxInventoryUI node
	var box_ui = get_tree().get_first_node_in_group("box_inventory_ui")
	
	if box_ui and box_ui.has_method("open_box_ui"):
		box_ui.open_box_ui(box_type)
	else:
		push_error("BoxInventoryUI not found in scene!")
		
func hide_box_ui():
	# Get the BoxInventoryUI node
	var box_ui = get_tree().get_first_node_in_group("box_inventory_ui")
	
	if box_ui and box_ui.has_method("close_box_ui"):
		box_ui.close_box_ui()

func show_interaction_prompt(show: bool):
	if label:
		if show:
			label.visible = true
		else:
			label.visible = false
	else:
		print("cant find label3D")

func can_be_looted() -> bool:
	return not is_opened
