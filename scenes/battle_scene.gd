extends Node2D

# Properties for encounter handling
var is_wild_encounter = false
var encounter_data = null

# References to important nodes
@onready var game_controller = $TileMapLayer/GameController
@onready var tile_map_layer = $TileMapLayer
@onready var game_instructions = $UIRoot/GameInstructions
@onready var team_viewer = %TeamViewer  # Make sure this reference is correct

# Called when the node enters the scene tree
func _ready():
	# Make sure critical references are set first
	tile_map_layer = $TileMapLayer
	game_controller = $TileMapLayer/GameController
	game_instructions = $UIRoot/GameInstructions
	if "initialize_player_team_with_test_cryptids" in GameState:
		GameState.initialize_player_team_with_test_cryptids()
	# Ensure tile_map_layer has a selected_cryptid
	if tile_map_layer and tile_map_layer.get("selected_cryptid") == null:
		# Initialize with a default value if needed
		print("No selected_cryptid found, initializing with default")
		tile_map_layer.selected_cryptid = null
	
	# Retrieve encounter data from GameState
	if "current_encounter" in GameState and GameState.current_encounter != null:
		encounter_data = GameState.current_encounter
		print("Loaded encounter data:", encounter_data)
		
		# Configure the battle based on encounter type
		setup_encounter()
	else:
		print("No encounter data found in GameState")
		
		
	var team_viewer_scene = load("res://Cryptid-Menagerie/scenes/team_viewer.tscn")
	if team_viewer_scene:
		team_viewer = team_viewer_scene.instantiate()
		
		# Add to UI layer
		var ui_root = get_node_or_null("/root/VitaChrome/UIRoot")
		if ui_root:
			ui_root.add_child(team_viewer)
			print("Team viewer added to UI")
		else:
			add_child(team_viewer)
			print("Team viewer added to main scene")
			
		team_viewer.hide()  # Start hidden
	
	var show_team_button = $ShowTeam  # Adjust the path if needed
	if show_team_button:
		show_team_button.connect("pressed", Callable(self, "toggle_team_viewer"))
		print("Team button connected successfully")
	else:
		print("ERROR: Could not find ShowTeam button")
		
	var gold_display_scene = load("res://Cryptid-Menagerie/scenes/gold_display.tscn")
	if gold_display_scene:
		var gold_display = gold_display_scene.instantiate()
		add_child(gold_display)
		# Move it to the top of the scene tree so it renders above everything
		move_child(gold_display, get_child_count() - 1)
		print("Gold display added to overworld")
		
	var film_display_scene = load("res://Cryptid-Menagerie/scenes/film_display.tscn")
	if film_display_scene:
		var film_display = film_display_scene.instantiate()
		add_child(film_display)
		# Move it to the top of the scene tree so it renders above everything
		move_child(film_display, get_child_count() - 1)
		print("Film display added to scene")

func _input(event):
	# ... existing input code ...
	
	# Check for "C" key press
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			print("C key pressed - toggle team viewer")
			toggle_team_viewer()
			# Mark event as handled
			get_viewport().set_input_as_handled()


func toggle_team_viewer():
	print("Toggling team viewer")
	if team_viewer:
		if team_viewer.visible:
			team_viewer.hide()
		else:
			team_viewer.open()
	else:
		print("ERROR: team_viewer reference is null")

# Set up the battle based on encounter data
func setup_encounter():
	# Determine if this is a wild encounter
	is_wild_encounter = encounter_data.has("is_wild_encounter") and encounter_data.is_wild_encounter
	
	# Set game controller mode
	if game_controller:
		game_controller.is_trainer_battle = !is_wild_encounter
	
	# Setup enemies based on encounter data
	if encounter_data.has("cryptids") and encounter_data.cryptids.size() > 0:
		spawn_enemy_cryptids(encounter_data.cryptids)
		
		# Set up player cryptids to match enemy count
		setup_player_cryptids(encounter_data.cryptids.size())
	
	# Update UI elements
	if game_instructions:
		if is_wild_encounter:
			game_instructions.text = "A wild encounter has appeared in the " + encounter_data.biome + "!"
		else:
			game_instructions.text = "Trainer battle!"
			
	# Sort cryptids by speed
	if tile_map_layer:
		tile_map_layer.sort_cryptids_by_speed(tile_map_layer.all_cryptids_in_play)
		
	# Initialize the turn order display
	var turn_order = $UIRoot/TurnOrder
	if turn_order and turn_order.has_method("initialize_cryptid_labels"):
		turn_order.initialize_cryptid_labels()
	
	# Initialize the first player cryptid as selected
	initialize_first_player_cryptid()
	
	# Set up the action menu
	var action_menu = $UIRoot/ActionSelectMenu
	if action_menu and action_menu.has_method("prompt_player_for_action"):
		action_menu.prompt_player_for_action()
	
	## Initialize the first cryptid's turn
	#initialize_first_cryptid_turn()

