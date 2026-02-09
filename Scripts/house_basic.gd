extends Node3D

@onready var anim_player = $house_basic/AnimationPlayer
@onready var floating_popup = $Label3D
@onready var spawn_point = $spawn_point

var player_nearby: bool = false
var is_preview: bool = false

func _ready():
	if floating_popup:
		floating_popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		floating_popup.visible = false
		
	$Area3D.monitoring = !is_preview
	
	if not is_preview:
		# Only connect signals on the real placed instance
		$Area3D.body_entered.connect(_on_area_3d_body_entered)
		$Area3D.body_exited.connect(_on_area_3d_body_exited)


func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		anim_player.play("Cube_007Action")
		
		# SHOW the popup
		if floating_popup:
			floating_popup.visible = true

func _on_area_3d_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		anim_player.play_backwards("Cube_007Action")
		
		# HIDE the popup
		if floating_popup:
			floating_popup.visible = false

# Check for input in _input or _process
func _input(event):
	if not player_nearby:
		return
	
	if Input.is_action_just_pressed("rotate_clockwise"):
		enter_house()
		
		
func enter_house():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var save_pos = spawn_point.global_position
		save_pos.y += 0.0  # Spawn above ground, let gravity settle like default spawn does
		WorldManager.update_player_data(save_pos, spawn_point.global_rotation, player.current_hunger)
		WorldManager.current_world_data["player_health"] = player.player_health
	
	await TransitionManager.fade_to_black(0.5).finished
	get_tree().change_scene_to_file("res://Scenes/Craftables/Building/house_basic_indoor.tscn")
