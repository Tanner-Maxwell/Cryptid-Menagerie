extends Node2D

var next_node_id = ""

func _ready():
	print("Reward scene loaded!")
	
	# Get the continue button by its path
	var continue_button = $VBoxContainer/ContinueButton
	if continue_button:
		# Connect the pressed signal
		continue_button.connect("pressed", Callable(self, "_on_continue_button_pressed"))
		print("Continue button connected")
	else:
		print("WARNING: Could not find continue button at path $VBoxContainer/ContinueButton")
		# Try to find it by class instead
		for child in get_children():
			if child is Button:
				child.connect("pressed", Callable(self, "_on_continue_button_pressed"))
				print("Found and connected a Button node instead")
				break

func _on_continue_button_pressed():
	print("Continue button pressed - returning to overworld")
	
	# Get the next node ID to go to
	var next_node_id = ""
	if GameState.current_encounter and GameState.current_encounter.has("next_node_id"):
		next_node_id = GameState.current_encounter.next_node_id
		print("Will position at next node: " + next_node_id)
		
		# Store it in GameState
		GameState.set_current_node_id(next_node_id)
	
	# Create instance of the overworld scene
	var overworld_scene_path = "res://Cryptid-Menagerie/scenes/overworld_map.tscn" 
	print("Loading overworld scene from: " + overworld_scene_path)
	
	var overworld_scene_resource = load(overworld_scene_path)
	if overworld_scene_resource == null:
		print("ERROR: Failed to load overworld scene resource")
		return
		
	var overworld_scene = overworld_scene_resource.instantiate()
	if overworld_scene == null:
		print("ERROR: Failed to instantiate overworld scene")
		return
	
	print("Overworld scene instantiated successfully")
	
	# Replace the current scene with the overworld scene
	get_tree().root.add_child(overworld_scene)
	get_tree().current_scene = overworld_scene
	
	# Remove this scene
	get_tree().root.remove_child(self)
	queue_free()  # Free this scene since we're done with it
	
	print("Returned to overworld map")


# 2. Update your encounter node selection logic in overworld_map.gd

func _on_encounter_node_clicked(node):
	# Skip if node is not accessible
	if not node.is_accessible:
		print(node.name + " clicked - not accessible")
		return
	
	# Skip if this is the current node
	if node.is_current:
		print(node.name + " clicked - already current")
		return
	
	print(node.name + " clicked!")
	
	# Get node data
	var encounter_type = ""
	var node_id = ""
	
	if "encounter_data" in node:
		# If node has encounter_data object
		if "encounter_type" in node.encounter_data:
			encounter_type = node.encounter_data.encounter_type
		if "node_id" in node.encounter_data:
			node_id = node.encounter_data.node_id
	elif "encounter_type" in node:
		# Direct properties
		encounter_type = node.encounter_type
		node_id = node.node_id
	
	print("Node data - ID: " + node_id + ", Type: " + encounter_type)
	
	# Handle different encounter types
	match encounter_type:
		"wild", "trainer":
			print("Transitioning to battle scene")
			# Battle code...
			
		"reward":
			print("REWARD NODE! Transitioning to reward scene")
			
			# For reward nodes
			var reward_data = {
				"node_id": node_id,
				"encounter_type": "reward"
			}
			
			# Find next node ID (connected node that isn't the previous battle)
			var next_node_id = ""
			if "connected_nodes" in node:
				for connected_id in node.connected_nodes:
					var connected_node = find_encounter_node_by_id(connected_id)
					if connected_node and "encounter_type" in connected_node and connected_node.encounter_type != "reward":
						next_node_id = connected_id
						print("Found next node after reward: " + next_node_id)
						break
						
			# Add the next node ID to reward data if found
			if next_node_id != "":
				reward_data["next_node_id"] = next_node_id
			
			# Store in GameState and transition to reward scene
			GameState.set_current_encounter(reward_data)
			print("Set reward data in GameState: " + str(reward_data))
			
			# IMPORTANT: First verify the reward scene exists
			var reward_scene_path = "res://Cryptid-Menagerie/scenes/reward_scene.tscn"
			var dir = DirAccess.open("res://Cryptid-Menagerie/scenes/")
			if dir:
				print("Checking available scenes:")
				dir.list_dir_begin()
				var file_name = dir.get_next()
				while file_name != "":
					if file_name.ends_with(".tscn"):
						print("- " + file_name)
					file_name = dir.get_next()
			else:
				print("Could not access scenes directory")
			
			# Try an alternative path if needed
			if !FileAccess.file_exists(reward_scene_path):
				print("WARNING: Reward scene not found at: " + reward_scene_path)
				# Try some alternative paths
				var alternatives = [
					"res://reward_scene.tscn",
					"res://scenes/reward_scene.tscn",
					"res://Cryptid-Menagerie/reward_scene.tscn"
				]
				
				for alt_path in alternatives:
					if FileAccess.file_exists(alt_path):
						reward_scene_path = alt_path
						print("Found alternative path: " + reward_scene_path)
						break
			else:
				print("Reward scene file exists at: " + reward_scene_path)
			
			# Attempt the transition
			print("Changing to reward scene at: " + reward_scene_path)
			get_tree().change_scene_to_file(reward_scene_path)
			
		"rest":
			# Handle rest nodes...
			print("Rest node clicked")
			
		_:
			# Default for unknown node types
			print("Unknown node type: " + encounter_type)
			

