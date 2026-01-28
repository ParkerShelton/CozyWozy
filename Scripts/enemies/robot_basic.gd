extends BaseEnemy

func _ready():
	super._ready()
	
	max_health = 50.0
	current_health = 50.0
	move_speed = 2.0
	attack_damage = 5.0
	attack_range = 1.5
	detection_range = 10.0
	exp_reward = 5
	
	# Set drops
	drop_items = [
		{"item_name": "iron", "drop_chance": 0.8, "min_amount": 1, "max_amount": 3}
	]

func perform_attack():
	super.perform_attack()  # Call base attack
	# Add enemy-specific attack effects
