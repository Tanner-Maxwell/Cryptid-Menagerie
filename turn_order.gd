extends VBoxContainer

@onready var tile_map_layer = %TileMapLayer
@onready var turn_order_card_ui = preload("res://cryptids_cards_turn_order.tscn")
@onready var card_dialog = preload("res://Cryptid-Menagerie/data/cryptids/Cards/card_dialog.tscn")
@onready var cryptid_name_label = Label.new()
@onready var picked_card_ui

var picked_cards: Array = []
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	
func _add_picked_cards_to_turn_order(cryptid_name):
	#picked_card_ui = turn_order_card_ui.instantiate()
	cryptid_name_label = Label.new()
	cryptid_name_label.text = cryptid_name
	var label_setting = LabelSettings.new()
	label_setting.font_size = 34
	
	cryptid_name_label.label_settings = label_setting
	add_child(cryptid_name_label)
	add_child(picked_card_ui)
