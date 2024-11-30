extends Control

# Signal to notify the selected action type
signal action_selected(action_type: int)

# Enum for the action types
enum ActionType { PICK_CARDS, SWAP, REST, CATCH, CARDS_PICKED, BATTLE_PHASE }

@onready var hand = %Hand
@onready var tile_map_layer = %TileMapLayer


func _ready():
	# Connecting button signals to the respective functions
	$VBoxContainer/PickCardButton.connect("pressed", Callable(self, "_on_pick_cards_pressed"))
	$VBoxContainer/SwapButton.connect("pressed", Callable(self, "_on_swap_pressed"))
	$VBoxContainer/RestButton.connect("pressed", Callable(self, "_on_rest_pressed"))
	$VBoxContainer/CatchButton.connect("pressed", Callable(self, "_on_catch_pressed"))
	%ConfirmCardButton.connect("pressed", Callable(self, "_on_confirm_card_pressed"))

# Function to display the action selection menu
func prompt_player_for_action():
	self.visible = true

# Functions for each action button
func _on_pick_cards_pressed():
	self.visible = false
	emit_signal("action_selected", ActionType.PICK_CARDS)
	print("pick cards pressed")

func _on_swap_pressed():
	self.visible = false
	emit_signal("action_selected", ActionType.SWAP)

func _on_rest_pressed():
	self.visible = false
	emit_signal("action_selected", ActionType.REST)

func _on_catch_pressed():
	self.visible = false
	emit_signal("action_selected", ActionType.CATCH)

func _on_confirm_card_pressed():
	if hand.highlighted_cards.size() == 2 and hand.selected_cryptid.completed_turn == false:
		emit_signal("action_selected", ActionType.CARDS_PICKED)
		if tile_map_layer.any_cryptid_not_completed():
			emit_signal("action_selected", ActionType.BATTLE_PHASE)
	
	
