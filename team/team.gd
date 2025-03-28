extends Node2D
class_name Team

const MAX_TEAM_SIZE = 6  # Maximum number of cryptids in a team

@export var _content:Array[Cryptid] = []

func add_cryptid(cryptid:Cryptid) -> bool:
	# Check if team is already at maximum size
	if _content.size() >= MAX_TEAM_SIZE:
		return false
	
	_content.append(cryptid)
	return true

func has_space() -> bool:
	return _content.size() < MAX_TEAM_SIZE

func remove_cryptid(cryptid:Cryptid):
	_content.erase(cryptid)

func get_cryptids() -> Array[Cryptid]:
	return _content
