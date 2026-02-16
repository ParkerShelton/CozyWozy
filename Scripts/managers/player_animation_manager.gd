# player_animation_manager.gd
extends Node3D

@onready var animation_player = $"../vesper/AnimationPlayer"
@onready var player = get_parent()

enum AnimState {
	IDLE,
	RUN,
	DASH,
	ATTACK,
	PLACE,
	BLOCK,
	DEATH,
	FLOATING,
	LANDING,
	EQUIP
}

var current_state = AnimState.IDLE
var current_run_anim = ""

var current_fist_attack = -1
var fist_attack_count = 3

var current_sword_attack = 0
var sword_attack_count = 2

var is_attacking = false
var queued_attacks = 0

var combo_window_time = 0.5
var last_attack_time = 0.0
var in_combo = false

var is_equipping = false

var holding_gun: bool = false
var is_shooting: bool = false

func _physics_process(_delta):
	update_animation()
	if in_combo and Time.get_ticks_msec() / 1000.0 - last_attack_time > combo_window_time:
		reset_combo()

func set_holding_gun(value: bool):
	if holding_gun == value:
		return
	holding_gun = value
	animation_player.speed_scale = 1.0
	if holding_gun:
		animation_player.play("shoot_idle")
	else:
		current_state = AnimState.IDLE
		current_run_anim = ""
		animation_player.play("idle")


func play_shoot():
	if is_shooting:
		return
	is_shooting = true
	current_state = AnimState.ATTACK
	animation_player.speed_scale = 2.5
	animation_player.stop()
	animation_player.play("shoot")
	
	var anim_length = animation_player.get_animation("shoot").length
	await get_tree().create_timer(anim_length / animation_player.speed_scale).timeout
	
	is_shooting = false
	animation_player.speed_scale = 1.0
	if holding_gun:
		current_state = AnimState.IDLE
		animation_player.play("shoot_idle")


func update_animation():
	if is_attacking or is_equipping or is_shooting:
		return
	
	if current_state == AnimState.FLOATING or current_state == AnimState.LANDING:
		return
	
	if holding_gun:
		var new_state = AnimState.IDLE
		if player.is_dashing:
			new_state = AnimState.DASH
		elif player.velocity.length() > 0.1:
			new_state = AnimState.RUN
		else:
			new_state = AnimState.IDLE
		
		if new_state == AnimState.IDLE and current_state != AnimState.IDLE:
			current_state = AnimState.IDLE
			animation_player.play("shoot_idle")
		elif new_state == AnimState.RUN:
			if current_state != AnimState.RUN:
				current_state = AnimState.RUN
				animation_player.play("shoot_idle")
		elif new_state == AnimState.DASH:
			if current_state != AnimState.DASH:
				current_state = AnimState.DASH
				animation_player.speed_scale = 2.5
				animation_player.play("dash_roll")
		return
	
	var new_state = AnimState.IDLE
	
	if "is_blocking" in player and player.is_blocking:
		new_state = AnimState.BLOCK
	elif player.is_dashing:
		new_state = AnimState.DASH
	elif player.is_placing:
		new_state = AnimState.PLACE
	elif player.velocity.length() > 0.1:
		new_state = AnimState.RUN
	else:
		new_state = AnimState.IDLE
	
	if new_state != current_state:
		if current_state == AnimState.DASH:
			animation_player.speed_scale = 1.0
		current_state = new_state
		if new_state == AnimState.RUN:
			current_run_anim = ""
		play_animation(new_state)
	
	if current_state == AnimState.RUN:
		var run_anim = get_run_animation()
		if run_anim != current_run_anim:
			current_run_anim = run_anim
			animation_player.play(run_anim)

func get_run_animation() -> String:
	var vel = player.velocity
	vel.y = 0.0
	
	if vel.length() < 0.1:
		return "run"
	
	var move_angle = atan2(-vel.z, vel.x)
	var face_angle = player.rotation.y
	
	var relative = move_angle - face_angle
	relative = deg_to_rad(wrapf(rad_to_deg(relative), -180.0, 180.0))
	
	var forward_threshold = 3.0 * PI / 8.0
	var backward_threshold = 5.0 * PI / 8.0

	if relative > -forward_threshold and relative <= forward_threshold:
		return "run"
	elif relative > forward_threshold and relative <= backward_threshold:
		return "run_right"
	elif relative > -backward_threshold and relative <= -forward_threshold:
		return "run_left"
	else:
		return "run_backward"



