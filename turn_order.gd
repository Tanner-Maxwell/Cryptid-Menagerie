extends VBoxContainer

@onready var tile_map_layer = %TileMapLayer
@onready var turn_order_card_ui = preload("res://cryptids_cards_turn_order.tscn")
@onready var card_dialog = preload("res://Cryptid-Menagerie/data/cryptids/Cards/card_dialog.tscn")

var picked_cards: Array = []
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	
func _add_picked_cards_to_turn_order(card_one, card_two):
	print(card_one, card_two)
	var picked_card_ui = turn_order_card_ui.instantiate()
	var card_one_ui = card_dialog.instantiate()
	var card_two_ui = card_dialog.instantiate()
	card_one_ui.card_resource = card_one.card_resource
	card_two_ui.card_resource = card_two.card_resource
	add_child(picked_card_ui)
	
	picked_card_ui.add_child(card_one_ui)
	picked_card_ui.add_child(card_two_ui)
	picked_cards.push_back(card_one_ui)
	picked_cards.push_back(card_two_ui)
