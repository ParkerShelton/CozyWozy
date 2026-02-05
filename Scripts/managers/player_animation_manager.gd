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
	DEATH
}

var current_state = AnimState.IDLE
# Tracks which run variant is currently playing so we only swap when it changes
var current_run_anim = ""

var current_fist_attack = -1  # -1 means no combo started, will pick random
var fist_attack_count = 3

var current_sword_attack = 0
var sword_attack_count = 2

var is_attacking = false
var queued_attacks = 0  # Count how many attacks are queued during current animation

var combo_window_time = 0.5
var last_attack_time = 0.0
var in_combo = false

func _physics_process(_delta):
	update_animation()
	
	if in_combo and Time.get_ticks_msec() / 1000.0 - last_attack_time > combo_window_time:
		reset_combo()

func update_animation():
	if is_attacking:
		return
	
	var new_state = AnimState.IDLE
	
	if player.is_dashing:
		new_state = AnimState.DASH
	elif player.is_placing:
		new_state = AnimState.PLACE
	elif player.velocity.length() > 0.1:
		new_state = AnimState.RUN
	else:
		new_state = AnimState.IDLE
	
	if new_state != current_state:
		# Reset speed scale when leaving dash
		if current_state == AnimState.DASH:
			animation_player.speed_scale = 1.0
		current_state = new_state
		# If we're transitioning INTO run, reset current_run_anim so
		# get_run_animation() picks the right variant on this frame.
		if new_state == AnimState.RUN:
			current_run_anim = ""
		play_animation(new_state)
	
	# While running, check every frame whether the directional variant needs
	# to change (player can strafe without the state itself changing).
	if current_state == AnimState.RUN:
		var run_anim = get_run_animation()
		if run_anim != current_run_anim:
			current_run_anim = run_anim
			animation_player.play(run_anim)

# --------------- Directional Run Logic ---------------
# Compares the player's velocity direction against their facing direction
# (rotation.y) to produce a relative angle, then buckets it into one of four
# quadrants using 45 degree boundaries.

func get_run_animation() -> String:
	var vel = player.velocity
	vel.y = 0.0
	
	if vel.length() < 0.1:
		return "run"
	
	# World-space angle of where the player is actually moving
	# Use same formula as player.gd: atan2(-z, x)
	var move_angle = atan2(-vel.z, vel.x)
	# World-space angle the player is facing
	var face_angle = player.rotation.y
	
	# Relative angle: positive = movement is to the right of facing,
	# negative = to the left.  Wrap into (-PI, PI].
	var relative = move_angle - face_angle
	relative = deg_to_rad(wrapf(rad_to_deg(relative), -180.0, 180.0))
	
	# Bucket thresholds (radians)
	# Use 67.5 degrees for forward so diagonal-forward (forward + left/right) uses regular run
	var forward_threshold = 3.0 * PI / 8.0  # 67.5 degrees
	var backward_threshold = 5.0 * PI / 8.0  # 112.5 degrees

	if relative > -forward_threshold and relative <= forward_threshold:
		return "run"
	elif relative > forward_threshold and relative <= backward_threshold:
		return "run_right"
	elif relative > -backward_threshold and relative <= -forward_threshold:
		return "run_left"
	else:
		return "run_backward"

# --------------- Animation Playback ---------------

func play_animation(state: AnimState):
	match state:
		AnimState.IDLE:
			animation_player.play("idle")
			current_run_anim = ""
		AnimState.RUN:
			# Initial run variant picked here; frame-by-frame updates
			# happen in the update_animation() RUN block above.
			current_run_anim = get_run_animation()
			animation_player.play(current_run_anim)
		AnimState.DASH:
			animation_player.speed_scale = 2.5
			animation_player.play("dash_roll")
		AnimState.PLACE:
			pass
		AnimState.ATTACK:
			animation_player.play("attack")
		AnimState.DEATH:
			animation_player.play("die")

# --------------- Attack ---------------

func play_attack(item_name: String):
	# If already attacking, queue the next attack for smooth combo
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

		# If no combo started (-1), pick a random attack
		# Otherwise continue the sequence
		if current_fist_attack == -1:
			current_fist_attack = randi() % fist_attack_count

		anim_name = "hit_fist_" + str(current_fist_attack + 1)

		if animation_player.is_playing() and animation_player.current_animation.begins_with("hit_fist_"):
			animation_player.speed_scale = 2.0
			animation_player.play(anim_name, 0.1)
		else:
			animation_player.speed_scale = 2.0
			animation_player.play(anim_name)

		# Move to next in sequence for combo
		current_fist_attack = (current_fist_attack + 1) % fist_attack_count
	else:
		in_combo = true
		anim_name = "hit_sword_" + str(current_sword_attack + 1)

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

	# If player queued more attacks, play the next one immediately
	if queued_attacks > 0:
		queued_attacks -= 1
		_execute_attack(item_name)
	else:
		# Force a state mismatch so the next frame re-applies idle or run.
		current_state = AnimState.ATTACK
		current_run_anim = ""

func reset_combo():
	in_combo = false
	current_fist_attack = -1  # Reset to -1 so next single click picks random
	current_sword_attack = 0

func play_death():
	current_state = AnimState.DEATH
	is_attacking = false
	queued_attacks = 0
	animation_player.play("die")
