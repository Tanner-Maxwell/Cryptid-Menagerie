extends Node2D
class_name OverworldMap

# Variables for tracking game state
var current_floor = 1
var player_progress = 0
var encounter_manager
var current_node_id: String = ""

# Node references
@onready var encounter_nodes = $EncounterNodes

# Called when the node enters the scene tree for the first time.
func _ready():
	# Initialize the encounter manager
	current_node_id = ""
	
	encounter_manager = WildEncounterManager.new()
	add_child(encounter_manager)
	
	# Set initial values
	encounter_manager.set_floor(current_floor)
	
	# Connect signals from encounter nodes
	for node in encounter_nodes.get_children():
		if node.has_signal("encounter_selected"):
			node.connect("encounter_selected", Callable(self, "_on_encounter_selected"))
	
	initialize_node_accessibility()
	
	# Make the PathDrawer update its connections
	if $PathLines.has_method("update_connections"):
		$PathLines.update_connections()
		
	check_battle_result()
	if GameState.get_current_node_id() != "":
		var current_node_id = GameState.get_current_node_id()
		print("Positioning player at node: " + current_node_id)
		
		# Find the node with this ID
		var encounter_node = find_encounter_node_by_id(current_node_id)
		if encounter_node:
			# Set player position to this node
			position_player_at_node(encounter_node)
			
			# Update available nodes based on this position
			update_available_nodes(encounter_node)
		else:
			print("ERROR: Could not find node with ID: " + current_node_id)
	else:
		print("No current node ID - placing at start position")
	
	var gold_display_scene = load("res://Cryptid-Menagerie/scenes/gold_display.tscn")
	if gold_display_scene:
		var gold_display = gold_display_scene.instantiate()
		add_child(gold_display)
		# Move it to the top of the scene tree so it renders above everything
		move_child(gold_display, get_child_count() - 1)
		print("Gold display added to overworld")
	
	if GoldManager and GameState.get_current_node_id() == "":
		GoldManager.reset()
		GoldManager.add_gold(100, "Debug test gold")


# Handler for when an encounter node is selected
func _on_encounter_selected(node_data):
	# Skip if node has empty encounter type (start node)
	if node_data.encounter_type == "":
		print("Start node clicked - no action")
		return
	
	print("Encounter selected: ", node_data)
	
	# Find the selected node
	var selected_node = find_node_by_id(node_data.node_id)
	if not selected_node:
		push_error("Could not find selected node: " + node_data.node_id)
		return
	
	# Update current node tracking
	for node in $EncounterNodes.get_children():
		if node is EncounterNode:
			node.set_current(false)
	
	selected_node.set_current(true)
	
	# Update in game state
	if GameState:
		GameState.set_current_node_id(node_data.node_id)
	
	# Set the appropriate biome based on the selected node
	encounter_manager.set_biome(node_data.biome)
	
	# Process based on encounter type
	if node_data.encounter_type == "reward":
		print("Reward node selected")
		transition_to_reward(node_data)
	elif node_data.encounter_type == "wild":
		# Start wild encounter
		encounter_manager.start_wild_encounter(node_data.node_id)
	elif node_data.encounter_type == "trainer":
		# Start trainer battle
		print("Trainer battle selected")

# Handle the transition to the battle scene
func _transition_to_battle(encounter_data):
	# Save any necessary game state
	GameState.save_overworld_state(self)
	
	# Create instance of the battle scene
	var battle_scene = load("res://battle_scene.tscn").instantiate()
	
	# Set up the battle with our encounter data
	battle_scene.setup_encounter(encounter_data)
	
	# Replace the current scene with the battle scene
	get_tree().root.add_child(battle_scene)
	get_tree().current_scene = battle_scene
	
	# Remove this scene, but don't free it if we want to come back
	get_tree().root.remove_child(self)

# Start a trainer battle with predefined trainer data
func _start_trainer_battle(node_data):
	# Load trainer data
	var trainer_data = load("res://trainers/" + node_data.trainer_id + ".tres")
	
	# Create trainer battle setup
	var battle_data = {
		"is_wild_encounter": false,
		"trainer": trainer_data,
		"biome": node_data.biome,
		"floor": current_floor
	}
	
	# Transition to battle
	_transition_to_battle(battle_data)

