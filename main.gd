extends Node2D

@onready var game_controller = get_node("/root/VitaChrome/TileMapLayer/GameController")


var enemy_character_state: int = 0

func _ready():
	# Set default battle type (wild battle where catching is allowed)
	game_controller.is_trainer_battle = false

# Function to set up a wild battle (catchable cryptids)
func set_wild_battle():
	game_controller.is_trainer_battle = false
	var game_instructions = get_node("/root/VitaChrome/UIRoot/GameInstructions")
	if game_instructions:
		game_instructions.text = "A wild battle has started! You can catch the last enemy cryptid."
	print("Battle configured as a wild battle (catching allowed)")

# Function to set up a trainer battle (catching not allowed)
func set_trainer_battle(trainer_name = "Trainer"):
	game_controller.is_trainer_battle = true
	var game_instructions = get_node("/root/VitaChrome/UIRoot/GameInstructions")
	if game_instructions:
		game_instructions.text = trainer_name + " has challenged you to a battle!"
	print("Battle configured as a trainer battle (catching not allowed)")
