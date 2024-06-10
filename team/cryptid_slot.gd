extends PanelContainer

@onready var texture_rect:TextureRect = %TextureRect

func display(cryptid:Cryptid):
	texture_rect.texture = cryptid.icon
