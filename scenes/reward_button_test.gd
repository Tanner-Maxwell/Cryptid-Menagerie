extends Button

func _ready():
	# Connect the pressed signal
	connect("pressed", Callable(self, "_on_button_pressed"))
	text = "TEST: Go to Reward Scene"

func _on_button_pressed():
	print("===== TEST BUTTON PRESSED =====")
	print("Attempting direct scene transition to reward scene")
	
	# Try multiple potential paths for the reward scene
	var potential_paths = [
		"res://reward_scene.tscn",
		"res://Cryptid-Menagerie/scenes/reward_scene.tscn",
		"res://Cryptid-Menagerie/reward_scene.tscn",
		"res://scenes/reward_scene.tscn"
	]
	
	var scene_exists = false
	var valid_path = ""
	
	# Check if any of the paths exist
	for path in potential_paths:
		if FileAccess.file_exists(path):
			scene_exists = true
			valid_path = path
			print("Found valid scene at: " + path)
			break
	
	if scene_exists:
		print("Transitioning to reward scene at: " + valid_path)
		# Attempt the transition
		var result = get_tree().change_scene_to_file(valid_path)
		print("Scene change result: " + str(result))
	else:
		print("ERROR: Could not find reward scene at any of the expected paths!")
		print("Create a basic reward scene at one of these locations:")
		for path in potential_paths:
			print("- " + path)
