extends Node

# This is a singleton to track permanently defeated cryptids across the game
var _defeated_list = []

func _ready():
	print("DefeatedCryptidsTracker singleton initialized")

func add_defeated(cryptid_name):
	if !_defeated_list.has(cryptid_name):
		_defeated_list.append(cryptid_name)
		print("Added to global defeated list:", cryptid_name)
	
func get_defeated_list():
	return _defeated_list
	
func is_defeated(cryptid_name):
	return _defeated_list.has(cryptid_name)
