class_name SwapCryptidDialog
extends PanelContainer

# Static list of all cryptids that have been defeated (persists between swaps)
static var all_defeated_cryptids = []

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

func open(team: Team, cryptid_to_swap: Cryptid, cryptids_in_play: Array):
	print("DIALOG: open() called")
	print("DIALOG: Team:", team)
	print("DIALOG: Swap cryptid:", cryptid_to_swap.name)
	print("DIALOG: Cryptids in play:", cryptids_in_play.size())
	
	# Add the currently swapped cryptid to the persistent defeated list
	if !all_defeated_cryptids.has(cryptid_to_swap.name):
		all_defeated_cryptids.append(cryptid_to_swap.name)
		print("Added to permanently defeated list:", cryptid_to_swap.name)
	
	print("Current defeated cryptids list:", all_defeated_cryptids)
	
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
	
	# Filter out cryptids that have been previously defeated
	var valid_cryptids = []
	for cryptid in all_cryptids:
		if cryptid == null:
			continue
			
		# Check if this cryptid has been permanently defeated
		if all_defeated_cryptids.has(cryptid.name):
			print("DIALOG: EXCLUDING defeated cryptid:", cryptid.name)
			continue
		
		valid_cryptids.append(cryptid)
		print("DIALOG: KEEPING valid cryptid:", cryptid.name)
	
	all_cryptids = valid_cryptids
	
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

func create_slot(cryptid: Cryptid, in_play: bool) -> PanelContainer:
	print("DIALOG: create_slot for", cryptid.name)
	
	# Create the panel container
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(220, 180)
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
	
	# Create health label - getting the correct stored health
	var health_label = Label.new()
	var current_health = cryptid.health  # Default to max health
	var max_health = cryptid.health
	
	# Step 1: Check for in-play cryptids (most up-to-date health)
	if in_play:
		# Find the corresponding node
		for cryptid_node in get_tree().get_nodes_in_group("cryptids"):
			if cryptid_node.cryptid == cryptid:
				# Try to get health from the health bar
				var health_bar = cryptid_node.get_node_or_null("HealthBar")
				if health_bar:
					current_health = health_bar.value
					max_health = health_bar.max_value
					print("DIALOG: Found actual health for " + cryptid.name + ": " + 
						  str(current_health) + "/" + str(max_health))
				break
	# Step 2: For cryptids not in play, check for stored health
	else:
		# Check for health property first
		if cryptid.get("current_health") != null and cryptid.current_health > 0:
			current_health = cryptid.current_health
			print("DIALOG: Found stored health property for " + cryptid.name + ": " + str(current_health))
		# Then check for metadata
		elif cryptid.has_meta("current_health") and cryptid.get_meta("current_health") > 0:
			current_health = cryptid.get_meta("current_health")
			print("DIALOG: Found stored health metadata for " + cryptid.name + ": " + str(current_health))
		else:
			print("DIALOG: No stored health found for " + cryptid.name + ", using default: " + str(current_health))
	
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
		
		# Make non-playable slots stand out more with a different color
		style_box.bg_color = Color(0.3, 0.3, 0.5, 1.0)  # Slightly bluish
		
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

func set_title(new_title):
	title_label.text = new_title
	
	# Add a red flash effect to the title to emphasize emergency
	var original_color = title_label.get_theme_color("font_color", "Label")
	var flash_tween = get_tree().create_tween()
	flash_tween.tween_property(title_label, "modulate", Color(1, 0, 0, 1), 0.5)
	flash_tween.tween_property(title_label, "modulate", Color(1, 1, 1, 1), 0.5)
	
	# Make the dialog larger and more prominent
	custom_minimum_size = Vector2(650, 550)
	
	# Add a red border to the panel
	var panel_style = get_theme_stylebox("panel", "PanelContainer")
	if panel_style:
		var new_style = panel_style.duplicate()
		new_style.border_width_left = 4
		new_style.border_width_top = 4
		new_style.border_width_right = 4
		new_style.border_width_bottom = 4
		new_style.border_color = Color(1, 0, 0, 1)
		add_theme_stylebox_override("panel", new_style)
