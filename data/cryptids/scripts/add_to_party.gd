extends Node2D

@onready var player = %Player
@onready var hand = %Hand
@onready var discard_cards = %DiscardCards

@onready var turn_completed_ = $"TurnCompleted?"
@onready var selected = $Selected
@onready var player_team = %PlayerTeam
var discard_cards_visible = false


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
		
		# Don't toggle discard cards if an action is in progress
		if tile_map.move_action_bool or tile_map.attack_action_bool:
			# We're in the middle of an action, don't show/hide discard
			print("Action in progress, ignoring discard toggle")
			return
			
		# Toggle visibility of discard cards
		discard_cards_visible = !discard_cards_visible
		
		if discard_cards_visible:
			# Show discard cards
			hand.switch_cryptid_discard_cards(cryptid)
			discard_cards.show()
		else:
			# Hide discard cards
			discard_cards.hide()
			

func set_health_values(_health: int, _max_health: int):
	max_health = _max_health
	health = _health

func update_health_bar():
	($HealthBar as ProgressBar).max_value = max_health
	($HealthBar as ProgressBar).value = health
