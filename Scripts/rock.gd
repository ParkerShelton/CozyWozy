extends Node3D

var rock_health : int = 4
var current_health : int
var is_broken : bool = false

var min_pebbles : int = 1
var max_pebbles : int = 3


func _ready():
	current_health = rock_health

	var num_rock = randi_range(1,3)
	var rock = get_node("rock_" + str(num_rock))
	rock.rotation.y = randf_range(0, TAU) 
	rock.visible = true

func take_damage(dmg):
	if is_broken:
		return
		
	current_health -= dmg
	if current_health <= 0:
		break_rock()
	else:
		shake_rock()

func break_rock():
	is_broken = true
	remove_from_group("rock")
	spawn_pebbles()
	queue_free()

func spawn_pebbles():
	var num_pebbles = randi_range(min_pebbles, max_pebbles)
	
	# Load the generic dropped item scene and pebble icon
	var dropped_item_scene = load("res://Scenes/dropped_item.tscn")
	var pebble_icon = load("res://Assets/Icons/pebble.png")  # Adjust path
	
	for i in range(num_pebbles):
		if dropped_item_scene:
			var pebble = dropped_item_scene.instantiate()
			get_parent().add_child(pebble)
			
			var side_offset = Vector3(
				randf_range(-0.3, 0.3),
				0,
				randf_range(-0.3, 0.3)
			)
			
			pebble.global_position = global_position + side_offset
			pebble.global_position.y = 0.3
			
			# Setup the pebble
			if pebble.has_method("setup"):
				pebble.setup("pebble", 1, pebble_icon)
			else:
				print("ERROR: Pebble doesn't have setup method!")
			
			pebble.rotation.y = randf_range(0, TAU)


func shake_rock():
	var tween = create_tween()
	tween.tween_property(self, "rotation:z", 0.1, 0.1)
	tween.tween_property(self, "rotation:z", -0.1, 0.1)
	tween.tween_property(self, "rotation:z", 0, 0.1)	
