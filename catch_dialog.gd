extends PanelContainer

signal cryptid_selected(cryptid, new_cryptid)

@onready var grid_container = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var close_button = $MarginContainer/VBoxContainer/CloseButton
@onready var caught_cryptid_display = %CaughtCryptidDisplay

var caught_cryptid = null

func _ready():
	hide()  # Start hidden
	close_button.connect("pressed", Callable(self, "_on_close_button_pressed"))
	print("CatchDialog initialized and ready")

func open(team: Team, new_cryptid: Cryptid, cryptids_in_play: Array):
	print("DIALOG: open() called")
	print("DIALOG: Team size:", team.get_cryptids().size() if team.has_method("get_cryptids") else "unknown")
	print("DIALOG: New cryptid:", new_cryptid.name)
	
	# Set the caught cryptid
	caught_cryptid = new_cryptid
	
	# Update title
	title_label.text = "Your team is full! Choose a cryptid to replace:"
	
	# Display the caught cryptid info
	update_caught_cryptid_display(new_cryptid)
	
	# Check grid_container
	if not grid_container:
		print("ERROR: grid_container is null! Trying to find it manually.")
		grid_container = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/GridContainer")
		
		if not grid_container:
			print("CRITICAL ERROR: Could not find GridContainer! Dialog will not show cryptids.")
			return
		else:
			print("Found grid_container manually:", grid_container)
	
	# Clear existing slots
	print("DIALOG: Clearing existing slots")
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()
	
	# Get all cryptids in the team
	print("DIALOG: Getting cryptids from team")
	var all_cryptids = []
	
	# Try different methods to get cryptids
	if team.has_method("get_cryptids"):
		print("DIALOG: Using get_cryptids() - found", team.get_cryptids().size(), "cryptids")
		all_cryptids = team.get_cryptids()
	elif team.has_property("_content"):
		print("DIALOG: Accessing _content property - found", team._content.size(), "cryptids")
		all_cryptids = team._content
	elif team is Node and team.has_node("cryptidTeam"):
		print("DIALOG: Accessing cryptidTeam node")
		all_cryptids = team.get_node("cryptidTeam").get_cryptids()
	else:
		print("ERROR: Could not get cryptids from team object:", team)
	
	print("DIALOG: Retrieved", all_cryptids.size(), "cryptids from team")
	
	# Create a slot for each cryptid in the team
	for i in range(all_cryptids.size()):
		var cryptid = all_cryptids[i]
		
		if not cryptid:
			print("ERROR: Null cryptid at index", i)
			continue
			
		print("DIALOG: Processing cryptid:", cryptid.name)
		
		# Check if this cryptid is currently in battle
		var in_play = false
		for played_cryptid in cryptids_in_play:
			if played_cryptid.cryptid == cryptid:
				in_play = true
				print("DIALOG: Cryptid", cryptid.name, "is in play")
				break
		
		# Create a slot for this cryptid
		print("DIALOG: Creating slot for", cryptid.name)
		var slot = create_slot(cryptid, in_play)
		
		if slot:
			print("DIALOG: Adding slot to grid")
			grid_container.add_child(slot)
		else:
			print("ERROR: Failed to create slot for", cryptid.name)
	
	# Show the dialog
	print("DIALOG: Showing dialog")
	show()
	print("DIALOG: Dialog should be visible now")

func update_caught_cryptid_display(cryptid: Cryptid):
	# Create a display panel for the caught cryptid
	caught_cryptid_display.clear_display()
	
	# Set the title
	caught_cryptid_display.set_title("Newly Caught Cryptid:")
	
	# Add cryptid info
	caught_cryptid_display.set_cryptid(cryptid)
	
	# Make sure it's visible
	caught_cryptid_display.show()

func create_slot(cryptid: Cryptid, in_play: bool) -> PanelContainer:
	print("DIALOG: create_slot for", cryptid.name)
	
	# Create the panel container
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(180, 160)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Create the margin container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	slot.add_child(margin)
	
	# Create the main vertical container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# Create center container for icon
	var center = CenterContainer.new()
	vbox.add_child(center)
	
	# Create icon
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(80, 80)
	icon_rect.expand_mode = 3  # EXPAND_FIT_WIDTH_PROPORTIONAL = 3
	icon_rect.stretch_mode = 5  # STRETCH_KEEP_ASPECT_CENTERED = 5
	if cryptid.icon:
		icon_rect.texture = cryptid.icon
	center.add_child(icon_rect)
	
	# Create name label
	var name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.text = cryptid.name
	name_label.horizontal_alignment = 1  # CENTER = 1
	vbox.add_child(name_label)
	
	# Add separator
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Create health label - getting the correct stored health
	var health_label = Label.new()
	var current_health = cryptid.health  # Default to max health
	var max_health = cryptid.health
	
	# Check for stored health
	if cryptid.has_meta("current_health") and cryptid.get_meta("current_health") > 0:
		current_health = cryptid.get_meta("current_health")
	elif cryptid.get("current_health") != null and cryptid.current_health > 0:
		current_health = cryptid.current_health
	
	health_label.text = "HP: " + str(current_health) + "/" + str(max_health)
	
	# Color the health text based on percentage
	var health_percentage = float(current_health) / max_health
	if health_percentage < 0.25:
		health_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))  # Red for low health
	elif health_percentage < 0.5:
		health_label.add_theme_color_override("font_color", Color(1, 0.5, 0, 1))  # Orange for medium health
	
	vbox.add_child(health_label)
	
	# Create cards label
	var cards_label = Label.new()
	var in_deck = 0
	var in_discard = 0
	
	for card in cryptid.deck:
		if card.current_state == Card.CardState.IN_DECK:
			in_deck += 1
		elif card.current_state == Card.CardState.IN_DISCARD:
			in_discard += 1
	
	cards_label.text = "Deck: " + str(in_deck) + " / Discard: " + str(in_discard)
	vbox.add_child(cards_label)
	
	# Give the slot a background color so it's clearly visible
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	slot.add_theme_stylebox_override("panel", style_box)
	
	# Modified: Allow selection of in-play cryptids
	if in_play:
		# Add an "IN BATTLE" indicator but still allow selection
		var in_battle_label = Label.new()
		in_battle_label.text = "IN BATTLE"
		in_battle_label.add_theme_font_size_override("font_size", 16)
		in_battle_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3, 1))  # Orange instead of red
		in_battle_label.horizontal_alignment = 1  # CENTER = 1
		
		# Position at top of card
		in_battle_label.set_anchors_preset(5)  # PRESET_CENTER_TOP = 5
		in_battle_label.position.y = 5
		
		slot.add_child(in_battle_label)
	
	# Make clickable and setup for signals (for all cryptids)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Store cryptid reference
	slot.set_meta("cryptid", cryptid)
	
	# Connect input event
	slot.gui_input.connect(_on_slot_gui_input.bind(slot, cryptid))
	
	return slot

# Handle slot input
func _on_slot_gui_input(event, slot, cryptid):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Selected cryptid to replace: " + cryptid.name)
		emit_signal("cryptid_selected", cryptid, caught_cryptid)
		hide()
		get_viewport().set_input_as_handled()

# Close button pressed
func _on_close_button_pressed():
	hide()
	
	# Since we're choosing not to replace a cryptid, we need to release the caught one
	var game_instructions = get_node("/root/VitaChrome/UIRoot/GameInstructions")
	if game_instructions:
		game_instructions.text = "You released " + caught_cryptid.name + "."
	
	# Reset the action menu
	var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_menu and action_menu.has_method("prompt_player_for_action"):
		action_menu.prompt_player_for_action()