# Advance to the next floor
func advance_floor():
	current_floor += 1
	encounter_manager.set_floor(current_floor)
	# Additional logic for floor progression...

func initialize_node_accessibility():
	# Start with all nodes inaccessible
	for node in $EncounterNodes.get_children():
		if node is EncounterNode:
			node.set_accessible(false)
	
	# Make the start node accessible and current
	var start_node = $EncounterNodes/StartNode
	if start_node:
		start_node.set_accessible(true)
		start_node.set_current(true)
		
		# Make nodes connected to the start node accessible
		for connected_id in start_node.connected_nodes:
			var connected_node = find_node_by_id(connected_id)
			if connected_node:
				connected_node.set_accessible(true)

func find_node_by_id(node_id):
	for node in $EncounterNodes.get_children():
		if node is EncounterNode and node.node_id == node_id:
			return node
	return null

func handle_battle_completion(was_victorious, node_id):
	if was_victorious:
		# Find the completed node
		var completed_node = find_node_by_id(node_id)
		if completed_node:
			# Mark node as completed
			completed_node.set_completed(true)
			
			# Make connected nodes accessible
			for connected_id in completed_node.connected_nodes:
				var connected_node = find_node_by_id(connected_id)
				if connected_node:
					connected_node.set_accessible(true)
			
			# Update path visuals
			if $PathLines.has_method("update_connections"):
				$PathLines.update_connections()

# Add this function to process battle results
func check_battle_result():
	# Check if GameState has battle result data - use 'in' operator instead of has()
	if "last_battle_result" in GameState and GameState.last_battle_result != null:
		print("Processing battle result:", GameState.last_battle_result)
		
		var was_victorious = GameState.last_battle_result
		var node_id = ""
		
		# Get the node ID if available - use safer property checks
		if "current_encounter" in GameState and GameState.current_encounter != null:
			if GameState.current_encounter is Dictionary and "node_id" in GameState.current_encounter:
				node_id = GameState.current_encounter.node_id
				print("Battle was for node:", node_id)
		
		# Process the battle result
		if node_id != "":
			handle_battle_completion(was_victorious, node_id)
		
		# Clear the result data to avoid reprocessing
		GameState.last_battle_result = null
		
		# Optional: Clear the encounter data too
		GameState.current_encounter = null

func find_encounter_node_by_id(node_id: String):
	print("Searching for node with ID: " + node_id)
	
	# Find all encounter nodes in the scene
	var encounter_nodes = get_tree().get_nodes_in_group("encounter_nodes")
	print("Found " + str(encounter_nodes.size()) + " encounter nodes")
	
	# Debug - print all node IDs
	for node in encounter_nodes:
		# First check for direct property
		if "node_id" in node:
			print("Node found with ID: " + str(node.node_id))
		# Then try metadata
		elif node.has_meta("node_id"):
			print("Node found with metadata ID: " + str(node.get_meta("node_id")))
		# Generic print
		else:
			print("Node without ID property: " + node.name)
	
	# Look for the node with matching ID - check multiple ways
	for node in encounter_nodes:
		# 1. Check direct property match
		if "node_id" in node and node.node_id == node_id:
			print("Found matching node by direct property: " + node_id)
			return node
			
		# 2. Check metadata match
		elif node.has_meta("node_id") and node.get_meta("node_id") == node_id:
			print("Found matching node by metadata: " + node_id)
			return node
			
		# 3. Check name match (if node names follow ID pattern)
		elif node.name.to_lower() == node_id.to_lower():
			print("Found matching node by name: " + node_id)
			return node
			
		# 4. Check partial match (if IDs are stored with prefixes/suffixes)
		elif "node_id" in node and node_id in node.node_id:
			print("Found matching node by partial ID: " + node_id + " in " + node.node_id)
			return node
	
	# Additional check for nodes with encounter_data
	for node in encounter_nodes:
		if "encounter_data" in node and "node_id" in node.encounter_data:
			if node.encounter_data.node_id == node_id:
				print("Found matching node by encounter_data: " + node_id)
				return node
	
	# If not found after all checks, try to find the closest match
	var best_match = null
	var highest_similarity = 0
	
	for node in encounter_nodes:
		var node_name = ""
		if "node_id" in node:
			node_name = node.node_id
		elif node.has_meta("node_id"):
			node_name = node.get_meta("node_id")
		else:
			node_name = node.name
			
		# Simple similarity check - count matching characters
		var similarity = 0
		for i in range(min(node_name.length(), node_id.length())):
			if i < node_name.length() and i < node_id.length() and node_name[i] == node_id[i]:
				similarity += 1
				
		if similarity > highest_similarity:
			highest_similarity = similarity
			best_match = node
	
	if best_match != null and highest_similarity > node_id.length() / 2:
		var best_match_id = ""
		if "node_id" in best_match:
			best_match_id = best_match.node_id
		else:
			best_match_id = best_match.name
		print("Found best matching node: " + best_match_id)
		return best_match
	
	# If still not found, try to use a default or starting node
	var default_node = find_default_start_node()
	if default_node:
		print("Using default node as fallback")
		return default_node
		
	# If all else fails, return null
	print("ERROR: Could not find any matching node for ID: " + node_id)
	return null

