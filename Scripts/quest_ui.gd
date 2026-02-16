extends CanvasLayer

signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal task_progress(quest_id: String, task_id: String, current: int, required: int)

@export var menu_animation_duration: float = 0.3
@export var open_texture: Texture2D  # Open icon
@export var close_texture: Texture2D  # Close icon

@onready var panel: Panel = $QuestPanel
@onready var quest_title: Label = $QuestPanel/MarginContainer/VBoxContainer/QuestTitle
@onready var quest_desc: Label = $QuestPanel/MarginContainer/VBoxContainer/QuestDescription
@onready var task_list: VBoxContainer = $QuestPanel/MarginContainer/VBoxContainer/TaskList
@onready var open_button: TextureButton = $OpenButton
@onready var close_button: TextureButton = $QuestPanel/CloseButton

var audio_player: AudioStreamPlayer = null
var click_sound: AudioStream = load("res://Assets/SFX/click_3.mp3")
var task_scene = preload("res://UI/task_item.tscn")

var is_menu_open: bool = false

func _ready():
	audio_player = $AudioStreamPlayer
	audio_player.bus = "SFX"
	audio_player.stream = click_sound
	
	open_button.pressed.connect(_toggle_menu)
	close_button.pressed.connect(_toggle_menu)
	
	QuestManager.quest_started.connect(_on_quest_started)
	QuestManager.task_progress.connect(_on_task_progress)
	QuestManager.quest_completed.connect(_on_quest_completed)
	
	panel.visible = false
	update_ui()

func _on_quest_started(quest_id: String):
	update_ui()

func _on_task_progress(quest_id: String, task_id: String, current: int, required: int):
	update_ui()

func _on_quest_completed(quest_id: String):
	update_ui()

func update_ui():
	var quest = QuestManager.get_active_quest()
	if quest.is_empty():
		return
	
	quest_title.text = quest["title"]
	quest_desc.text = quest["description"]
	
	# Clear old tasks
	for child in task_list.get_children():
		child.queue_free()
	
	# Add tasks
	var progress = QuestManager.get_progress()
	for task in quest["tasks"]:
		var task_item = task_scene.instantiate()
		task_list.add_child(task_item)
		var current = progress.get(task["id"], 0)
		task_item.setup(task, current)

func _toggle_menu():
	is_menu_open = !is_menu_open

	audio_player.pitch_scale = randf_range(0.9, 1.1)
	audio_player.play()

	var tween = create_tween()
	if is_menu_open:
		panel.visible = true
		open_button.visible = false
		tween.tween_property(panel, "position:x", 1250, menu_animation_duration).from(2000.0)
	else:
		tween.tween_property(panel, "position:x", 2000.0, menu_animation_duration)
		tween.tween_callback(func(): panel.visible = false)
		tween.tween_callback(func(): open_button.visible = true)

#func _input(event):
	#if event.is_action_pressed("open_quest_menu"):  # Add this action in Input Map
		#_toggle_menu()
