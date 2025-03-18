extends Node2D

@onready var player = %Player
@onready var hand = %Hand
@onready var turn_completed_ = $"TurnCompleted?"
@onready var selected = $Selected
@onready var player_team = %PlayerTeam

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
	if event is InputEventMouse:
		if event.button_mask == MOUSE_BUTTON_LEFT and event.is_pressed() and self.get_parent().is_in_group("player"):
			#hand.switch_cryptid_deck(cryptid)
			hand.switch_cryptid_discard_cards(cryptid)

func set_health_values(_health: int, _max_health: int):
	max_health = _max_health
	health = _health

func update_health_bar():
	($HealthBar as ProgressBar).max_value = max_health
	($HealthBar as ProgressBar).value = health
