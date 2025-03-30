extends Node2D

# Properties for encounter handling
var is_wild_encounter = false
var encounter_data = null

# References to important nodes
@onready var game_controller = $TileMapLayer/GameController
@onready var tile_map_layer = $TileMapLayer
@onready var game_instructions = $UIRoot/GameInstructions

# Called when the node enters the scene tree
func _ready():
	# Any initialization from your main.gd that you want to keep
	
	# Set default battle type (wild battle where catching is allowed)
	game_controller.is_trainer_battle = false
	
	# Retrieve encounter data from GameState
	if "current_encounter" in GameState and GameState.current_encounter != null:
		encounter_data = GameState.current_encounter
		print("Loaded encounter data:", encounter_data)
		
		# Configure the battle based on encounter type
		setup_encounter()
	else:
		print("No encounter data found in GameState")

# Set up the battle based on encounter data
func setup_encounter():
	# Clear any existing cryptids first
	clear_existing_cryptids()
	
	# Determine if this is a wild encounter
	is_wild_encounter = encounter_data.has("is_wild_encounter") and encounter_data.is_wild_encounter
	
	# Set game controller mode
	if game_controller:
		game_controller.is_trainer_battle = !is_wild_encounter
	
	# Setup enemies based on encounter data
	if encounter_data.has("cryptids") and encounter_data.cryptids.size() > 0:
		spawn_enemy_cryptids(encounter_data.cryptids)
		
		# Limit player cryptids to match enemy count
		limit_player_cryptids(encounter_data.cryptids.size())
	
	# Update UI elements
	if game_instructions:
		if is_wild_encounter:
			game_instructions.text = "A wild encounter has appeared in the " + encounter_data.biome + "!"
		else:
			game_instructions.text = "Trainer battle!"
	
	# Make sure the turn order is updated
	if tile_map_layer:
		tile_map_layer.sort_cryptids_by_speed(tile_map_layer.all_cryptids_in_play)
		
	# Update turn order UI
	var turn_order = $UIRoot/TurnOrder
	if turn_order and turn_order.has_method("initialize_cryptid_labels"):
		turn_order.initialize_cryptid_labels()
	
	# Initialize the first cryptid's turn
	initialize_first_cryptid_turn()
# Spawn enemy cryptids based on encounter data
func spawn_enemy_cryptids(cryptids):
	# Get references to necessary nodes
	var enemy_team = $TileMapLayer/EnemyTeam
	var tile_map_layer = $TileMapLayer
	
	if !enemy_team or !tile_map_layer:
		print("Error: Could not find enemy team or tile map layer")
		return
	
	print("Spawning", cryptids.size(), "enemy cryptids")
	
	# Use the existing initialize_starting_positions function with our wild cryptids
	tile_map_layer.enemy_cryptids_in_play = tile_map_layer.initialize_starting_positions(
		tile_map_layer.enemy_starting_positions, 
		enemy_team,
		cryptids
	)
	
	# Update all_cryptids_in_play to include these new cryptids
	for cryptid in tile_map_layer.enemy_cryptids_in_play:
		tile_map_layer.all_cryptids_in_play.append(cryptid)
	
	# Sort by speed
	tile_map_layer.sort_cryptids_by_speed(tile_map_layer.all_cryptids_in_play)

# End battle and return to overworld
func end_battle(was_victorious = true):
	print("Battle ended with " + ("victory" if was_victorious else "defeat"))
	
	# Store battle result in GameState
	GameState.last_battle_result = was_victorious
	
	# Get the overworld scene path
	var overworld_scene_path = "res://Cryptid-Menagerie/scenes/overworld_map.tscn"
	
	# Use a safer method to get the scene tree
	var scene_tree = Engine.get_main_loop()
	if scene_tree:
		print("Found scene tree, changing scene")
		# Add a small delay to make sure everything is cleaned up
		await scene_tree.create_timer(0.5).timeout
		scene_tree.change_scene_to_file(overworld_scene_path)
	else:
		print("ERROR: Could not get scene tree")
		# Try the regular method as fallback
		if get_tree():
			get_tree().change_scene_to_file(overworld_scene_path)
		else:
			print("Critical error: Both scene_tree and get_tree() are null")

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
