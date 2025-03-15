extends VBoxContainer

@onready var tile_map_layer = %TileMapLayer
@onready var turn_order_card_ui = preload("res://cryptids_cards_turn_order.tscn")
@onready var card_dialog = preload("res://Cryptid-Menagerie/data/cryptids/Cards/card_dialog.tscn")
@onready var cryptid_name_labels = {}  # Dictionary to track labels by cryptid name
@onready var picked_card_ui

var picked_cards: Array = []

# Called when the node enters the scene tree for the first time.
func _ready():
	# Initialize the labels for all cryptids in play
	initialize_cryptid_labels()

func initialize_cryptid_labels():
	# Clear existing labels
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	cryptid_name_labels.clear()
	
	# Create labels for all cryptids in play
	for cryptid_in_play in tile_map_layer.all_cryptids_in_play:
		var cryptid_name = cryptid_in_play.cryptid.name
		var cryptid_name_label = Label.new()
		cryptid_name_label.text = cryptid_name
		
		var label_setting = LabelSettings.new()
		label_setting.font_size = 34
		cryptid_name_label.label_settings = label_setting
		
		add_child(cryptid_name_label)
		
		# Store the label reference using the cryptid object as key
		# This avoids issues with string name mismatches
		cryptid_name_labels[cryptid_in_play] = cryptid_name_label
	
func _add_picked_cards_to_turn_order(cryptid_name):
	# This function is likely being called from elsewhere, but we're using 
	# initialize_cryptid_labels now, so we can just print for debugging
	print("_add_picked_cards_to_turn_order called with: ", cryptid_name)

# Call this function in _process to update label colors based on turn completion
func _process(delta):
	update_label_colors()

# Update label colors based on cryptid turn completion status
func update_label_colors():
	for cryptid_in_play in tile_map_layer.all_cryptids_in_play:
		if cryptid_in_play in cryptid_name_labels:
			var label = cryptid_name_labels[cryptid_in_play]
			
			# Check if the cryptid has completed their turn
			if cryptid_in_play.cryptid.completed_turn:
				# Create a red label settings if needed
				if label.label_settings.font_color != Color(1, 0, 0, 1):
					var red_setting = label.label_settings.duplicate()
					red_setting.font_color = Color(1, 0, 0, 1)  # Red color
					label.label_settings = red_setting
			else:
				# Create a white label settings if needed
				if label.label_settings.font_color != Color(1, 1, 1, 1):
					var white_setting = label.label_settings.duplicate()
					white_setting.font_color = Color(1, 1, 1, 1)  # White color
					label.label_settings = white_setting
