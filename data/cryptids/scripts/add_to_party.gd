extends Node2D

@onready var player = %Player
@export var cryptid:Cryptid
var max_health : int
var health : int

func _ready():
	var instance = cryptid.scene.instantiate()
	add_child(instance)
	cryptid.update_stats()
	set_health_values(cryptid.health, cryptid.health)
	print(cryptid.health)
	update_health_bar()

func _process(delta):
	pass


func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouse:
		if event.button_mask == MOUSE_BUTTON_LEFT and event.is_pressed():
			if player.has_method("add_to_party"):
				player.add_to_party(cryptid)
				#queue_free()

func set_health_values(_health: int, _max_health: int):
	max_health = _max_health
	health = _health

func update_health_bar():
	($HealthBar as ProgressBar).max_value = max_health
	($HealthBar as ProgressBar).value = health
	print(health, "health")
	print(max_health, "max_health")
	print(cryptid.name)
