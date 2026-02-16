class_name PlayerCombat

var player: Node3D

# ATTACK COOLDOWN
var can_attack: bool = true
var attack_cooldown: float = 0.4  # Seconds between attacks

var enemy_knockback_force = 18.0  # Force applied to enemies
var player_recoil_force = 10.0    # Force applied back to player

# THROWING
var thrown_rock_scene = preload("res://Scenes/Ranged/Ammo/thrown_rock.tscn")
var can_throw: bool = true
var throw_cooldown: float = 0.5
var base_throw_speed: float = 20.0
var slingshot_throw_speed: float = 35.0
var throw_arc: float = 0.1  # How much upward angle to add

func _init(_player: Node3D):
	player = _player

func click():
	if not can_attack:
		return
	
	var selected_item = Hotbar.get_selected_item()
	var item_name = selected_item["item_name"]
	
	var item_type = ItemManager.get_item_type(item_name)
	if item_type == "weapon":
		swing_sword(item_name)
		return
	
	# Raycast from player in the direction they're facing
	var from = player.global_position + Vector3(0, 1.0, 0)
	var forward = player.transform.basis.x
	var to = from + forward * player.attack_range
	
	var space_state = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0xFFFFFFFF
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_object = result.collider
		var target = hit_object
		
		# FIRST PASS: Try to find a node with take_damage() method
		var current = hit_object
		var found_method = false
		while current:
			if current.has_method("take_damage"):
				target = current
				found_method = true
				break
			current = current.get_parent()
		
		# SECOND PASS: If no take_damage found, look for groups
		if not found_method:
			current = hit_object
			while current:
				if current.is_in_group("trees") or current.is_in_group("rocks") or current.is_in_group("enemies"):
					target = current
					break
				current = current.get_parent()
		
		# Calculate damage based on item and target
		var damage = calculate_damage(item_name, target)

		# If damage is 0, don't allow the action
		if damage == 0.0 and (target.is_in_group("enemies") or target.is_in_group("trees") or target.is_in_group("rocks")):
			return
		
		# Start cooldown AFTER validation
		can_attack = false
		player.get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)
		
		# Play animation
		if player.anim_controller.has_method("play_attack"):
			player.anim_controller.play_attack(item_name)
		
		# Check if we hit an enemy
		if target.is_in_group("enemies"):
			# Play sound for enemies
			SoundManager.play_attack_sound(item_name, player.attack_audio_player)
			if target.has_method("take_damage"):
				target.take_damage(damage)
			return
		
		# Check if holding a seed and clicked on tilled ground
		var plant = PlantManager.get_plant(item_name)
		if plant and target.is_in_group("tilled_ground"):
			var success = target.plant_seed(plant)
			
			if success:
				var selected_slot = Hotbar.selected_slot
				var slot_data = Hotbar.get_slot(selected_slot)
				var new_quantity = slot_data["quantity"] - 1
				
				if new_quantity <= 0:
					Hotbar.clear_slot(selected_slot)
				else:
					Hotbar.set_slot(selected_slot, item_name, new_quantity, slot_data["icon"])
			return
		
		# Check if clicked on a harvestable crop
		if target.is_in_group("planted_crops"):
			var crop = target
			if crop.is_ready:
				var yields = crop.harvest()
				
				if yields.has("crop"):
					Inventory.add_item(yields.crop.item, yields.crop.icon, yields.crop.amount)
				
				if yields.has("seeds") and yields.seeds.amount > 0:
					Inventory.add_item(yields.seeds.item, yields.seeds.icon, yields.seeds.amount)
			return
		
		# Attack trees, rocks, etc.
		if target.has_method("take_damage") or target.is_in_group("trees") or target.is_in_group("rocks"):
			# Play sound based on tool
			if target.is_in_group("trees") and item_type == "axe":
				SoundManager.play_tree_chop_sound(player.attack_audio_player)
			else:
				SoundManager.play_attack_sound(item_name, player.attack_audio_player)
			
			# Deal damage
			if target.has_method("take_damage"):
				target.take_damage(damage)
			return

