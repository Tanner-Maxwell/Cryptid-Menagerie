extends Control

@onready var hand = %Hand
@onready var tile_map_layer = %TileMapLayer
@onready var card_container = %SelectedCards


@onready var selected_cryptid
@onready var card_dialog = preload("res://Cryptid-Menagerie/data/cryptids/Cards/card_dialog.tscn")

var highlighted_selected_top_bottom: Array = []
var max_highlighted_cards = 2


func highlight_card(new_card: CardDialog):
	if new_card in highlighted_selected_top_bottom:
		unhighlight_card(new_card)
		return

	# If two cards are already highlighted, don't allow selecting a third
	if highlighted_selected_top_bottom.size() < max_highlighted_cards:
		highlighted_selected_top_bottom.append(new_card)
		new_card.highlight()
		new_card.z_index += 1

# Function to unhighlight the current card
func unhighlight_card(card: CardDialog):
	if card in highlighted_selected_top_bottom:
		highlighted_selected_top_bottom.erase(card)
		card.unhighlight()
		card.z_index -= 1

# Ensure no more than two cards are highlighted
func can_highlight_more() -> bool:
	return highlighted_selected_top_bottom.size() < max_highlighted_cards


# Called when the node enters the scene tree for the first time.
func switch_cryptid_selected_cards(cryptid: Cryptid):
	selected_cryptid = cryptid
	for child in self.get_children():
		remove_child(child)
	var base_card
	for card_resource in cryptid.selected_cards:
		base_card = card_dialog.instantiate()
		base_card.card_resource = card_resource
		print(base_card)
		card_container.add_child(base_card)
	selected_cryptid.currently_selected = false
	selected_cryptid = cryptid

