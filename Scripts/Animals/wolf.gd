extends BaseAnimal

@onready var animation_player = $wolf2/AnimationPlayer

var pack_speed_bonus: float = 0.2  # 20% faster near other wolves
var pack_detection_radius: float = 15.0

func _ready():
	await super._ready()
	
	max_health = 10.0
	current_health = 10.0
	move_speed = 5.0
	attack_damage = 5.0
	attack_range = 1.5
	detection_range = 20.0
	
	# Set drops
	drop_items = [
		{"item_name": "iron", "drop_chance": 0.8, "min_amount": 1, "max_amount": 3}
	]

func _process(delta):
	update_animation()

func update_animation():
	if not animation_player:
		return
	
	match current_state:
		State.WANDER, State.FLEE, State.CHASE:
			animation_player.speed_scale = 2
			move_speed = 8
			
			if current_state == State.CHASE:
				animation_player.speed_scale = 3
				move_speed = 12
				
			# Moving - play walk
			if not animation_player.is_playing() or animation_player.current_animation != "walk":
				animation_player.play("walk")
				
			if animation_player.animation_finished:
				animation_player.play("walk")
				
		State.IDLE:
			# Idle on ground - just stop moving animation
			if velocity.length() < 0.1:
				if animation_player.is_playing() and animation_player.current_animation == "walk":
					animation_player.stop()
					animation_player.play("idle")


func _apply_pack_bonus():
	var nearby_wolves = get_tree().get_nodes_in_group("animals")
	var wolf_count = 0
	for animal in nearby_wolves:
		if animal != self and animal.animal_key == "wolf":
			if global_position.distance_to(animal.global_position) < pack_detection_radius:
				wolf_count += 1
	# Temporarily boost move_speed if wolves are nearby
	move_speed = move_speed * (1.0 + pack_speed_bonus * wolf_count)
