extends Control

@export var hand_radius: int = 100
@export var card_angle: float = 0
@export var angle_limit: float = 25
@export var highlight_offset: float = 15
@export var max_card_spread_angle: float = 5
@export var current_highlighted_container = null
@onready var tile_map_layer = %TileMapLayer
@onready var cryptids_cards = %"Cryptids Cards"
@onready var selected_cards_node = %SelectedCards

@onready var selected_cryptid

var current_highlighted_card: CardDialog = null

@onready var card_dialog = preload("res://Cryptid-Menagerie/data/cryptids/Cards/card_dialog.tscn")

var hand: Array = []
var highlighted_cards: Array = []
var max_highlighted_cards = 2


func _ready():
	selected_cryptid = tile_map_layer.player_cryptids_in_play[0].cryptid
	switch_cryptid_deck(selected_cryptid)

func add_card(card):
	hand.push_back(card)
	add_child(card)
	reposition_cards()

func remove_card(card):
	hand.erase(card)

func reposition_cards():
	var card_spread = min(angle_limit / hand.size(), max_card_spread_angle)
	var current_angle = 0
	if hand.size() > 1:	
		current_angle = -(card_spread * (hand.size()-1))/2 - 92
	else:
		current_angle = -(card_spread * (hand.size()-1))/2 - 90
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
	if card in highlighted_cards:
		card.position.y -= highlight_offset

# Function to highlight the selected card
func highlight_card(new_card: CardDialog):
	if new_card in highlighted_cards:
		unhighlight_card(new_card)
		return

	# If two cards are already highlighted, don't allow selecting a third
	if highlighted_cards.size() < max_highlighted_cards:
		highlighted_cards.append(new_card)
		new_card.highlight()
		new_card.position.y -= highlight_offset
		new_card.z_index += 1

# Function to unhighlight the current card
func unhighlight_card(card: CardDialog):
	if card in highlighted_cards:
		highlighted_cards.erase(card)
		card.unhighlight()
		card.position.y += highlight_offset
		card.z_index -= 1

# Ensure no more than two cards are highlighted
func can_highlight_more() -> bool:
	return highlighted_cards.size() < max_highlighted_cards
	
func cards_selected(selected_cards: Array):
	for cards_picked in selected_cards:
		selected_cryptid.deck.erase(cards_picked.card_resource)
		selected_cryptid.selected_cards.push_back(cards_picked.card_resource)
	return selected_cryptid

func switch_cryptid_deck(cryptid: Cryptid):
	hand.clear()
	highlighted_cards.clear()
	for child in self.get_children():
		remove_child(child)
	var base_card
	for card_resource in cryptid.deck:
		base_card = card_dialog.instantiate()
		base_card.card_resource = card_resource
		add_card(base_card)
	selected_cryptid.currently_selected = false
	selected_cryptid = cryptid
		
func switch_cryptid_selected_cards(cryptid: Cryptid):
	selected_cryptid = cryptid
	highlighted_cards.clear()
	for child in selected_cards_node.get_children():
		selected_cards_node.remove_child(child)
	var base_card
	for card_resource in cryptid.selected_cards:
		base_card = card_dialog.instantiate()
		base_card.card_resource = card_resource
		selected_cards_node.add_child(base_card)
	selected_cryptid.currently_selected = false
	selected_cryptid = cryptid

func _on_button_pressed():
	var base_card = card_dialog.instantiate()
	base_card.card_resource = preload("res://Cryptid-Menagerie/data/cryptids/Moves/test_card.tres")
	add_card(base_card)
	selected_cryptid.deck.push_back(base_card.card_resource)
