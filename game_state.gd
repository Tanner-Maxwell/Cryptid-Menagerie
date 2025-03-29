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
	initialize_player_team()

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
