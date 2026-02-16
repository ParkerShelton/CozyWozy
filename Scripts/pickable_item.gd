extends Node3D
var item_name : String = ""
var quantity : int = 1
var icon : Texture2D = null
var can_pickup : bool = false
var is_magnetizing : bool = false
var player : Node3D = null
var player_has_left : bool = false
var require_player_exit : bool = false
@export var magnetize_speed : float = 10.0
@export var magnetize_distance : float = 5.0
@export var pickup_delay : float = 1.0
var audio_player: AudioStreamPlayer = null
var pickup_sounds: Array[AudioStream] = []

func _ready():
	add_to_group("pickable")
	setup_audio()
	# Create Area3D for magnetizing
	var area = Area3D.new()
	add_child(area)
	
	area.collision_layer = 0
	area.collision_mask = 8
	
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = magnetize_distance
	collision.shape = sphere
	area.add_child(collision)
	
	# Connect signals
	await get_tree().process_frame
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	
	# Check if player is already in range when spawned
	await get_tree().process_frame
	var overlapping_bodies = area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("player"):
			player = body
			if not require_player_exit:
				is_magnetizing = true
	
	# Delay pickup
	await get_tree().create_timer(pickup_delay).timeout
	can_pickup = true

func setup_audio():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.volume_db = -10.0
	
	# Load all 6 pop sounds
	for i in range(1, 7):  # pop_1.mp3 through pop_6.mp3
		var sound = load("res://Assets/SFX/pop_" + str(i) + ".mp3")
		if sound:
			pickup_sounds.append(sound)
		else:
			push_error("✗ Failed to load pop_" + str(i) + ".mp3")

func _process(delta):
	var can_magnetize = is_magnetizing and player and can_pickup
	if require_player_exit:
		can_magnetize = can_magnetize and player_has_left
	
	if can_magnetize:
		var direction = (player.global_position - global_position).normalized()
		global_position += direction * magnetize_speed * delta
		
		if global_position.distance_to(player.global_position) < 0.5:
			pickup()

func setup(i_n: String, q: int, ico: Texture2D, from_drop: bool = false):
	self.item_name = i_n
	self.quantity = q
	self.icon = ico
	self.require_player_exit = from_drop
	
	if has_node("Sprite3D"):
		var sprite = $Sprite3D
		sprite.texture = ico
		sprite.pixel_size = 0.02
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		
		var material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.no_depth_test = true
		material.albedo_texture = ico
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		
		sprite.material_override = material

func _on_body_entered(body: Node3D):
	var can_start_magnetizing = body.is_in_group("player") and can_pickup
	if require_player_exit:
		can_start_magnetizing = can_start_magnetizing and player_has_left
	
	if can_start_magnetizing:
		player = body
		is_magnetizing = true

func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_has_left = true
		is_magnetizing = false
		player = null

func pickup():
	if can_pickup:
		if Inventory.add_item(item_name, icon, quantity):
			# Pick a random sound from the array
			if pickup_sounds.size() > 0:
				audio_player.stream = pickup_sounds[randi() % pickup_sounds.size()]
				audio_player.volume_db = -15.0
				audio_player.pitch_scale = randf_range(0.95, 1.05)
				audio_player.play()
			
			if item_name == "log":
				QuestManager.update_task_progress("gather_wood", 1)
			
			if item_name == "apple":
				QuestManager.update_task_progress("gather_apples", 1)
				
			# Hide the sprite immediately
			if has_node("Sprite3D"):
				$Sprite3D.visible = false
			
			# Detach audio player and let it auto-free when done
			remove_child(audio_player)
			get_tree().root.add_child(audio_player)
			audio_player.finished.connect(audio_player.queue_free)
			
			# Free the pickup item immediately
			queue_free()
			return true
	return false