# 3. Update the battle_scene.gd end_battle function to handle rewards

func end_battle(was_victorious = true):
	print("Battle ended with " + ("victory" if was_victorious else "defeat"))
	
	# Store battle result in GameState
	GameState.last_battle_result = was_victorious
	
	# Determine what scene to go to next
	var next_scene = "res://Cryptid-Menagerie/scenes/overworld_map.tscn"
	
	# If victorious and there's a next_node_id that's a reward, go to reward scene
	if was_victorious && GameState.current_encounter:
		# First update current node to the battle node regardless
		if GameState.current_encounter.has("node_id"):
			GameState.set_current_node_id(GameState.current_encounter.node_id)
			print("Updated current node to: " + GameState.current_encounter.node_id)
			
		# If there's a next_node_id and it's likely a reward, go there
		if GameState.current_encounter.has("next_node_id"):
			var next_node_id = GameState.current_encounter.next_node_id
			var next_node = find_encounter_node_by_id(next_node_id)
			
			if next_node and "encounter_type" in next_node and next_node.encounter_type == "reward":
				print("Battle victory - proceeding to reward node: " + next_node_id)
				# Create reward data
				var reward_data = {
					"node_id": next_node_id,
					"encounter_type": "reward",
					"next_node_id": next_node_id  # Store it for the reward scene
				}
				GameState.set_current_encounter(reward_data)
				next_scene = "res://Cryptid-Menagerie/scenes/reward_scene.tscn"
	
	# Use a safer method to get the scene tree
	var scene_tree = Engine.get_main_loop()
	if scene_tree:
		print("Found scene tree, changing scene to: " + next_scene)
		# Add a small delay to make sure everything is cleaned up
		await scene_tree.create_timer(0.5).timeout
		scene_tree.change_scene_to_file(next_scene)
	else:
		print("ERROR: Could not get scene tree")
		# Try the regular method as fallback
		if get_tree():
			get_tree().change_scene_to_file(next_scene)
		else:
			print("Critical error: Both scene_tree and get_tree() are null")


# 4. Add a find_encounter_node_by_id function to battle_scene.gd as well (similar to your overworld map version)

func find_encounter_node_by_id(node_id: String):
	# This function will only work when called from the overworld scene
	# It gets all encounter nodes in the current scene
	var encounter_nodes = []
	
	# Try to get all encounter nodes directly
	var tree = Engine.get_main_loop()
	if tree:
		var scene_root = tree.get_current_scene()
		if scene_root:
			# Look for encounter_nodes group
			encounter_nodes = scene_root.get_tree().get_nodes_in_group("encounter_nodes")
			print("Found " + str(encounter_nodes.size()) + " encounter nodes in current scene")
	
	# Look for the node with matching ID
	for node in encounter_nodes:
		# Check direct property match
		if "node_id" in node and node.node_id == node_id:
			return node
			
		# Check metadata match
		elif node.has_meta("node_id") and node.get_meta("node_id") == node_id:
			return node
	
	# If not found, return null
	print("Node ID not found in current scene: " + node_id)
	return null

func _on_continue_pressed():
	print("Continue pressed, returning to overworld")
	
	# Return to overworld
	get_tree().change_scene_to_file("res://Cryptid-Menagerie/scenes/overworld_map.tscn")
