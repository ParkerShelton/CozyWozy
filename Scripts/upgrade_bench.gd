extends Node3D

var player_nearby = false

# Called when the node enters the scene tree for the first time.
func _ready():
	$upgrade_bench/AnimationPlayer.play("float")


func _input(event):
	if player_nearby and event.is_action_pressed("click"):
		pickup()
		pass

func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		$Label3D.visible = true
		
func _on_area_3d_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		$Label3D.visible = false

func pickup():
	var dropped_item_scene = load("res://Scenes/dropped_item.tscn")
	var log_icon = load("res://Assets/Icons/log.png")
	
	var upgrade_bench = dropped_item_scene.instantiate()
	get_parent().add_child(upgrade_bench)
	upgrade_bench.global_position = global_position
	
	if upgrade_bench.has_method("setup"):
		upgrade_bench.setup("upgrade_bench", 1, log_icon)

	queue_free()
	
	
	
	
	
