extends Control

@onready var hand = %Hand
@onready var tile_map_layer = %TileMapLayer
@onready var card_container = %CardContainer


@onready var selected_cryptid
@onready var card_dialog = preload("res://Cryptid-Menagerie/data/cryptids/Cards/card_dialog.tscn")

var highlighted_cards: Array = []
var max_highlighted_cards = 2


# Called when the node enters the scene tree for the first time.
func switch_cryptid_selected_cards(cryptid: Cryptid):
	selected_cryptid = cryptid
	highlighted_cards.clear()
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
