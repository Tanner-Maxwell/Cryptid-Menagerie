extends Node2D

@onready var player = %Player
@export var cryptid:Cryptid

func _ready():
	var instance = cryptid.scene.instantiate()
	add_child(instance)
	

func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouse:
		if event.button_mask == MOUSE_BUTTON_LEFT and event.is_pressed():
			if player.has_method("add_to_party"):
				player.add_to_party(cryptid)
				#queue_free()
