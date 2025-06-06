extends Node

# Game state variables
var current_floor = 1
var current_biome = "Forest"
var current_encounter = null
var player_team = null
var last_battle_result = null
var _current_node_id: String = ""

# Currency system
var gold: int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	#initialize_player_team()
	initialize_player_team_with_test_cryptids()

	if player_team == null:
		print("Initializing player team in GameState")
		player_team = Team.new()
		

# Initialize player team with starter cryptid
func initialize_player_team():
	player_team = Team.new()
	# Add starter cryptid - replace with path to your starter cryptid
	# var starter = load("res://path/to/starter_cryptid.tres")
	# player_team.add_cryptid(starter)

# Set the current encounter data
func set_current_encounter(encounter_data):
	current_encounter = encounter_data

# Get the current encounter data
func get_current_encounter():
	return current_encounter

func set_current_node_id(id: String):
	_current_node_id = id
	
func get_current_node_id() -> String:
	return _current_node_id

# Gold management functions
func add_gold(amount: int):
	gold += amount
	print("Added " + str(amount) + " gold. Total: " + str(gold))
	
func remove_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		print("Removed " + str(amount) + " gold. Total: " + str(gold))
		return true
	else:
		print("Not enough gold! Needed: " + str(amount) + ", Available: " + str(gold))
		return false
		
func get_gold() -> int:
	return gold
	
func set_gold(amount: int):
	gold = amount
	print("Set gold to: " + str(gold))

# Initialize gold when starter is selected
func initialize_starting_gold():
	set_gold(100)
	print("Initialized starting gold to 100")

func initialize_player_team_with_test_cryptids():
	print("Initializing player team with test cryptids")
	
	# Create a team if it doesn't exist
	if player_team == null:
		player_team = Team.new()
	
	# Check if team is empty
	var team_size = 0
	if player_team.has_method("get_cryptids"):
		team_size = player_team.get_cryptids().size()
	elif "_content" in player_team:
		team_size = player_team._content.size()
	
	if team_size == 0:
		print("Adding test cryptids to empty team")
		
		# Add a test Glowfly
		var glowfly = load("res://Cryptid-Menagerie/data/cryptids/CryptidResources/glowfly.tres")
		if glowfly:
			if player_team.has_method("add_cryptid"):
				player_team.add_cryptid(glowfly)
				print("Added Glowfly to player team")
			else:
				print("WARNING: player_team doesn't have add_cryptid method")
		else:
			print("ERROR: Could not load glowfly resource")
			
		# Initialize gold for test cryptids
		initialize_starting_gold()
	else:
		print("Player team already has", team_size, "cryptids")

func debug_player_team():
	print("=== Player Team Debug ===")
	if player_team == null:
		print("Player team is null!")
		return
		
	var team_cryptids = []
	if player_team.has_method("get_cryptids"):
		team_cryptids = player_team.get_cryptids()
	elif "_content" in player_team:
		team_cryptids = player_team._content
	
	print("Total cryptids in team:", team_cryptids.size())
	for i in range(team_cryptids.size()):
		print(i, ":", team_cryptids[i].name)
	print("Current gold:", gold)
	print("========================")

func reset_to_defaults():
	print("=== RESETTING GAMESTATE TO DEFAULT VALUES ===")
	
	# Reset progression
	current_floor = 1
	current_biome = "Forest"
	current_encounter = null
	last_battle_result = null
	_current_node_id = ""  # Reset to empty/starting node
	gold = 0  # Reset gold
	
	if FilmManager:
		FilmManager.reset()
		
	print("Reset progression values")
	
	# Reset player team completely
	if player_team:
		print("Clearing existing player team...")
		# Clear the existing team
		if player_team.has_method("get_cryptids"):
			var existing_cryptids = player_team.get_cryptids()
			print("Removing", existing_cryptids.size(), "existing cryptids")
			for cryptid in existing_cryptids:
				if player_team.has_method("remove_cryptid"):
					player_team.remove_cryptid(cryptid)
		elif "_content" in player_team:
			print("Clearing _content array with", player_team._content.size(), "cryptids")
			player_team._content.clear()
	else:
		# Create a new team if it doesn't exist
		player_team = Team.new()
		print("Created new player team")
	
	print("Player team cleared")
	print("=== GAMESTATE RESET COMPLETE ===")

func start_new_game():
	print("Starting new game...")
	reset_to_defaults()
	
	# Don't auto-initialize cryptids here - let the starter selection handle it
	print("New game initialized - ready for starter selection")

func restart_game():
	print("Restarting game with test cryptids...")
	reset_to_defaults()
	
	# Reinitialize with test cryptids for quick restart
	initialize_player_team_with_test_cryptids()
	
	print("Game restarted with test cryptids")