func spawn_enemy_cryptids(cryptids):
	# Get references to necessary nodes
	var enemy_team = $TileMapLayer/EnemyTeam
	
	if !enemy_team or !tile_map_layer:
		print("Error: Required nodes not found")
		return
	
	# Clear any existing enemy cryptids first
	for child in enemy_team.get_children():
		if child.has_method("set_health_values"):  # Identify cryptid nodes
			if tile_map_layer.enemy_cryptids_in_play.has(child):
				tile_map_layer.enemy_cryptids_in_play.erase(child)
			if tile_map_layer.all_cryptids_in_play.has(child):
				tile_map_layer.all_cryptids_in_play.erase(child)
			enemy_team.remove_child(child)
			child.queue_free()
	
	# Reset tracking array
	tile_map_layer.enemy_cryptids_in_play.clear()
	
	# Use the modified initialize_starting_positions function with our wild cryptids
	var spawned_cryptids = tile_map_layer.initialize_starting_positions(
		tile_map_layer.enemy_starting_positions, 
		enemy_team,
		cryptids
	)
	
	# IMPORTANT: Make sure we're adding to enemy_cryptids_in_play, not player_cryptids_in_play
	tile_map_layer.enemy_cryptids_in_play = []  # Clear array to be safe
	tile_map_layer.enemy_cryptids_in_play.append_array(spawned_cryptids)
	
	# Update all_cryptids_in_play
	for cryptid in spawned_cryptids:
		if !tile_map_layer.all_cryptids_in_play.has(cryptid):
			tile_map_layer.all_cryptids_in_play.append(cryptid)
	
	# Debug team assignments after setup
	tile_map_layer.debug_team_assignments()

func end_battle(was_victorious = true):
	print("Battle ended with " + ("victory" if was_victorious else "defeat"))
	
	# Store battle result in GameState
	GameState.last_battle_result = was_victorious
	
	# IMPORTANT: Update player team with any changes
	update_team_after_battle()
	
	# Determine what scene to go to next
	var next_scene = "res://Cryptid-Menagerie/scenes/overworld_map.tscn"
	
	# Use a safer method to get the scene tree
	var scene_tree = Engine.get_main_loop()
	if scene_tree:
		print("Found scene tree, changing scene")
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


# Add this new function to ensure teams are updated
func update_team_after_battle():
	print("Updating player team after battle...")
	
	# Get references to player team tracking
	var player_team_model = GameState.player_team if GameState.has_node("player_team") else null
	
	# If we don't have GameState team reference, try to find it elsewhere
	if not player_team_model:
		var player_team_node = get_node_or_null("/root/VitaChrome/PlayerTeam")
		if player_team_node and player_team_node.get("cryptidTeam"):
			player_team_model = player_team_node.cryptidTeam
			print("Using PlayerTeam.cryptidTeam as model")
	
	if not player_team_model:
		print("ERROR: Could not find player team model")
		return
	
	# Get the remaining player cryptids 
	var remaining_cryptids = []
	for cryptid_node in tile_map_layer.player_cryptids_in_play:
		if is_instance_valid(cryptid_node) and cryptid_node.cryptid:
			remaining_cryptids.append(cryptid_node.cryptid)
			print("Active cryptid: " + cryptid_node.cryptid.name)
	
	# Remove any cryptids not in remaining_cryptids list from the team model
	if player_team_model.has_method("get_cryptids") and player_team_model.has_method("remove_cryptid"):
		var team_cryptids = player_team_model.get_cryptids()
		
		# Track all cryptids that should be removed
		var to_remove = []
		for team_cryptid in team_cryptids:
			var still_active = false
			
			# Check if this cryptid is in our remaining list
			for active in remaining_cryptids:
				if team_cryptid.name == active.name:
					still_active = true
					break
			
			# If this cryptid is not in our active list
			if not still_active:
				to_remove.append(team_cryptid)
		
		# Now remove all defeated cryptids
		for defeated in to_remove:
			print("Removing defeated cryptid from team model: " + defeated.name)
			player_team_model.remove_cryptid(defeated)
	
	print("Team update complete. Final team:")
	# Print final team for verification
	if player_team_model.has_method("get_cryptids"):
		var final_team = player_team_model.get_cryptids()
		for i in range(final_team.size()):
			print(str(i+1) + ". " + final_team[i].name)


