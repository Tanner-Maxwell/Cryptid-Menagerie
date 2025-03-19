extends Control

# Signal to notify the selected action type
signal action_selected(action_type: int)

# Enum for the action types
enum ActionType { SWAP, REST, CATCH, BATTLE_PHASE, END_TURN }

@onready var hand = %Hand
@onready var tile_map_layer = %TileMapLayer

# Direct references to buttons for more reliable access
@onready var swap_button = $VBoxContainer/SwapButton
@onready var rest_button = $VBoxContainer/RestButton
@onready var catch_button = $VBoxContainer/CatchButton
@onready var end_turn_button = $VBoxContainer/EndTurnButton
@onready var done_moving_button = $VBoxContainer/DoneMoving

func _ready():
	# Print button references to verify we have the correct paths
	print("Button references in action_select_menu:")
	print("  swap_button =", swap_button != null)
	print("  rest_button =", rest_button != null)
	print("  catch_button =", catch_button != null)
	print("  end_turn_button =", end_turn_button != null)
	
	# Connecting button signals to the respective functions
	$VBoxContainer/SwapButton.connect("pressed", Callable(self, "_on_swap_pressed"))
	$VBoxContainer/RestButton.connect("pressed", Callable(self, "_on_rest_pressed"))
	$VBoxContainer/CatchButton.connect("pressed", Callable(self, "_on_catch_pressed"))
	$VBoxContainer/EndTurnButton.connect("pressed", Callable(self, "_on_end_turn_pressed"))
	$VBoxContainer/DoneMoving.connect("pressed", Callable(self, "_on_done_moving_pressed"))

func update_menu_visibility(cryptid: Cryptid):
	if cryptid == null:
		print("ERROR: Null cryptid passed to update_menu_visibility")
		return
		
	print("Updating menu for cryptid: ", cryptid.name)
	print("top_card_played: ", cryptid.top_card_played, ", bottom_card_played: ", cryptid.bottom_card_played)
	
	# Show/hide the DoneMoving button based on active movement
	if tile_map_layer.move_action_bool and tile_map_layer.move_leftover > 0:
		$VBoxContainer/DoneMoving.show()
	else:
		$VBoxContainer/DoneMoving.hide()
	
	# Check if the cryptid has used a card action this turn
	if cryptid.top_card_played or cryptid.bottom_card_played:
		print("Card action used - hiding action buttons, showing only End Turn")
		$VBoxContainer/SwapButton.hide()
		$VBoxContainer/RestButton.hide()
		$VBoxContainer/CatchButton.hide()
		$VBoxContainer/EndTurnButton.show()
	elif !tile_map_layer.move_action_bool:
		print("No card action used - showing all action buttons")
		$VBoxContainer/SwapButton.show()
		$VBoxContainer/RestButton.show()
		$VBoxContainer/CatchButton.show()
		$VBoxContainer/EndTurnButton.show()

# Function to display the action selection menu
func prompt_player_for_action():
	print("MENU: prompt_player_for_action called")
	
	# Ensure we're visible first
	show()
	
	# Update button visibility based on current cryptid
	var selected_cryptid = null
	if hand and hand.has_method("switch_cryptid_deck"):
		selected_cryptid = hand.selected_cryptid
		if selected_cryptid:
			update_menu_visibility(selected_cryptid)
		else:
			print("ERROR: No selected_cryptid found in hand!")
	else:
		print("ERROR: hand reference invalid or missing switch_cryptid_deck method!")

# Function to explicitly force-update the menu state
func force_update():
	if hand and hand.selected_cryptid:
		update_menu_visibility(hand.selected_cryptid)
	
# Functions for each action button
func _on_swap_pressed():
	hide()
	emit_signal("action_selected", ActionType.SWAP)

func _on_rest_pressed():
	hide()
	emit_signal("action_selected", ActionType.REST)

func _on_catch_pressed():
	hide()
	emit_signal("action_selected", ActionType.CATCH)

func _on_end_turn_pressed():
	hide()
	emit_signal("action_selected", ActionType.END_TURN)

# Called when all player cryptids have completed their turns
func trigger_battle_phase():
	emit_signal("action_selected", ActionType.BATTLE_PHASE)


func _on_DoneMoving_pressed():
	# Get the tile map controller
	var tile_map_layer = get_tree().get_nodes_in_group("map")[0]
	hide()
	# Call the finish_movement function
	tile_map_layer.finish_movement()