func position_player_at_node(node):
	# Get the player character
	var player = get_node_or_null("PlayerCharacter") # adjust path as needed
	if player:
		# Set player position to node position
		player.global_position = node.global_position
		print("Positioned player at: " + str(node.global_position))
	else:
		print("ERROR: Player character not found")
		

func update_available_nodes(current_node):
	# First reset all nodes to unavailable
	var all_nodes = get_tree().get_nodes_in_group("encounter_nodes")
	for node in all_nodes:
		node.set_accessible(false)
	
	# Make connected nodes available
	for connected_id in current_node.connected_nodes:
		var connected_node = find_encounter_node_by_id(connected_id)
		if connected_node:
			connected_node.set_accessible(true)
			print("Made node accessible: " + connected_id)
	
	# Mark current node as completed and current
	current_node.set_completed(true)
	current_node.set_current(true)

# Helper function to find a default/starting node
func find_default_start_node():
	# Find all encounter nodes
	var encounter_nodes = get_tree().get_nodes_in_group("encounter_nodes")
	
	# First try to find a node explicitly marked as start
	for node in encounter_nodes:
		if ("is_start" in node and node.is_start) or node.has_meta("is_start"):
			print("Found start node: " + node.name)
			return node
	
	# If no explicit start node, try to find one with "start" in the name
	for node in encounter_nodes:
		if "start" in node.name.to_lower():
			print("Found node with 'start' in name: " + node.name)
			return node
	
	# If that fails, just return the first node
	if encounter_nodes.size() > 0:
		print("Using first node as default: " + encounter_nodes[0].name)
		return encounter_nodes[0]
		
	return null

