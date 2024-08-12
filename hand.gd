extends Control

@export var hand_radius: int = 100
@export var card_angle: float = -90
@export var angle_limit: float = 25
@export var max_card_spread_angle: float = 5

@onready var card_dialog = preload("res://Cryptid-Menagerie/data/cryptids/Cards/card_dialog.tscn")

var hand: Array = []

func add_card(card):
	hand.push_back(card)
	add_child(card)
	reposition_cards()

func reposition_cards():
	var card_spread = min(angle_limit / hand.size(), max_card_spread_angle)
	var current_angle = -(card_spread * (hand.size()- 1))/2 - 90
	for card in hand:
		card_transform_update(card, current_angle)
		current_angle += card_spread
		pass

func get_card_position(angle: float) -> Vector2:
	var x: float = hand_radius * cos(deg_to_rad(angle))
	var y: float = hand_radius * sin(deg_to_rad(angle))
	
	return Vector2(x, y)

func card_transform_update(card, angle_in_drag: float):
	card.set_position(get_card_position(angle_in_drag))
	card.set_rotation(deg_to_rad(angle_in_drag + 90))


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
	#card_dialog.set_position(get_card_position(card_angle))


func _on_button_pressed():
	var base_card = card_dialog.instantiate()
	base_card.card_resource = preload("res://Cryptid-Menagerie/data/cryptids/Moves/test_card.tres")
	add_card(base_card)
	print("card added: ", base_card)
