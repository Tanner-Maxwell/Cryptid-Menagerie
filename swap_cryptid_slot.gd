class_name SwapCryptidSlot
extends PanelContainer

signal selected

@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var health_label: Label = %HealthLabel
@onready var cards_label: Label = %CardsLabel
@onready var in_play_overlay: ColorRect = %InPlayOverlay

var cryptid_data = null
var is_in_play = false

# In your _ready() function, add some debugging to verify nodes are found:
func _ready():
	# Debug: check if all nodes were found
	var nodes_ok = true
	
	if not icon_rect:
		print("ERROR: IconRect not found in SwapCryptidSlot")
		nodes_ok = false
	
	if not name_label:
		print("ERROR: NameLabel not found in SwapCryptidSlot")
		nodes_ok = false
	
	if not health_label:
		print("ERROR: HealthLabel not found in SwapCryptidSlot")
		nodes_ok = false
		
	if not cards_label:
		print("ERROR: CardsLabel not found in SwapCryptidSlot")
		nodes_ok = false
		
	if not in_play_overlay:
		print("ERROR: InPlayOverlay not found in SwapCryptidSlot")
		nodes_ok = false
	
	if nodes_ok:
		print("SwapCryptidSlot: All node references found successfully")
	else:
		print("SwapCryptidSlot: Some node references are missing, slot functionality will be limited")
		
	# Try alternative lookup methods if nodes weren't found
	if not icon_rect:
		icon_rect = find_child("IconRect", true, false)
		if icon_rect:
			print("Found IconRect using find_child")

# Set up the slot with cryptid data
func setup(cryptid: Cryptid, in_play: bool):
	cryptid_data = cryptid 
	is_in_play = in_play
	
	# Set icon
	icon_rect.texture = cryptid.icon
	
	# Set name
	name_label.text = cryptid.name
	
	# Set health - check for actual health in nodes first
	var actual_health = cryptid.health
	# Health bar label
	health_label.text = "HP: " + str(actual_health) + "/" + str(cryptid.health)
	
	# Set cards info
	var in_deck = 0
	var in_discard = 0
	
	for card in cryptid.deck:
		if card.current_state == Card.CardState.IN_DECK:
			in_deck += 1
		elif card.current_state == Card.CardState.IN_DISCARD:
			in_discard += 1
	
	cards_label.text = "Deck: " + str(in_deck) + " / Discard: " + str(in_discard)
	
	# Show/hide overlay based on in_play status
	in_play_overlay.visible = in_play
	
	# Set slot interactivity
	mouse_filter = Control.MOUSE_FILTER_STOP if not in_play else Control.MOUSE_FILTER_IGNORE
	
	# If in play, gray out the panel
	if in_play:
		modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		modulate = Color(1, 1, 1, 1)

# Handle click events
func _gui_input(event):
	if not is_in_play and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("selected")
		get_viewport().set_input_as_handled()
