class_name PlayerAudio

var player: Node3D

var footstep_audio: AudioStreamPlayer = null
var footstep_sounds: Array = []
var sprint_sounds: Array = []

var zip_open_sound: AudioStream
var zip_closed_sound: AudioStream
var ui_audio: AudioStreamPlayer 

var sword_hit_sounds: Array = []
var dash_roll_sound: AudioStream = null

func _init(_player: Node3D):
	player = _player

func setup_audio():
	footstep_audio = AudioStreamPlayer.new()
	player.add_child(footstep_audio)
	footstep_audio.volume_db = -20.0
	
	ui_audio = AudioStreamPlayer.new()
	player.add_child(ui_audio)
	ui_audio.volume_db = -10.0
		
	for i in range(1, 6):
		var sound = load("res://Assets/SFX/sword_hit_" + str(i) + ".mp3")
		sword_hit_sounds.append(sound)

	for i in range(1, 9):
		var sound = load("res://Assets/SFX/run_" + str(i) + ".mp3")
		footstep_sounds.append(sound)
	
	for i in range(1, 5):
		var sound = load("res://Assets/SFX/sprint_" + str(i) + ".mp3")
		sprint_sounds.append(sound)

	dash_roll_sound = load("res://Assets/SFX/dash_roll.mp3")
	zip_open_sound = load("res://Assets/SFX/zip_open.mp3")
	zip_closed_sound = load("res://Assets/SFX/zip_closed.mp3")

func play_footstep_sound():
	if Input.is_action_pressed("sprint"):
		if sprint_sounds.is_empty():
			return
		
		var rand = randf()
		var random_sound
		
		if rand < 0.15:
			var index = randi() % 2
			random_sound = sprint_sounds[index]
		else:
			var index = 2 + (randi() % 2)
			random_sound = sprint_sounds[index]
		
		footstep_audio.stream = random_sound
		footstep_audio.pitch_scale = randf_range(0.9, 1.1)
		footstep_audio.volume_db = -20.0
		footstep_audio.play()
	else:
		if footstep_sounds.is_empty():
			return
		
		var random_sound = footstep_sounds[randi() % footstep_sounds.size()]
		footstep_audio.stream = random_sound
		footstep_audio.pitch_scale = randf_range(0.9, 1.1)
		footstep_audio.volume_db = -15.0
		footstep_audio.play()
