extends Node
class_name WildEncounterManager

# Constants
const MAX_WILD_CRYPTIDS = 3

# Signals
signal encounter_setup_complete(encounter_data)

# Biome definitions with associated cryptids
var biome_resources = {
	"Forest": preload("res://Cryptid-Menagerie/data/biomes/forest_biome.tres")
	#"Volcano": preload("res://biomes/volcano_biome.tres"),
	#"Beach": preload("res://biomes/beach_biome.tres")
}

# Function to get the cryptids for a biome
func get_biome_cryptids(biome_name):
	if biome_resources.has(biome_name):
		return biome_resources[biome_name].cryptids
	return []
	
# Function to get encounter weights for a biome
func get_biome_weights(biome_name):
	if biome_resources.has(biome_name):
		return biome_resources[biome_name].encounter_weights
	return [60, 30, 10]  # Default weights

# Variables to track game state
var current_floor = 1
var current_biome = "Forest"

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize() # Initialize random number generator

# Set the current floor level (affects cryptid levels)
func set_floor(floor_num):
	current_floor = floor_num
	print("Floor set to: ", current_floor)

# Set the current biome (affects which cryptids can appear)
func set_biome(biome_name):
	if biome_resources.has(biome_name):
		current_biome = biome_name
		print("Biome set to: ", current_biome)
	else:
		push_error("Invalid biome name: " + biome_name)

# Generate a new wild encounter based on current settings
func generate_encounter():
	var encounter_data = {
		"biome": current_biome,
		"floor": current_floor,
		"cryptids": [],
		"is_wild_encounter": true
	}
	
	# Determine number of cryptids based on biome's encounter weights
	var weights = get_biome_weights(current_biome)
	var num_cryptids = _weighted_random_choice([1, 2, 3], weights)
	
	print("Generating encounter with ", num_cryptids, " cryptids in ", current_biome)
	
	# Select random cryptids from the current biome
	var available_cryptids = get_biome_cryptids(current_biome)
	
	# Make a copy to avoid modifying the original
	available_cryptids = available_cryptids.duplicate()
	
	# Check if we have any cryptids for this biome
	if available_cryptids.size() == 0:
		push_error("No cryptids defined for biome: " + current_biome)
		return encounter_data
	
	for i in range(num_cryptids):
		if available_cryptids.size() > 0:
			# Pick a random cryptid from the biome
			var cryptid_index = randi() % available_cryptids.size()
			var cryptid_resource = available_cryptids[cryptid_index]
			
			# Create a copy of the cryptid and set its level based on floor
			var encounter_cryptid = cryptid_resource.duplicate()
			encounter_cryptid.level = current_floor
			encounter_cryptid.update_stats()  # Recalculate stats based on new level
			
			# Add to the encounter
			encounter_data.cryptids.append(encounter_cryptid)
			
			# Remove this cryptid from the pool to avoid duplicates
			available_cryptids.remove_at(cryptid_index)
	
	# Emit signal with encounter data
	emit_signal("encounter_setup_complete", encounter_data)
	return encounter_data

# Helper function for weighted random selection
func _weighted_random_choice(items, weights):
	var total_weight = 0
	for weight in weights:
		total_weight += weight
	
	var random_value = randf() * total_weight
	var current_weight = 0
	
	for i in range(items.size()):
		current_weight += weights[i]
		if random_value <= current_weight:
			return items[i]
			
	# Fallback (should never reach here if weights are valid)
	return items[0]

# Start a wild encounter with the current settings
func start_wild_encounter(node_id):
	var encounter_data = generate_encounter()
	
	# Add the node ID to the encounter data
	encounter_data["node_id"] = node_id
	
	# Store in GameState
	GameState.set_current_encounter(encounter_data)
	
	# Get the path to your saved battle scene
	var battle_scene_path = "res://Cryptid-Menagerie/scenes/battle_scene.tscn"
	
	# Change to the battle scene
	get_tree().change_scene_to_file(battle_scene_path)
	
	return encounter_data
