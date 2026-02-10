# remote_player.gd
extends CharacterBody3D

var steam_id: int = 0
var player_name: String = ""

@onready var character_model = $character_modeled  # Or whatever you named it
@onready var animation_player = $character_modeled/AnimationPlayer
@onready var name_label = $Label3D

func _ready():
	# Set player name
	if steam_id != 0:
		name_label.text = Steam.getFriendPersonaName(steam_id)
	
	# Start idle animation
	if animation_player:
		animation_player.play("idle")

func _physics_process(_delta):
	# Simple animation based on movement
	if animation_player:
		if velocity.length() > 0.1:
			if animation_player.current_animation != "run":
				animation_player.play("run")
		else:
			if animation_player.current_animation != "idle":
				animation_player.play("idle")
	
	move_and_slide()
