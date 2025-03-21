class_name GameController
extends Node2D

@onready var action_selection_menu = %ActionSelectMenu
@onready var game_instructions = %GameInstructions
@onready var swap_button = %SwapButton
@onready var rest_button = %RestButton
@onready var catch_button = %CatchButton
@onready var hand = %Hand
@onready var turn_order = %"Turn Order"
@onready var tile_map_layer = %TileMapLayer
@onready var discarded_cards = %DiscardCards
@onready var enemy_ai_controller = $EnemyAIController


enum GameState {
	PLAYER_TURN,
	ENEMY_TURN,
	GAMEOVER,
	VICTORY
}

@onready var current_state: GameState = GameState.PLAYER_TURN

func _ready():
	# Start with the player's turn when the game begins
	transition(GameState.PLAYER_TURN)

func transition(next_state: GameState):
	match current_state:
		GameState.PLAYER_TURN:
			start_player_turn()
		GameState.ENEMY_TURN:
			start_enemy_turn()
		# Handle other states (GAMEOVER, VICTORY)
	
	current_state = next_state

# Function that starts the player's turn
func start_player_turn():
	# Display the action selection menu
	action_selection_menu.prompt_player_for_action()
	# Connect to the menu's signal if not already connected
	if not action_selection_menu.is_connected("action_selected", Callable(self, "_on_action_selected")):
		action_selection_menu.connect("action_selected", Callable(self, "_on_action_selected"))

# Function to start the enemy turn
func start_enemy_turn():
	pass

# Function to handle the selected action from the ActionSelectionMenu
func _on_action_selected(action_type: int):
	match action_type:
		action_selection_menu.ActionType.SWAP:
			prompt_swap_cryptid()
		action_selection_menu.ActionType.REST:
			perform_rest()
		action_selection_menu.ActionType.CATCH:
			prompt_catch_cryptid()
		action_selection_menu.ActionType.END_TURN:
			end_current_turn()
		action_selection_menu.ActionType.BATTLE_PHASE:
			battle_phase()

# Functions to handle each action
func prompt_swap_cryptid():
	print("Prompting player to swap cryptid")
	game_instructions.text = "Select a cryptid to swap to"

func perform_rest():
	print("Player is resting")
	game_instructions.text = "Player is resting"
	
	# Mark current cryptid's turn as completed
	if hand.selected_cryptid:
		hand.selected_cryptid.completed_turn = true
		
	# Check if all cryptids have completed their turns
	if not tile_map_layer.any_cryptid_not_completed():
		battle_phase()
	else:
		# Move to the next cryptid's turn
		hand.next_cryptid_turn()
		action_selection_menu.prompt_player_for_action()

func prompt_catch_cryptid():
	print("Prompting player to catch a cryptid")
	game_instructions.text = "Select a cryptid to catch"
	
func end_current_turn():
	print("Ending current cryptid's turn")
	game_instructions.text = "Turn ended"
	
	# Mark current cryptid's turn as completed
	if hand.selected_cryptid:
		hand.selected_cryptid.completed_turn = true
		hand.selected_cryptid.currently_selected = false
	
	# Check if all cryptids have completed their turns
	if not tile_map_layer.any_cryptid_not_completed():
		battle_phase()
	else:
		# Move to the next cryptid's turn
		hand.next_cryptid_turn()
		
		# Update the UI to show the new selected cryptid's hand
		if hand.selected_cryptid:
			hand.switch_cryptid_deck(hand.selected_cryptid)
			game_instructions.text = "Now controlling: " + hand.selected_cryptid.name
		
		# Show the action menu for the next cryptid
		action_selection_menu.prompt_player_for_action()

func battle_phase():
	print("Entering battle phase")
	game_instructions.text = "Battle phase"
	
	action_selection_menu.hide()
	discarded_cards.show()
	
	# Check if all player cryptids have completed their turns
	var all_completed = true
	for cryptid in tile_map_layer.all_cryptids_in_play:
		if cryptid.cryptid.completed_turn == false:
			all_completed = false
			break
	
	if all_completed:
		# Enemy turn logic would go here
		# ...
		
		# After enemy turn, reset all turns and start a new round
		reset_all_cryptid_turns()
		transition(GameState.PLAYER_TURN)
		hand.show()
	
func reset_all_cryptid_turns():
	for cryptid_in_play in tile_map_layer.all_cryptids_in_play:
		cryptid_in_play.cryptid.completed_turn = false
		cryptid_in_play.cryptid.top_card_played = false
		cryptid_in_play.cryptid.bottom_card_played = false
