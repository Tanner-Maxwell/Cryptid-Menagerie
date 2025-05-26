extends Control

# Path to overworld scene to transition to after selection
const OVERWORLD_SCENE_PATH = "res://Cryptid-Menagerie/scenes/overworld_map.tscn"

# References to UI elements
@onready var grid_container = $MainContainer/GridAndDetailsContainer/GridContainer/GridScrollContainer/CryptidGrid
@onready var details_panel = $MainContainer/GridAndDetailsContainer/DetailsPanel
@onready var confirm_button = $MainContainer/BottomBar/ConfirmButton
@onready var search_bar = $MainContainer/TopBar/FilterContainer/SearchBar
@onready var sort_option_button = $MainContainer/TopBar/FilterContainer/SortOptionButton
@onready var biome_filter_button = $MainContainer/TopBar/FilterContainer/BiomeFilterButton
@onready var type_filter_button = $MainContainer/TopBar/FilterContainer/TypeFilterButton
@onready var play_style_filter_button = $MainContainer/TopBar/FilterContainer/PlayStyleFilterButton
@onready var cryptid_slot_scene = preload("res://Cryptid-Menagerie/starter_cryptid_slot.tscn")


# Variables to track selection state
var selected_cryptid: Cryptid = null
var all_cryptids: Array[Cryptid] = []
var filtered_cryptids: Array[Cryptid] = []
var available_biomes: Array[BiomeCryptids] = []

# Export variables for configuration
@export var biome_resources: Array[BiomeCryptids] = []

func _ready():
	# Set up UI controls
	_setup_sort_options()
	_setup_filter_buttons()
	
	# Connect signals
	search_bar.text_changed.connect(_on_search_text_changed)
	sort_option_button.item_selected.connect(_on_sort_option_selected)
	confirm_button.pressed.connect(_on_confirm_pressed)
	
	# Load all available cryptids from biome resources
	load_all_cryptids()
	
	# Initially, show all cryptids sorted alphabetically
	filtered_cryptids = all_cryptids.duplicate()
	sort_cryptids("Name")
	
	# Disable confirm button until a cryptid is selected
	confirm_button.disabled = true
	
	# Populate the grid with cryptid slots
	populate_grid()

func _setup_sort_options():
	# Add sort options to the dropdown
	sort_option_button.clear()
	sort_option_button.add_item("Name (A-Z)")
	sort_option_button.add_item("Health (High-Low)")
	sort_option_button.add_item("Speed (High-Low)")
	sort_option_button.add_item("Deck Size (High-Low)")
	
	# Add elemental types to the type filter button
	type_filter_button.clear()
	type_filter_button.add_item("All Types")
	
	# Add all elemental types from the enum
	for i in range(Cryptid.ELEMENTAL_TYPE.size()):
		var type_name = Cryptid.ELEMENTAL_TYPE.keys()[i]
		type_filter_button.add_item(type_name)
	
	# Add play styles to the play style filter button
	play_style_filter_button.clear()
	play_style_filter_button.add_item("All Styles")
	play_style_filter_button.add_item("Damage")
	play_style_filter_button.add_item("Tank")
	play_style_filter_button.add_item("Support")
	

func _setup_filter_buttons():
	# Connect filter buttons
	type_filter_button.item_selected.connect(_on_type_filter_selected)
	play_style_filter_button.item_selected.connect(_on_play_style_filter_selected)
	biome_filter_button.item_selected.connect(_on_biome_filter_selected)
	
	# Populate biome filter button
	biome_filter_button.clear()
	biome_filter_button.add_item("All Biomes")
	
	for biome in biome_resources:
		biome_filter_button.add_item(biome.biome_name)

func load_all_cryptids():
	all_cryptids.clear()
	available_biomes.clear()
	
	# Load from assigned biome resources
	for biome_resource in biome_resources:
		available_biomes.append(biome_resource)
		for cryptid in biome_resource.cryptids:
			if not all_cryptids.has(cryptid):
				all_cryptids.append(cryptid)
	
	print("Loaded " + str(all_cryptids.size()) + " cryptids from " + str(biome_resources.size()) + " biomes")

func populate_grid():
	# Clear existing grid items
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()
	
	# Add a slot for each cryptid in filtered list
	for cryptid in filtered_cryptids:
		var slot = cryptid_slot_scene.instantiate()
		grid_container.add_child(slot)
		slot.setup(cryptid)
		slot.selected.connect(_on_cryptid_selected.bind(cryptid))
		slot.hovered.connect(_on_cryptid_hovered.bind(cryptid))
		slot.unhovered.connect(_on_cryptid_unhovered)

