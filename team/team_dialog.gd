class_name TeamDialog
extends PanelContainer

@export var slot_scene:PackedScene

@onready var team_dialog_grid_container:GridContainer = %TeamDialogGridContainer

func open(team:Team):
	show()
	for children in team_dialog_grid_container.get_children():
		team_dialog_grid_container.remove_child(children)
	for cryptid in team.get_cryptids():
		var slot = slot_scene.instantiate()
		team_dialog_grid_container.add_child(slot)
		slot.display(cryptid)

func _on_close_button_pressed():
	hide()