# Functions from your main.gd that you want to keep
func set_wild_battle():
	game_controller.is_trainer_battle = false
	if game_instructions:
		game_instructions.text = "A wild battle has started! You can catch the last enemy cryptid."
	print("Battle configured as a wild battle (catching allowed)")

func set_trainer_battle(trainer_name = "Trainer"):
	game_controller.is_trainer_battle = true
	if game_instructions:
		game_instructions.text = trainer_name + " has challenged you to a battle!"
	print("Battle configured as a trainer battle (catching not allowed)")

# Function to clear existing cryptids
func clear_existing_cryptids():
	# Clear enemy team
	var enemy_team = $TileMapLayer/EnemyTeam
	if enemy_team:
		for child in enemy_team.get_children():
			if child.has_method("set_health_values"):  # A way to identify cryptid nodes
				enemy_team.remove_child(child)
				child.queue_free()
	
	# Reset tracking arrays
	if tile_map_layer:
		tile_map_layer.enemy_cryptids_in_play.clear()
		tile_map_layer.player_cryptids_in_play.clear()
		tile_map_layer.all_cryptids_in_play.clear()

# Function to limit player cryptids to match enemy count
func limit_player_cryptids(enemy_count):
	var player_team = $TileMapLayer/PlayerTeam
	if player_team:
		# Get existing player cryptids
		var player_cryptids = []
		for child in player_team.get_children():
			if child.has_method("set_health_values"):  # A way to identify cryptid nodes
				player_cryptids.append(child)
		
		# If we have more than needed, remove extras
		if player_cryptids.size() > enemy_count:
			for i in range(enemy_count, player_cryptids.size()):
				var child = player_cryptids[i]
				# Remove from tracking arrays
				if tile_map_layer:
					tile_map_layer.player_cryptids_in_play.erase(child)
					tile_map_layer.all_cryptids_in_play.erase(child)
				# Remove from scene
				player_team.remove_child(child)
				child.queue_free()
		
		# Update all_cryptids_in_play
		if tile_map_layer:
			tile_map_layer.all_cryptids_in_play.clear()
			for child in player_team.get_children():
				if child.has_method("set_health_values"):
					tile_map_layer.player_cryptids_in_play.append(child)
					tile_map_layer.all_cryptids_in_play.append(child)
			for child in $TileMapLayer/EnemyTeam.get_children():
				if child.has_method("set_health_values"):
					tile_map_layer.all_cryptids_in_play.append(child)

# Initialize the first cryptid's turn
func initialize_first_cryptid_turn():
	if tile_map_layer and tile_map_layer.all_cryptids_in_play.size() > 0:
		var first_cryptid = tile_map_layer.all_cryptids_in_play[0]
		
		# Set as selected
		if first_cryptid and first_cryptid.cryptid:
			first_cryptid.cryptid.currently_selected = true
			
			# Initialize hand
			var hand = $UIRoot/Hand
			if hand and hand.has_method("switch_cryptid_deck"):
				hand.switch_cryptid_deck(first_cryptid.cryptid)
				
			# Initialize game controller
			if game_controller and game_controller.has_method("setup_cryptid_turn"):
				game_controller.setup_cryptid_turn(first_cryptid.cryptid)