func _on_node_clicked(node):  # The function name might be different in your code
	print("Node clicked: " + node.name)
	
	# Skip if node is not accessible
	if "is_accessible" in node and not node.is_accessible:
		print("Node not accessible, ignoring click")
		return
		
	# Skip if already current
	if "is_current" in node and node.is_current:
		print("Node is already current, ignoring click")
		return
	
	# Block multiple clicks by adding a timer or flag
	if has_meta("processing_click") and get_meta("processing_click"):
		print("Already processing a click, ignoring")
		return
		
	# Set flag to prevent multiple processing
	set_meta("processing_click", true)
	
	# Get node data - handle both direct properties and encounter_data
	var node_id = ""
	var encounter_type = ""
	
	if "node_id" in node:
		node_id = node.node_id
	
	if "encounter_type" in node:
		encounter_type = node.encounter_type
	elif "encounter_data" in node and "encounter_type" in node.encounter_data:
		encounter_type = node.encounter_data.encounter_type
		
	print("Clicked node - ID: " + node_id + ", Type: " + encounter_type)
	
	# Process based on encounter type
	match encounter_type:
		"wild", "trainer":
			print("Battle node clicked")
			# Prepare and process battle encounter...
			# Your existing battle transition code...
			
		"reward":
			print("REWARD NODE CLICKED")
			
			# Set up reward data
			var reward_data = {
				"node_id": node_id,
				"encounter_type": "reward"
			}
			
			# Find connected nodes to determine next node
			if "connected_nodes" in node:
				for connected_id in node.connected_nodes:
					# Find a non-reward node for next destination
					var connected_node = find_encounter_node_by_id(connected_id)
					if connected_node and (
						!("encounter_type" in connected_node) or 
						connected_node.encounter_type != "reward"
					):
						reward_data["next_node_id"] = connected_id
						print("Found next node after reward: " + connected_id)
						break
			
			# Store encounter data in GameState
			GameState.set_current_encounter(reward_data)
			print("Set reward data in GameState")
			
			# CRITICAL FIX: Use a small delay before changing scenes
			# This prevents issues with multiple click processing
			await get_tree().create_timer(0.1).timeout
			
			# Transition to the reward scene
			print("Transitioning to reward scene...")
			get_tree().change_scene_to_file("res://Cryptid-Menagerie/scenes/reward_scene.tscn")
			return  # Important to stop code execution here
			
		"rest":
			print("Rest node clicked")
			# Handle rest node logic...
			
		_:
			print("Unknown node type: " + encounter_type)
	
	# Reset click processing flag after a short delay
	# This ensures the flag gets reset even if there's an error above
	await get_tree().create_timer(0.5).timeout
	set_meta("processing_click", false)

# Find this section and update it to the following:
func handle_encounter(node_id, encounter_type):
	# This demonstrates the structure - adapt to match your actual function
	
	# Create encounter data
	var encounter_data = {
		"node_id": node_id,
		"encounter_type": encounter_type,
		"biome": "Forest",  # Adjust as needed
		"trainer_id": ""    # Add if relevant
	}
	
	# Store in GameState
	GameState.set_current_encounter(encounter_data)
	print("Encounter selected: " + str(encounter_data))
	
	# Select the appropriate scene based on encounter type
	var scene_path = ""
	
	if encounter_type == "wild" or encounter_type == "trainer":
		scene_path = "res://Cryptid-Menagerie/scenes/battle_scene.tscn"
	elif encounter_type == "reward":
		scene_path = "res://Cryptid-Menagerie/scenes/reward_scene.tscn"
	else:
		# Default to overworld
		print("Unknown encounter type: " + encounter_type)
		return
	
	# Print debug info
	print("Transitioning to scene: " + scene_path)
	
	# Use call_deferred to prevent potential timing issues
	# This is key to ensuring the scene change happens reliably
	get_tree().call_deferred("change_scene_to_file", scene_path)

func transition_to_reward(encounter_data):
	print("Transitioning to reward scene")
	
	# Save this in GameState for reference
	GameState.set_current_encounter(encounter_data)
	
	# Create instance of the reward scene
	var reward_scene_path = "res://Cryptid-Menagerie/scenes/reward_scene.tscn"
	print("Loading reward scene from: " + reward_scene_path)
	
	var reward_scene_resource = load(reward_scene_path)
	if reward_scene_resource == null:
		print("ERROR: Failed to load reward scene resource at " + reward_scene_path)
		return
		
	var reward_scene = reward_scene_resource.instantiate()
	if reward_scene == null:
		print("ERROR: Failed to instantiate reward scene")
		return
	
	print("Reward scene instantiated successfully")
	
	# Set up the reward scene with encounter data if needed
	if reward_scene.has_method("setup_encounter"):
		reward_scene.setup_encounter(encounter_data)
	
	# Replace the current scene with the reward scene
	get_tree().root.add_child(reward_scene)
	get_tree().current_scene = reward_scene
	
	# Remove this scene, but don't free it
	get_tree().root.remove_child(self)
	print("Scene transition complete")

# Now modify your node click handler to call this function
# Find where you handle node clicks and set encounter data
# After you determine the encounter type is "reward", add:


