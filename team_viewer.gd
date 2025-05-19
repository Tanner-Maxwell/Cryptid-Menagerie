extends PanelContainer

@onready var grid_container = $MarginContainer/VBoxContainer/GridContainer
@onready var close_button = $MarginContainer/VBoxContainer/HBoxContainer/CloseButton
@onready var close_button2 = $MarginContainer/VBoxContainer/CloseButton2

# We'll need the SwapCryptidSlot scene for displaying cryptids
@export var cryptid_slot_scene: PackedScene

signal closed

func _ready():
	# Connect close buttons
	close_button.pressed.connect(_on_close_pressed)
	close_button2.pressed.connect(_on_close_pressed)
	
	# Hide initially
	hide()
	
	# Make sure this appears on top of other UI
	z_index = 100

func open():
	# Clear any existing slots
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()
	
	# Get player team from GameState
	if GameState.player_team:
		var all_cryptids = []
		
		# Get cryptids
		if GameState.player_team.has_method("get_cryptids"):
			all_cryptids = GameState.player_team.get_cryptids()
		elif "_content" in GameState.player_team:
			all_cryptids = GameState.player_team._content
			
		print("Team Viewer: Found", all_cryptids.size(), "cryptids")
		
		# Create a slot for each cryptid
		for cryptid in all_cryptids:
			if cryptid == null:
				continue
				
			var slot = create_cryptid_slot(cryptid)
			if slot:
				grid_container.add_child(slot)
	
	# Show the dialog
	show()

func create_cryptid_slot(cryptid):
	# If we have the SwapCryptidSlot scene, use it
	if cryptid_slot_scene:
		var slot = cryptid_slot_scene.instantiate()
		
		# Check if the slot has a setup method
		if slot.has_method("setup"):
			# Find if this cryptid is currently in play
			var is_in_play = false
			var tile_map_layer = get_node_or_null("/root/VitaChrome/TileMapLayer")
			if tile_map_layer:
				for cryptid_node in tile_map_layer.player_cryptids_in_play:
					if cryptid_node.cryptid == cryptid:
						is_in_play = true
						break
			
			# Setup the slot
			slot.setup(cryptid, is_in_play)
			return slot
	
	# If slot scene isn't specified or instantiation failed, create a basic version
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 160)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	# Add basic info
	var name_label = Label.new()
	name_label.text = cryptid.name
	vbox.add_child(name_label)
	
	# Add health info if available
	var health_text = "HP: "
	if cryptid.has_meta("current_health"):
		health_text += str(cryptid.get_meta("current_health"))
	else:
		health_text += str(cryptid.health)
	health_text += "/" + str(cryptid.health)
	
	var health_label = Label.new()
	health_label.text = health_text
	vbox.add_child(health_label)
	
	# Also display deck/discard count if available
	var deck_count = 0
	var discard_count = 0
	
	if cryptid.deck:
		for card in cryptid.deck:
			if card.current_state == Card.CardState.IN_DECK:
				deck_count += 1
			elif card.current_state == Card.CardState.IN_DISCARD:
				discard_count += 1
	
	var cards_label = Label.new()
	cards_label.text = "Deck: " + str(deck_count) + " / Discard: " + str(discard_count)
	vbox.add_child(cards_label)
	print("testing 1... 2...")
	return panel

func _on_close_pressed():
	hide()
	emit_signal("closed")