func reset_battle_state():
	# Reset all critical variables to safe defaults
	if tile_map_layer:
		tile_map_layer.selected_cryptid = null
		tile_map_layer.enemy_cryptids_in_play.clear()
		tile_map_layer.player_cryptids_in_play.clear()
		tile_map_layer.all_cryptids_in_play.clear()
		
		# Reset action flags
		tile_map_layer.move_action_bool = false
		tile_map_layer.attack_action_bool = false
		
		# Reset any other tile_map_layer state
		if tile_map_layer.has_method("reset_for_new_cryptid"):
			tile_map_layer.reset_for_new_cryptid()

func setup_player_cryptids(num_enemies):
	print("Setting up player cryptids to match", num_enemies, "enemies")
	
	# Get references to necessary nodes
	var player_team_node = $TileMapLayer/PlayerTeam
	var tile_map_layer = $TileMapLayer
	
	if !player_team_node || !tile_map_layer:
		print("Error: Required nodes not found for player setup")
		return
	
	# Clear existing player cryptids
	for child in player_team_node.get_children():
		# Skip nodes that aren't cryptids (like labels)
		if !child.has_method("set_health_values"):
			continue
			
		# Remove from tracking arrays before removing from scene
		if tile_map_layer.player_cryptids_in_play.has(child):
			tile_map_layer.player_cryptids_in_play.erase(child)
		if tile_map_layer.all_cryptids_in_play.has(child):
			tile_map_layer.all_cryptids_in_play.erase(child)
			
		# Remove from scene
		player_team_node.remove_child(child)
		child.queue_free()
	
	# Reset player cryptids array
	tile_map_layer.player_cryptids_in_play.clear()
	
	# Get the player's team from GameState
	var player_cryptids = []
	if GameState.player_team:
		if GameState.player_team.has_method("get_cryptids"):
			player_cryptids = GameState.player_team.get_cryptids()
		elif "_content" in GameState.player_team:
			player_cryptids = GameState.player_team._content
			
		print("Got", player_cryptids.size(), "cryptids from GameState")
	else:
		print("WARNING: No player team found in GameState")
		return
	
	# Limit to the number of enemies
	var count = min(num_enemies, player_cryptids.size())
	print("Using", count, "player cryptids for this battle")
	
	# Create and position player cryptids
	for i in range(count):
		# Skip if we've run out of available positions
		if i >= tile_map_layer.player_starting_positions.size():
			print("WARNING: Not enough starting positions for all player cryptids")
			break
			
		var cryptid_resource = player_cryptids[i]
		print("Spawning player cryptid:", cryptid_resource.name)
		
		# Create the cryptid instance
		var blank_cryptid = tile_map_layer.blank_cryptid.instantiate()
		blank_cryptid.cryptid = cryptid_resource
		blank_cryptid.hand = $UIRoot/Hand
		
		# Position it
		var pos = tile_map_layer.player_starting_positions[i]
		blank_cryptid.position = tile_map_layer.map_to_local(pos)
		
		# Add to scene
		player_team_node.add_child(blank_cryptid)
		
		# IMPORTANT: Make sure we're adding to player_cryptids_in_play, not enemy_cryptids_in_play
		tile_map_layer.player_cryptids_in_play.append(blank_cryptid)
		tile_map_layer.all_cryptids_in_play.append(blank_cryptid)
	
	# Debug team assignments after setup
	tile_map_layer.debug_team_assignments()

func initialize_first_player_cryptid():
	var tile_map_layer = $TileMapLayer
	
	if tile_map_layer and tile_map_layer.player_cryptids_in_play.size() > 0:
		# Get the first player cryptid
		var first_cryptid_node = tile_map_layer.player_cryptids_in_play[0]
		var first_cryptid = first_cryptid_node.cryptid
		
		# Set it as the selected cryptid
		tile_map_layer.selected_cryptid = first_cryptid_node
		first_cryptid.currently_selected = true
		
		print("Initialized", first_cryptid.name, "as selected cryptid")
		
		# Initialize the hand with this cryptid's cards
		var hand = $UIRoot/Hand
		if hand and hand.has_method("switch_cryptid_deck"):
			hand.switch_cryptid_deck(first_cryptid)
			print("Initialized hand with", first_cryptid.name, "cards")
		else:
			print("ERROR: Could not initialize hand with cryptid cards")
