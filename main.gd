extends Node2D

@onready var game_controller = $GameController


var enemy_character_state: int = 0
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
	#if game_controller.current_state == game_controller.GameState.ENEMY_TURN:
		#pass
