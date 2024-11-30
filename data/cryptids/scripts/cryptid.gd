# Define a custom class named Cryptid that extends the Resource class
class_name Cryptid
extends Resource

# Declare exported variables for the cryptid's name and associated scene
@export var name: String
@export var scene: PackedScene
@export var icon: Texture2D
@export var deck: Array[Card]
@export var selected_cards: Array[Card]
@export var completed_turn: bool
@export var currently_selected: bool

# Declare main stat variables
@export var strength: int = 10
@export var knowledge: int = 10
@export var willpower: int = 10
@export var dexterity: int = 10
@export var vigor: int = 10

# Declare lesser stat variables, which are derived from the main stats
var health: int = 10
var speed: int
var max_hand_size: int

# Declare a variable for the level of the cryptid
@export var level: int = 1

# Function to calculate ability score from a base stat
func get_ability_score(stat: int) -> int:
	return (stat - 10) / 2

# Function to calculate derived stats based on the main stats
func calculate_stats():
	# Calculate ability scores from main stats
	var strength_score = get_ability_score(strength)
	var knowledge_score = get_ability_score(knowledge)
	var willpower_score = get_ability_score(willpower)
	var dexterity_score = get_ability_score(dexterity)
	var vigor_score = get_ability_score(vigor)
	
	# Calculate health based on vigor ability score and level
	health = (10 + vigor_score) * level
	
	# Speed is determined directly by the dexterity score
	speed = dexterity_score
	
	# Maximum hand size is determined directly by the knowledge score
	max_hand_size = knowledge_score
	
	# Return the calculated values as a dictionary for easy access
	return {
		"health": health,
		"speed": speed,
		"max_hand_size": max_hand_size,
		"strength_score": strength_score,
		"willpower_score": willpower_score,
		"dexterity_score": dexterity_score,
		"vigor_score": vigor_score
	}

# Function to update stats (call this whenever main stats or level changes)
func update_stats():
	var stats = calculate_stats()
	health = stats["health"]
	speed = stats["speed"]
	max_hand_size = stats["max_hand_size"]

# Initialize derived stats on creation
func _ready():
	update_stats()
