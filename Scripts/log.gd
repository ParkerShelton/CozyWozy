extends Node3D

var magnetize_speed : float = 10.0
var magnetize_distance : float = 3.0

var is_magnetizing : bool = false
var player : Node3D = null
var area : Area3D

var item_name : String = "log"
var item_icon = preload("res://Assets/Icons/log.png")

func _ready():
	var random_delay = randf_range(0.1, 0.5)
	await get_tree().create_timer(random_delay).timeout
	$AnimationPlayer.play("idle")
	
	area = $Area3D  # Adjust path if needed
	area.body_entered.connect(on_body_entered)
	area.body_exited.connect(on_body_exited)

func _process(delta):
	if is_magnetizing and player:
		# Move towards the player
		var direction = (player.global_position - global_position).normalized()
		global_position += direction * magnetize_speed * delta
		
		# Check if close enough to collect
		if global_position.distance_to(player.global_position) < 0.5:
			collect()

func on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player = body
		is_magnetizing = true

func on_body_exited(body: Node3D):
	if body == player:
		is_magnetizing = false
		player = null

func collect():
	Inventory.add_item(item_name, item_icon, 1)
	queue_free()