func play_sheath(item_name: String):
	if item_name == "wood_sword":
		is_equipping = true # Reusing this flag to lock the animation state
		current_state = AnimState.IDLE # Setting back to idle state
		
		animation_player.play("sheath_sword")
		
		# Wait for animation to finish before allowing other animations
		var anim = animation_player.get_animation("sheath_sword")
		await get_tree().create_timer(anim.length / animation_player.speed_scale).timeout
		
		is_equipping = false



# Add this function to the script
func play_equip(item_name: String):
	if item_name == "wood_sword":
		is_equipping = true
		current_state = AnimState.EQUIP
		
		animation_player.speed_scale = 1.5 # Optional: make it snappier
		animation_player.play("draw_sword") # Ensure this name matches your AnimPlayer
		
		# Wait for the animation to finish
		var anim_length = animation_player.get_animation("draw_sword").length
		await get_tree().create_timer(anim_length / animation_player.speed_scale).timeout
		
		is_equipping = false
		# The update_animation loop will naturally pick back up from here


func play_animation(state: AnimState):
	match state:
		AnimState.IDLE:
			animation_player.play("idle")
			current_run_anim = ""
		AnimState.RUN:
			current_run_anim = get_run_animation()
			animation_player.play(current_run_anim)
		AnimState.DASH:
			animation_player.speed_scale = 2.5
			animation_player.play("dash_roll")
		AnimState.PLACE:
			pass
		AnimState.BLOCK:
			animation_player.speed_scale = 2.0
			animation_player.play("shield_block")
		AnimState.ATTACK:
			animation_player.play("attack")
		AnimState.DEATH:
			animation_player.play("die")
		AnimState.FLOATING:
			animation_player.speed_scale = 1.0
			animation_player.play("floating")
		AnimState.LANDING:
			animation_player.speed_scale = 1.0
			animation_player.play("landing")

func play_attack(item_name: String):
	if is_attacking:
		queued_attacks += 1
		return

	_execute_attack(item_name)

func _execute_attack(item_name: String):
	is_attacking = true
	last_attack_time = Time.get_ticks_msec() / 1000.0

	var anim_name: String

	if item_name == "":
		in_combo = true

		if current_fist_attack == -1:
			current_fist_attack = randi() % fist_attack_count

		anim_name = "hit_fist_" + str(current_fist_attack + 1)

		if animation_player.is_playing() and animation_player.current_animation.begins_with("hit_fist_"):
			animation_player.speed_scale = 2.0
			animation_player.play(anim_name, 0.1)
		else:
			animation_player.speed_scale = 2.0
			animation_player.play(anim_name)

		current_fist_attack = (current_fist_attack + 1) % fist_attack_count
	else:
		in_combo = true
		anim_name = "hit_sword_" + str(current_sword_attack + 1)

		var pick_attack = randi_range(1,5)
		if pick_attack == 1:
			anim_name = "sword_slash_up"
		else:
			anim_name = "sword_slash_down"

		if animation_player.is_playing() and animation_player.current_animation.begins_with("hit_sword_"):
			animation_player.speed_scale = 2.0
			animation_player.play(anim_name, 0.1)
		else:
			animation_player.speed_scale = 2.0
			animation_player.play(anim_name)

		current_sword_attack = (current_sword_attack + 1) % sword_attack_count

	var anim_length: float = animation_player.get_animation(anim_name).length
	var wait_time: float = anim_length / animation_player.speed_scale
	await get_tree().create_timer(wait_time).timeout

	animation_player.speed_scale = 1.0
	is_attacking = false

	if queued_attacks > 0:
		queued_attacks -= 1
		_execute_attack(item_name)
	else:
		current_state = AnimState.ATTACK
		current_run_anim = ""

func reset_combo():
	in_combo = false
	current_fist_attack = -1
	current_sword_attack = 0

func play_death():
	current_state = AnimState.DEATH
	is_attacking = false
	queued_attacks = 0
	animation_player.play("die")

func start_floating():
	current_state = AnimState.FLOATING
	is_attacking = false
	queued_attacks = 0
	animation_player.speed_scale = 1.0
	animation_player.play("floating")

func stop_floating():
	# Player is released — still in the air, keep floating anim until landing
	current_state = AnimState.FLOATING

func play_landing():
	current_state = AnimState.LANDING
	is_attacking = false
	animation_player.speed_scale = 1.0
	animation_player.play("landing")
	
	var anim_length = animation_player.get_animation("landing").length
	await get_tree().create_timer(anim_length).timeout
	
	if current_state == AnimState.LANDING:
		current_state = AnimState.IDLE
		animation_player.play("idle")
