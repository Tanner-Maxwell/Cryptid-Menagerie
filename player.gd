class_name Player
extends Node2D

var cryptidTeam: Team = Team.new()

func add_to_party(cryptid:Cryptid):
	print("I got a ", cryptid.name)
	cryptidTeam.add_cryptid(cryptid)