func _on_cryptid_selected(cryptid: Cryptid):
	# Update selected cryptid and show detailed information
	selected_cryptid = cryptid
	update_details_panel(cryptid, true)  # Show full details
	
	# Update visuals for selected slots
	for slot in grid_container.get_children():
		if slot.cryptid == selected_cryptid:
			slot.set_selected(true)
		else:
			slot.set_selected(false)
	
	# Enable confirm button
	confirm_button.disabled = false

func _on_cryptid_hovered(cryptid: Cryptid):
	if selected_cryptid == null:
		# Only show hover details if nothing is selected
		update_details_panel(cryptid, false)  # Show hover details

func _on_cryptid_unhovered():
	if selected_cryptid == null:
		# Clear details panel if nothing is selected
		clear_details_panel()
	else:
		# Show selected cryptid details
		update_details_panel(selected_cryptid, true)

func update_details_panel(cryptid: Cryptid, full_details: bool):
	if cryptid == null:
		clear_details_panel()
		return
		
	# Update cryptid name and image
	details_panel.get_node("VBoxContainer/NameLabel").text = cryptid.name
	
	if cryptid.icon:
		details_panel.get_node("VBoxContainer/CryptidIconRect").texture = cryptid.icon
	
	# Get type string
	var type_string = "Type: "
	if "elemental_types" in cryptid and cryptid.elemental_types.size() > 0:
		var types = []
		for type_id in cryptid.elemental_types:
			if type_id >= 0 and type_id < Cryptid.ELEMENTAL_TYPE.size():
				types.append(Cryptid.ELEMENTAL_TYPE.keys()[type_id])
		
		type_string += " / ".join(types)
	else:
		type_string += "Unknown"
	
	details_panel.get_node("VBoxContainer/TypeLabel").text = type_string
	
	# Update basic stats
	details_panel.get_node("VBoxContainer/StatsContainer/HealthLabel").text = "Health: " + str(cryptid.health)
	details_panel.get_node("VBoxContainer/StatsContainer/SpeedLabel").text = "Speed: " + str(cryptid.speed)
	details_panel.get_node("VBoxContainer/StatsContainer/DeckSizeLabel").text = "Deck Size: " + str(cryptid.max_hand_size)
	
	# Show/hide additional details based on full_details flag
	details_panel.get_node("VBoxContainer/FullStatsContainer").visible = full_details
	
	if full_details:
		# Update full stat details
		details_panel.get_node("VBoxContainer/FullStatsContainer/StrengthLabel").text = "Strength: " + str(cryptid.strength)
		details_panel.get_node("VBoxContainer/FullStatsContainer/DexterityLabel").text = "Dexterity: " + str(cryptid.dexterity)
		details_panel.get_node("VBoxContainer/FullStatsContainer/VigorLabel").text = "Vigor: " + str(cryptid.vigor)
		details_panel.get_node("VBoxContainer/FullStatsContainer/KnowledgeLabel").text = "Knowledge: " + str(cryptid.knowledge)
		details_panel.get_node("VBoxContainer/FullStatsContainer/WillpowerLabel").text = "Willpower: " + str(cryptid.willpower)
		
		# Show play style if available
		var style_text = "Play Style: "
		if "play_style" in cryptid:
			style_text += get_play_style_name(cryptid.play_style)
		else:
			style_text += "Balanced"
		details_panel.get_node("VBoxContainer/FullStatsContainer/PlayStyleLabel").text = style_text
		
		# Show cards preview if available
		var cards_container = details_panel.get_node("VBoxContainer/FullStatsContainer/CardPreviewContainer")
		cards_container.visible = cryptid.deck.size() > 0
		
		# Display deck info
		var deck_info = "Starting Deck: " + str(cryptid.deck.size()) + " cards"
		details_panel.get_node("VBoxContainer/FullStatsContainer/DeckInfolabel").text = deck_info
	
	# Show the details panel
	details_panel.visible = true

func clear_details_panel():
	details_panel.get_node("VBoxContainer/NameLabel").text = "Select a Cryptid"
	details_panel.get_node("VBoxContainer/CryptidIconRect").texture = null
	details_panel.get_node("VBoxContainer/TypeLabel").text = "Type: -"
	details_panel.get_node("VBoxContainer/StatsContainer/HealthLabel").text = "Health: -"
	details_panel.get_node("VBoxContainer/StatsContainer/SpeedLabel").text = "Speed: -"
	details_panel.get_node("VBoxContainer/StatsContainer/DeckSizeLabel").text = "Deck Size: -"
	details_panel.get_node("VBoxContainer/FullStatsContainer").visible = false

func get_play_style_name(style_id: int) -> String:
	match style_id:
		0: return "Damage"
		1: return "Tank"
		2: return "Support"
		_: return "Balanced"