func swing_sword(item_name: String):
	can_attack = false
	player.get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)
	
	SoundManager.play_sword_sound(player.attack_audio_player)
	
	if player.anim_controller.has_method("play_attack"):
		player.anim_controller.play_attack(item_name)
	
	var damage = ItemManager.get_item_damage(item_name)
	
	var hit_any_enemy = false
	
	var enemies_in_range = player.attack_hit_box.get_overlapping_bodies()
	
	for body in enemies_in_range:
		var target = body
		while target and target.get_groups().size() == 0 and target.get_parent():
			target = target.get_parent()
		
		if target.is_in_group("enemies"):
			if target.has_method("take_damage"):
				target.take_damage(damage)
				
				var knockback_direction = (target.global_position - player.global_position).normalized()
				knockback_direction.y = 0
				
				if target.has_method("apply_knockback"):
					target.apply_knockback(knockback_direction * enemy_knockback_force)
				
				player.velocity -= knockback_direction * player_recoil_force
				
				hit_any_enemy = true

func calculate_damage(item_name: String, target: Node) -> float:
	var base_fist_damage = 2.0
	
	if item_name == "":
		return base_fist_damage
	
	var item_damage = ItemManager.get_item_damage(item_name)
	var item_type = ItemManager.get_item_type(item_name)
	
	if item_damage == 0.0:
		return 0.0
	
	if item_type == "axe":
		if target.is_in_group("trees") or target.is_in_group("fences"):
			return item_damage
		else:
			return 0.0
	
	elif item_type == "pickaxe":
		if target.is_in_group("rocks"):
			return item_damage
		else:
			return 0.0
	
	elif item_type == "weapon":
		if target.is_in_group("enemies"):
			return item_damage
		else:
			return 0.0
	
	elif item_type == "hoe":
		return 0.0
		
	else:
			return 0.0

func try_block():
	if not player.equipped_shield:
		return
	
	if not player.is_blocking:
		player.is_blocking = true
		if player.anim_controller.has_method("play_shield_block"):
			player.anim_controller.play("shield_block")

func stop_blocking():
	if player.is_blocking:
		player.is_blocking = false
		if player.anim_controller.has_method("stop_shield_block"):
			player.anim_controller.stop_shield_block()

func _on_shield_equipped(shield_name: String):
	if player.equipped_shield:
		player.equipped_shield.queue_free()
		player.equipped_shield = null
	
	if ItemManager.has_model(shield_name):
		var shield_scene = ItemManager.get_model(shield_name)
		if shield_scene:
			player.equipped_shield = shield_scene.instantiate()
			player.left_hand.add_child(player.equipped_shield)
			player.equipped_shield.position = Vector3(0, 0, 0)
			player.equipped_shield.rotation_degrees = Vector3(0, 0, 90)
			player.equipped_shield.scale = Vector3(0.5, 0.5, 0.5)

func _on_shield_unequipped():
	if player.equipped_shield:
		player.equipped_shield.queue_free()
		player.equipped_shield = null

func try_throw_rock():
	if not can_throw:
		return
	
	var selected_item = Hotbar.get_selected_item()
	var item_name = selected_item["item_name"]
	
	if item_name != "pebble":
		return
	
	# TODO: Check inventory for slingshot
	var has_slingshot = false  
	
	throw_rock(has_slingshot)
	
	var selected_slot = Hotbar.selected_slot
	var slot_data = Hotbar.get_slot(selected_slot)
	var new_quantity = slot_data["quantity"] - 1
	
	if new_quantity <= 0:
		Hotbar.clear_slot(selected_slot)
	else:
		Hotbar.set_slot(selected_slot, item_name, new_quantity, slot_data["icon"])

func throw_rock(use_slingshot: bool = false):
	can_throw = false
	
	var mouse_world_pos = player.movement.get_mouse_world_position()
	var throw_direction = (mouse_world_pos - player.global_position).normalized()
	
	throw_direction.y = throw_arc
	throw_direction = throw_direction.normalized()
	
	var rock = thrown_rock_scene.instantiate()
	player.get_tree().root.add_child(rock)
	
	rock.global_position = player.global_position + Vector3(0, 1.2, 0) + (player.transform.basis.x * 0.5)
	
	var throw_speed = slingshot_throw_speed if use_slingshot else base_throw_speed
	rock.linear_velocity = throw_direction * throw_speed
	rock.thrown_by_slingshot = use_slingshot
	
	await player.get_tree().create_timer(throw_cooldown).timeout
	can_throw = true
