# QuestManager.gd (Logic only - Add as Autoload: Project Settings > Autoload)
# Handles quests, progress, signals - NO UI!

extends Node

signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal task_progress(quest_id: String, task_id: String, current: int, required: int)

@export var quests_json_path: String = "res://data/quests.json"

var quests_data: Dictionary = {}
var active_quest_id: String = ""
var quest_progress: Dictionary = {}  # {quest_id: {task_id: current_count}}

func _ready():
	load_quests()
	start_quest("quest_1")  # Example auto-start

func load_quests():
	if ResourceLoader.exists(quests_json_path):
		var file = FileAccess.open(quests_json_path, FileAccess.READ)
		var json_text = file.get_as_text()
		var parsed = JSON.parse_string(json_text)
		if parsed:
			quests_data = parsed["quests"]
			print("Loaded %d quests" % quests_data.size())
		else:
			push_error("Invalid JSON in quests.json")
	else:
		push_warning("Quests JSON not found at %s" % quests_json_path)

# Start a quest (call from game events)
func start_quest(quest_id: String):
	if not quests_data.has(quest_id):
		push_error("Quest %s not found!" % quest_id)
		return
	
	active_quest_id = quest_id
	quest_progress[quest_id] = {}  # Reset progress
	
	quest_started.emit(quest_id)
	print("Started quest: %s" % quest_id)

# Update task progress (call from inventory/player signals)
func update_task_progress(task_id: String, increment: int = 1):
	if active_quest_id == "" or not quest_progress.has(active_quest_id):
		return
	
	var qp = quest_progress[active_quest_id]
	qp[task_id] = qp.get(task_id, 0) + increment
	
	task_progress.emit(active_quest_id, task_id, qp[task_id], 0)
	
	# Check if quest complete
	var quest = quests_data[active_quest_id]
	var all_complete = true
	for task in quest["tasks"]:
		var tid = task["id"]
		var current = qp.get(tid, 0)
		if current < task["required"]:
			all_complete = false
			break
	
	if all_complete:
		quest_completed.emit(active_quest_id)
		print("Quest completed: %s" % active_quest_id)

# Get current quest data (for UI)
func get_active_quest() -> Dictionary:
	if active_quest_id == "":
		return {}
	return quests_data[active_quest_id]

# Get progress for active quest
func get_progress() -> Dictionary:
	return quest_progress.get(active_quest_id, {})

# Example calls from other scripts:
# QuestManager.update_task_progress("gather_wood", 1)
# QuestManager.start_quest("quest_2")
