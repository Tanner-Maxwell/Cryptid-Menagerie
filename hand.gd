extends Control

@export var hand_radius: int = 100
@export var card_angle: float = -90
@export var angle_limit: float = 25
@export var max_card_spread_angle: float = 5
@export var current_highlighted_container = null

var current_highlighted_card: CardDialog = null

@onready var card_dialog = preload("res://Cryptid-Menagerie/data/cryptids/Cards/card_dialog.tscn")

var hand: Array = []
var highlighted_cards: Array = []
var max_highlighted_cards = 2

func add_card(card):
	hand.push_back(card)
	add_child(card)
	reposition_cards()

func reposition_cards():
	var card_spread = min(angle_limit / hand.size(), max_card_spread_angle)
	var current_angle = -(card_spread * (hand.size()- 1))/2 - 90
	for card in hand:
		card_transform_update(card, current_angle)
		current_angle += card_spread
		pass

func get_card_position(angle: float) -> Vector2:
	var x: float = hand_radius * cos(deg_to_rad(angle))
	var y: float = hand_radius * sin(deg_to_rad(angle))
	
	return Vector2(x, y)

func card_transform_update(card, angle_in_drag: float):
	card.set_position(get_card_position(angle_in_drag))
	card.set_rotation(deg_to_rad(angle_in_drag + 90))

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Function to highlight the selected card
func highlight_card(new_card: CardDialog):
	## Unhighlight the currently highlighted card if it's not the same as the new one
	#print(new_card)
	#print(current_highlighted_card)
	#if current_highlighted_card != new_card:
		#unhighlight_card()
#
	## Highlight the new car
	#print("WHAT THE")
	#current_highlighted_card = new_card
	#current_highlighted_card.highlight()
	
	# If the card is already highlighted, do nothing
	# If the card is already highlighted, do nothing
	if new_card in highlighted_cards:
		unhighlight_card(new_card)
		return

	# If two cards are already highlighted, don't allow selecting a third
	if highlighted_cards.size() < max_highlighted_cards:
		highlighted_cards.append(new_card)
		new_card.highlight()

# Function to unhighlight the current card
func unhighlight_card(card: CardDialog):
	#if current_highlighted_card:
		#print("we unhighlighting boys")
		#current_highlighted_card.unhighlight()
		#current_highlighted_card = null
	if card in highlighted_cards:
		highlighted_cards.erase(card)
		card.unhighlight()

# Ensure no more than two cards are highlighted
func can_highlight_more() -> bool:
	return highlighted_cards.size() < max_highlighted_cards

func _on_button_pressed():
	var base_card = card_dialog.instantiate()
	base_card.card_resource = preload("res://Cryptid-Menagerie/data/cryptids/Moves/test_card.tres")
	add_card(base_card)
	print("card added: ", base_card)
