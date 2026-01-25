extends Node3D

var item_name : String = ""
var quantity : int = 1
var icon : Texture2D = null
var can_pickup : bool = false
var is_magnetizing : bool = false
var player : Node3D = null
var player_has_left : bool = false
var require_player_exit : bool = false  # NEW: Only required for dropped items

@export var magnetize_speed : float = 10.0
@export var magnetize_distance : float = 3.0
@export var pickup_delay : float = 1.0

func _ready():
	add_to_group("pickable")
	
	# Create Area3D for magnetizing
	var area = Area3D.new()
	add_child(area)
	
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = magnetize_distance
	collision.shape = sphere
	area.add_child(collision)
	
	# Connect signals
	await get_tree().process_frame
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	
	# Check if player is already in range when spawned
	await get_tree().process_frame
	var overlapping_bodies = area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("player"):
			player = body
			if not require_player_exit:
				is_magnetizing = true
	
	# Delay pickup
	await get_tree().create_timer(pickup_delay).timeout
	can_pickup = true

func _process(delta):
	var can_magnetize = is_magnetizing and player and can_pickup
	if require_player_exit:
		can_magnetize = can_magnetize and player_has_left
	
	if can_magnetize:
		var direction = (player.global_position - global_position).normalized()
		global_position += direction * magnetize_speed * delta
		
		if global_position.distance_to(player.global_position) < 0.5:
			pickup()

func setup(item_name: String, quantity: int, icon: Texture2D, from_drop: bool = false):
	self.item_name = item_name
	self.quantity = quantity
	self.icon = icon
	self.require_player_exit = from_drop
	
	if has_node("Sprite3D"):
		var sprite = $Sprite3D
		sprite.texture = icon
		sprite.pixel_size = 0.01
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _on_body_entered(body: Node3D):
	var can_start_magnetizing = body.is_in_group("player") and can_pickup
	if require_player_exit:
		can_start_magnetizing = can_start_magnetizing and player_has_left
	
	if can_start_magnetizing:
		player = body
		is_magnetizing = true

func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_has_left = true
		is_magnetizing = false
		player = null

func pickup():
	if can_pickup:
		if Inventory.add_item(item_name, icon, quantity):
			queue_free()
			return true
	return false
