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
	# Determine if this is a wild encounter
	is_wild_encounter = encounter_data.has("is_wild_encounter") and encounter_data.is_wild_encounter
	
	# Set game controller mode
	if game_controller:
		game_controller.is_trainer_battle = !is_wild_encounter
	
	# Setup enemies based on encounter data
	if encounter_data.has("cryptids") and encounter_data.cryptids.size() > 0:
		spawn_enemy_cryptids(encounter_data.cryptids)
	
	# Update UI elements
	if game_instructions:
		if is_wild_encounter:
			game_instructions.text = "A wild encounter has appeared in the " + encounter_data.biome + "!"
		else:
			game_instructions.text = "Trainer battle!"

# Spawn enemy cryptids from encounter data
func spawn_enemy_cryptids(cryptids):
	# References to your existing nodes
	var enemy_team = $TileMapLayer/EnemyTeam
	
	if !enemy_team or !tile_map_layer:
		print("Error: Could not find enemy team or tile map layer")
		return
	
	print("Spawning", cryptids.size(), "enemy cryptids")
	
	# Clear existing enemies
	tile_map_layer.enemy_cryptids_in_play.clear()
	
	# Spawn each enemy cryptid
	for i in range(cryptids.size()):
		if i >= tile_map_layer.enemy_starting_positions.size():
			print("Warning: Not enough starting positions for all enemies")
			break
			
		var cryptid = cryptids[i]
		print("Spawning enemy:", cryptid.name)
		
		# Create a new instance
		var blank_cryptid = tile_map_layer.blank_cryptid.instantiate()
		blank_cryptid.cryptid = cryptid
		blank_cryptid.hand = $UIRoot/Hand
		
		# Position it
		var pos = tile_map_layer.enemy_starting_positions[i]
		blank_cryptid.position = tile_map_layer.map_to_local(pos)
		
		# Add to scene
		enemy_team.add_child(blank_cryptid)
		
		# Add to tracking arrays
		tile_map_layer.enemy_cryptids_in_play.append(blank_cryptid)
		tile_map_layer.all_cryptids_in_play.append(blank_cryptid)
	
	# Sort by speed
	tile_map_layer.sort_cryptids_by_speed(tile_map_layer.all_cryptids_in_play)
	
	# Update turn order display
	var turn_order = $UIRoot/TurnOrder
	if turn_order and turn_order.has_method("initialize_cryptid_labels"):
		turn_order.initialize_cryptid_labels()

# End battle and return to overworld
func end_battle(was_victorious = true):
	# Store battle result in GameState
	GameState.last_battle_result = was_victorious
	
	# Get the overworld scene path
	var overworld_scene_path = "res://Cryptid-Menagerie/scenes/overworld_map.tscn"
	
	# Transition back to overworld
	get_tree().change_scene_to_file(overworld_scene_path)

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
