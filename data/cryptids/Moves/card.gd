class_name Card
extends Resource

@export var top_move:Move
@export var bottom_move:Move

@export var base_attack_top:Action
@export var base_move_bottom:Action

enum CardState {
	IN_DECK,
	IN_DISCARD,
	IN_HAND
}

# Default state is in deck
var current_state: CardState = CardState.IN_DECK

# Reference to the original card in the deck
var original_card = null
