class_name Team

var _content:Array[Cryptid] = []

func add_cryptid(cryptid:Cryptid):
	_content.append(cryptid)

func remove_cryptid(cryptid:Cryptid):
	_content.erase(cryptid)

func get_cryptids() -> Array[Cryptid]:
	return _content
