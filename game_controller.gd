class_name GameController
extends Node2D

@onready var action_selection_menu = %ActionSelectMenu  # Fixed node reference syntax

@onready var game_instructions = %GameInstructions

@onready var pick_card_button = %PickCardButton
@onready var swap_button = %SwapButton
@onready var rest_button = %RestButton
@onready var catch_button = %CatchButton
@onready var confirm_card_button = %ConfirmCardButton
@onready var hand = %Hand
@onready var turn_order = %"Turn Order"
@onready var tile_map_layer = %TileMapLayer
@onready var selected_cards = %SelectedCards


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
	print(selected_cards, "herrro")
	
func _process(_delta):
	if hand.highlighted_cards.size() == 2:
		confirm_card_button.text = "Confirm Cards"
	else:
		confirm_card_button.text = "Pick 2 Cards"

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
	print("start player turn")
	action_selection_menu.prompt_player_for_action()
	
	# Connect to the menu's signal if not already connected
	if not action_selection_menu.is_connected("action_selected", Callable(self, "_on_action_selected")):
		action_selection_menu.connect("action_selected", Callable(self, "_on_action_selected"))

# Function to start the enemy turn (you can expand this)
func start_enemy_turn():
	print("Enemy turn starts")

# Function to handle the selected action from the ActionSelectionMenu
func _on_action_selected(action_type: int):
	match action_type:
		action_selection_menu.ActionType.PICK_CARDS:
			prompt_pick_cards()
		action_selection_menu.ActionType.SWAP:
			prompt_swap_cryptid()
		action_selection_menu.ActionType.REST:
			perform_rest()
		action_selection_menu.ActionType.CATCH:
			prompt_catch_cryptid()
		action_selection_menu.ActionType.CARDS_PICKED:
			cards_picked()
		action_selection_menu.ActionType.BATTLE_PHASE:
			battle_phase()

# Functions to handle each action
func prompt_pick_cards():
	print("Prompting player to pick cards")
	game_instructions.text = "Prompting player to pick cards"
	pick_card_button.text = "Pick Two Cards"
	swap_button.hide()
	rest_button.hide()
	catch_button.hide()
	pick_card_button.hide()
	confirm_card_button.show()
	action_selection_menu.show()
	
	

func prompt_swap_cryptid():
	print("Prompting player to swap cryptid")
	game_instructions.text = "Prompting player to swap cryptid"

func perform_rest():
	print("Player is resting")
	game_instructions.text = "Player is resting"

func prompt_catch_cryptid():
	print("Prompting player to catch a cryptid")
	game_instructions.text = "Prompting player to catch a cryptid"

func cards_picked():
	hand.cards_selected(hand.highlighted_cards)
	for card in hand.highlighted_cards:
		card.queue_free()
		hand.hand.erase(card)
		hand.selected_cryptid.deck.erase(card)
		print(hand.selected_cryptid.deck)
		print(card)
	turn_order._add_picked_cards_to_turn_order(hand.highlighted_cards[0], hand.highlighted_cards[1])
	hand.highlighted_cards.clear()
	hand.reposition_cards()
	hand.selected_cryptid.completed_turn = true
	swap_button.show()
	rest_button.show()
	catch_button.show()
	pick_card_button.show()
	confirm_card_button.hide()
	action_selection_menu.hide()
	start_player_turn()
	
func battle_phase():
	hand.hide()
	action_selection_menu.hide()
	selected_cards.show()
	
