extends Node2D

@onready var player = %Player
@onready var hand = %Hand
@onready var discard_cards = %DiscardCards

@onready var turn_completed_ = $"TurnCompleted?"
@onready var selected = $Selected
@onready var player_team = %PlayerTeam
var discard_cards_visible = false
var status_effect_manager: StatusEffectManager
var status_effect_display: StatusEffectDisplay

@export var cryptid:Cryptid
var max_health : int
var health : int

func _ready():
	var instance = cryptid.scene.instantiate()
	add_child(instance)
	cryptid.update_stats()
	set_health_values(cryptid.health, cryptid.health)
	update_health_bar()
	hand = %Hand
	discard_cards = get_tree().get_root().find_child("DiscardDialog", true, false)
	if discard_cards == null:
		print("ERROR: Could not find DiscardCards node in scene tree")
	selected.modulate = Color(0, 0 , 0, 0)
	
	initialize_status_effects()

func _process(delta):
	if cryptid.completed_turn == true:
		turn_completed_.modulate = Color(1, 0 , 0, 1)
	if self.get_parent().is_in_group("enemy"):
		turn_completed_.modulate = Color(0, 0 , 0, 0)
	if cryptid.currently_selected == true:
		selected.modulate = Color(1, 0 , .5, 1)
	else:
		selected.modulate = Color(0, 0, 0, 0)
		
		

func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Get reference to tile map to check if actions are in progress
		var tile_map = get_tree().get_nodes_in_group("map")[0]
		
		# IMPORTANT: Check if attack action is in progress
		if tile_map.attack_action_bool:
			# Don't handle the event here - let the attack action handle it
			print("Attack in progress, ignoring cryptid click")
			return
			
		# Don't toggle discard cards if an action is in progress
		if tile_map.move_action_bool:
			# We're in the middle of an action, don't show/hide discard
			print("Action in progress, ignoring discard toggle")
			return
			
		## Toggle visibility of discard cards
		#discard_cards_visible = !discard_cards_visible
		#
		#if discard_cards_visible:
			## Show discard cards
			#hand.switch_cryptid_discard_cards(cryptid)
			#discard_cards.show()
			#hand.clear_card_selections()
		#else:
			## Hide discard cards
			#discard_cards.hide()
			

func set_health_values(current, maximum):
	# Update the health bar
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.value = current
		health_bar.max_value = maximum
	
	# IMPORTANT: Always update the metadata for consistent tracking
	cryptid.set_meta("current_health", current)
	
	# For compatibility, also set the property if it exists
	if cryptid.get("current_health") != null:
		cryptid.current_health = current

func update_health_bar():
	var health_bar = get_node_or_null("HealthBar")
	if health_bar and cryptid:
		# Update the label text
		var health_label = get_node_or_null("HealthNumber")
		if health_label:
			health_label.text = str(health_bar.value) + "/" + str(health_bar.max_value)
		
		# IMPORTANT: Always make sure metadata is in sync
		cryptid.set_meta("current_health", health_bar.value)
		
		# For compatibility, also update the property if it exists
		if cryptid.get("current_health") != null:
			cryptid.current_health = health_bar.value
			
		# Tint the health bar based on current health percentage
		var health_percent = float(health_bar.value) / health_bar.max_value
		if health_percent <= 0.25:
			health_bar.modulate = Color(1, 0, 0, 1)  # Red for critical health
		elif health_percent <= 0.5:
			health_bar.modulate = Color(1, 0.5, 0, 1)  # Orange for low health
		else:
			health_bar.modulate = Color(0, 1, 0, 1)  # Green for good health

func initialize_status_effects():
	# Create and add status effect manager
	status_effect_manager = StatusEffectManager.new()
	status_effect_manager.name = "StatusEffectManager"
	add_child(status_effect_manager)
	status_effect_manager.initialize(self)
	
	# Create and add status effect display
	status_effect_display = StatusEffectDisplay.new()
	status_effect_display.name = "StatusEffectDisplay"
	add_child(status_effect_display)
	
	# Position the display above the health bar
	var health_bar = get_node("HealthBar")
	if health_bar:
		# Get the left edge of the health bar
		var health_bar_left = health_bar.position.x - (health_bar.size.x / 2)
		
		status_effect_display.position = Vector2(
			health_bar.position.x,  # Adjust this value to move left/right
			health_bar.position.y - 35   # Adjust this value to move up/down
		)
	else:
		# Fallback position if no health bar found
		status_effect_display.position = Vector2(0, -60)
	
	# Set a higher z_index to ensure it renders above everything
	status_effect_display.z_index = 100
	
	# Initialize the display with the manager
	status_effect_display.initialize(status_effect_manager)

func setup_status_effect_display():
	# Check if StatusEffectManager exists
	if not has_node("StatusEffectManager"):
		var status_manager = StatusEffectManager.new()
		status_manager.name = "StatusEffectManager"
		add_child(status_manager)
		status_manager.initialize(self)
	
	# Check if StatusEffectDisplay exists
	if not has_node("StatusEffectDisplay"):
		var status_display = StatusEffectDisplay.new()
		status_display.name = "StatusEffectDisplay"
		add_child(status_display)
		
		# Get the status manager
		var status_manager = get_node("StatusEffectManager")
		status_display.initialize(status_manager)
		
		# Position it above the cryptid
		# Adjust these values based on your cryptid sprite size
		status_display.position = Vector2(0, -60)  # 60 pixels above center
		status_display.z_index = 10  # Ensure it renders above the cryptid
