class_name SwapCryptidDialog
extends PanelContainer

signal cryptid_selected(cryptid)

@onready var grid_container = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var close_button = $MarginContainer/VBoxContainer/CloseButton

var current_cryptid = null

func _ready():
	hide()  # Start hidden
	close_button.connect("pressed", Callable(self, "_on_close_button_pressed"))
	print("SwapCryptidDialog initialized and ready")
	
	# Debug node paths
	print("Node paths:")
	print("  grid_container:", grid_container)
	print("  title_label:", title_label)
	print("  close_button:", close_button)

# Open the dialog with the team data and current cryptid
func open(team: Team, cryptid_to_swap: Cryptid, cryptids_in_play: Array):
	print("DIALOG: open() called")
	print("DIALOG: Team:", team)
	print("DIALOG: Swap cryptid:", cryptid_to_swap.name)
	print("DIALOG: Cryptids in play:", cryptids_in_play.size())
	
	# Set the current cryptid
	current_cryptid = cryptid_to_swap
	
	# Update title
	title_label.text = "Select Cryptid to Swap with " + cryptid_to_swap.name
	
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
		print("DIALOG: Using get_cryptids()")
		all_cryptids = team.get_cryptids()
	elif team.has_property("_content"):
		print("DIALOG: Accessing _content property")
		all_cryptids = team._content
	elif team is Node and team.has_node("cryptidTeam"):
		print("DIALOG: Accessing cryptidTeam node")
		all_cryptids = team.get_node("cryptidTeam").get_cryptids()
	else:
		print("ERROR: Could not get cryptids from team object:", team)
	
	# Debug the array of cryptids
	print("DIALOG: Found", all_cryptids.size(), "cryptids")
	for i in range(all_cryptids.size()):
		if all_cryptids[i]:
			print("  Cryptid", i, ":", all_cryptids[i].name)
		else:
			print("  Cryptid", i, ": null")
	
	# Counter for eligible cryptids
	var eligible_count = 0
	
	print("DIALOG: Creating slots for", all_cryptids.size(), "cryptids")
	
	# Create a slot for each cryptid directly
	for i in range(all_cryptids.size()):
		var cryptid = all_cryptids[i]
		
		if not cryptid:
			print("ERROR: Null cryptid at index", i)
			continue
			
		print("DIALOG: Processing cryptid:", cryptid.name)
		
		# Check if this cryptid is already in play
		var in_play = false
		for played_cryptid in cryptids_in_play:
			if played_cryptid.cryptid == cryptid:
				in_play = true
				print("DIALOG: Cryptid", cryptid.name, "is in play")
				break
		
		if not in_play:
			print("DIALOG: Cryptid", cryptid.name, "is available for swap")
			eligible_count += 1
		
		# Create a slot directly
		print("DIALOG: Creating slot for", cryptid.name)
		var slot = create_slot(cryptid, in_play)
		
		if slot:
			print("DIALOG: Adding slot to grid")
			grid_container.add_child(slot)
		else:
			print("ERROR: Failed to create slot for", cryptid.name)
	
	# Show warning if no eligible cryptids
	if eligible_count == 0:
		print("DIALOG: No eligible cryptids found")
		title_label.text = "No eligible cryptids available for swap!"
		close_button.text = "Close"
	else:
		print("DIALOG: Found", eligible_count, "eligible cryptids")
		close_button.text = "Cancel"
	
	# Show the dialog
	print("DIALOG: Showing dialog")
	show()
	print("DIALOG: Dialog should be visible now")

# Create a slot UI element directly
func create_slot(cryptid: Cryptid, in_play: bool) -> PanelContainer:
	print("DIALOG: create_slot for", cryptid.name)
	
	# Create the panel container
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(220, 180)
	slot.size_flags_horizontal = 3  # SIZE_EXPAND_FILL = 3
	
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
	# Based on documentation
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
	
	# Create health label
	var health_label = Label.new()
	health_label.text = "HP: " + str(cryptid.health) + "/" + str(cryptid.health)
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
	
	# Handle if in play
	if in_play:
		# Gray out the slot
		slot.modulate = Color(0.5, 0.5, 0.5, 1.0)
		
		# Create overlay
		var overlay = ColorRect.new()
		overlay.color = Color(0, 0, 0, 0.3)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(overlay)
		
		# Set the overlay to cover the whole slot
		overlay.set_anchors_preset(8)  # PRESET_FULL_RECT = 8
		overlay.position = Vector2.ZERO
	else:
		# Make clickable and setup for signals
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Store cryptid reference
		slot.set_meta("cryptid", cryptid)
		
		# Connect input event directly
		slot.gui_input.connect(_on_slot_gui_input.bind(slot, cryptid))
	
	print("DIALOG: Created slot for", cryptid.name)
	return slot

# Handle slot input
func _on_slot_gui_input(event, slot, cryptid):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Selected cryptid: " + cryptid.name)
		emit_signal("cryptid_selected", cryptid)
		hide()
		get_viewport().set_input_as_handled()

# Close button pressed
func _on_close_button_pressed():
	hide()
	
	# Reset the action menu
	var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_menu and action_menu.has_method("prompt_player_for_action"):
		action_menu.prompt_player_for_action()
