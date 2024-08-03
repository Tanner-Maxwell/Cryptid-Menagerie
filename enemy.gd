class_name Enemy
extends Node2D

var cryptidTeam:Team = Team.new()

@export var cryptid_one:Cryptid
@export var cryptid_two:Cryptid
@export var cryptid_three:Cryptid
@export var cryptid_four:Cryptid
@export var cryptid_five:Cryptid
@export var cryptid_six:Cryptid

func _ready():
	var instance = cryptid_one.scene.instantiate()
	add_child(instance)
	add_to_party(cryptid_one)

func add_to_party(cryptid:Cryptid):
	print("I got a ", cryptid.name)
	cryptidTeam.add_cryptid(cryptid)
	
