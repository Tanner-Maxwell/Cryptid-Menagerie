extends Node

class_name NodeBase

var Connection : NodeBase:
	set(new_connection):
		Connection = new_connection
	get():
		return Connection

@export var Walkable : bool = true:
	set(new_value):
		Walkable = new_value
	get():
		return Walkable
		
@export var G : int:
	set(new_value):
		G = new_value
	get():
		return G
		
@export var H : int:
	set(new_value):
		H = new_value
	get():
		return H
		
@export var F : int:
	set(new_value):
		F = new_value
	get():
		return G + H
		
@export var Cube_Cords : Vector3i:
	set(new_value):
		Cube_Cords = new_value
	get():
		return Cube_Cords

@export var Hex_Cords : Vector2i:
	set(new_value):
		Hex_Cords = new_value
	get():
		return Hex_Cords


func SetConnection(nodeBase : NodeBase):
	Connection = nodeBase
	
func SetG(g):
	G = g

func SetH(h):
	H = h

func SetCubeCords(cube_cords):
	Cube_Cords = cube_cords

func SetHexCords(hex_cords):
	Hex_Cords = hex_cords
