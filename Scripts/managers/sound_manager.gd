# sound_manager.gd (Autoload)
extends Node

# Sound pools
var fist_sounds: Array = []
var sword_sounds: Array = []
var tree_chop_sounds: Array = []

# Tree chop weights (tree_chop.mp3 = 95%, tree_chop_1.mp3 = 5%)
var tree_chop_weights: Array = [0.95, 0.05]

func _ready():
	load_sounds()

func load_sounds():
	# Load fist sounds (6 files)
	for i in range(6):
		var path = "res://Assets/SFX/fist_hit_%d.mp3" % i if i > 0 else "res://Assets/SFX/fist_hit.mp3"
		if ResourceLoader.exists(path):
			fist_sounds.append(load(path))
	
	# Load sword sounds (5 files)
	for i in range(5):
		var path = "res://Assets/SFX/sword_hit_%d.mp3" % i if i > 0 else "res://Assets/SFX/sword_hit.mp3"
		if ResourceLoader.exists(path):
			sword_sounds.append(load(path))
	
	# Load tree chop sounds (2 files with weights)
	var tree_paths = [
		"res://Assets/SFX/tree_chop.mp3",
		"res://Assets/SFX/tree_chop_1.mp3"
	]
	for path in tree_paths:
		if ResourceLoader.exists(path):
			tree_chop_sounds.append(load(path))

# Play random fist sound
func play_fist_sound(audio_player: AudioStreamPlayer):
	if fist_sounds.is_empty():
		return
	
	var sound = fist_sounds[randi() % fist_sounds.size()]
	audio_player.stream = sound
	audio_player.pitch_scale = randf_range(0.9, 1.1)
	audio_player.play()

# Play random sword sound
func play_sword_sound(audio_player: AudioStreamPlayer):
	if sword_sounds.is_empty():
		return
	
	var sound = sword_sounds[randi() % sword_sounds.size()]
	audio_player.stream = sound
	audio_player.pitch_scale = randf_range(0.9, 1.1)
	audio_player.play()

# Play weighted tree chop sound (95% normal, 5% rare)
func play_tree_chop_sound(audio_player: AudioStreamPlayer):
	if tree_chop_sounds.is_empty():
		return
	
	var sound = choose_weighted_sound(tree_chop_sounds, tree_chop_weights)
	audio_player.stream = sound
	audio_player.pitch_scale = randf_range(0.9, 1.1)
	audio_player.play()

# Helper: Choose sound based on weights
func choose_weighted_sound(sounds: Array, weights: Array) -> AudioStream:
	var total_weight = 0.0
	for weight in weights:
		total_weight += weight
	
	var rand = randf() * total_weight
	var cumulative = 0.0
	
	for i in range(sounds.size()):
		cumulative += weights[i]
		if rand <= cumulative:
			return sounds[i]
	
	return sounds[0]  # Fallback

# Generic play attack sound based on item type
func play_attack_sound(item_name: String, audio_player: AudioStreamPlayer):
	if item_name == "":
		# Empty hand = fist
		play_fist_sound(audio_player)
		return
	
	var item_type = ItemManager.get_item_type(item_name)
	
	match item_type:
		"weapon":
			play_sword_sound(audio_player)
		"axe":
			play_tree_chop_sound(audio_player)
		"pickaxe":
			# Could add pickaxe sounds here
			play_fist_sound(audio_player)
		"hoe":
			# Could add hoe sounds here
			play_fist_sound(audio_player)
		_:
			play_fist_sound(audio_player)
