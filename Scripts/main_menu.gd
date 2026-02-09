extends Control


var audio_player: AudioStreamPlayer = null
var click_sound: AudioStream = load("res://Assets/SFX/click_3.mp3")

var pause_time : float = 0.2

func _ready():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	audio_player.stream = click_sound

func _on_play_button_pressed():
	audio_player.pitch_scale = randf_range(0.9, 1.1)
	audio_player.play()
	await get_tree().create_timer(pause_time).timeout
	get_tree().change_scene_to_file("res://UI/main_menu/world_choice.tscn")

func _on_settings_button_pressed():
	audio_player.pitch_scale = randf_range(0.9, 1.1)
	audio_player.play()
	await get_tree().create_timer(pause_time).timeout
	pass

func _on_quit_button_pressed():
	audio_player.pitch_scale = randf_range(0.9, 1.1)
	audio_player.play()
	await get_tree().create_timer(pause_time).timeout
	get_tree().quit()


func _on_multiplayer_button_pressed():
	get_tree().change_scene_to_file("res://UI/Multiplayer/multipayer_menu.tscn")
