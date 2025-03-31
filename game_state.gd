extends Node

# Game state variables
var current_floor = 1
var current_biome = "Forest"
var current_encounter = null
var player_team = null
var last_battle_result = null
var _current_node_id: String = ""

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
	print("========================")