func _on_search_text_changed(new_text: String):
	apply_filters()

func _on_sort_option_selected(index: int):
	var sort_type = sort_option_button.get_item_text(index)
	
	# Extract the actual sort key from the displayed text
	if "Name" in sort_type:
		sort_cryptids("Name")
	elif "Health" in sort_type:
		sort_cryptids("Health")
	elif "Speed" in sort_type:
		sort_cryptids("Speed")
	elif "Deck Size" in sort_type:
		sort_cryptids("DeckSize")

func _on_type_filter_selected(index: int):
	apply_filters()

func _on_play_style_filter_selected(index: int):
	apply_filters()

func _on_biome_filter_selected(index: int):
	apply_filters()

func apply_filters():
	# Start with all cryptids
	filtered_cryptids = all_cryptids.duplicate()
	
	# Apply search filter
	var search_text = search_bar.text.to_lower()
	if search_text != "":
		var search_results: Array[Cryptid] = []
		for cryptid in filtered_cryptids:
			if cryptid.name.to_lower().contains(search_text):
				search_results.append(cryptid)
		filtered_cryptids = search_results
	
	# Apply biome filter
	var biome_index = biome_filter_button.selected
	if biome_index > 0:  # 0 is "All Biomes"
		var biome_name = biome_filter_button.get_item_text(biome_index)
		var biome_results: Array[Cryptid] = []
		
		for cryptid in filtered_cryptids:
			# Check if this cryptid is in the selected biome
			for biome in available_biomes:
				if biome.biome_name == biome_name and biome.cryptids.has(cryptid):
					biome_results.append(cryptid)
					break
					
		filtered_cryptids = biome_results
	
	# Apply elemental type filter
	var type_index = type_filter_button.selected
	if type_index > 0:  # 0 is "All Types"
		var type_name = type_filter_button.get_item_text(type_index)
		var type_id = Cryptid.ELEMENTAL_TYPE[type_name]
		var type_results: Array[Cryptid] = []
		
		for cryptid in filtered_cryptids:
			if "elemental_types" in cryptid:
				# Check if the selected type is in the cryptid's array of types
				if type_id in cryptid.elemental_types:
					type_results.append(cryptid)
				
		filtered_cryptids = type_results
	
	# Apply play style filter
	var style_index = play_style_filter_button.selected
	if style_index > 0:  # 0 is "All Styles"
		var style_name = play_style_filter_button.get_item_text(style_index)
		var style_id
		
		match style_name:
			"Damage": style_id = 0
			"Tank": style_id = 1
			"Support": style_id = 2
			_: style_id = -1
			
		var style_results: Array[Cryptid] = []
		for cryptid in filtered_cryptids:
			if "play_style" in cryptid and cryptid.play_style == style_id:
				style_results.append(cryptid)
				
		filtered_cryptids = style_results
	
	# Apply current sort
	var sort_index = sort_option_button.selected
	var sort_type = sort_option_button.get_item_text(sort_index)
	
	if "Name" in sort_type:
		sort_cryptids("Name")
	elif "Health" in sort_type:
		sort_cryptids("Health")
	elif "Speed" in sort_type:
		sort_cryptids("Speed")
	elif "Deck Size" in sort_type:
		sort_cryptids("DeckSize")
	
	# Repopulate the grid with filtered results
	populate_grid()
	
	# Update UI with count of results
	$MainContainer/TopBar/FilterContainer/ResultsLabel.text = str(filtered_cryptids.size()) + " results"

func sort_cryptids(sort_by: String):
	match sort_by:
		"Name":
			filtered_cryptids.sort_custom(func(a, b): return a.name < b.name)
		"Health":
			filtered_cryptids.sort_custom(func(a, b): return a.health > b.health)
		"Speed":
			filtered_cryptids.sort_custom(func(a, b): return a.speed > b.speed)
		"DeckSize":
			filtered_cryptids.sort_custom(func(a, b): return a.max_hand_size > b.max_hand_size)

func _on_confirm_pressed():
	if selected_cryptid == null:
		return
		
	print("Starter cryptid confirmed: " + selected_cryptid.name)
	
	# Add the cryptid to the player's team in GameState
	if not GameState.player_team:
		GameState.player_team = Team.new()
		
	GameState.player_team.add_cryptid(selected_cryptid)
	print("Added " + selected_cryptid.name + " to player team")
	
	# Debug the team contents
	if GameState.has_method("debug_player_team"):
		GameState.debug_player_team()
	
	# Transition to the overworld scene
	get_tree().change_scene_to_file(OVERWORLD_SCENE_PATH)
