extends CanvasLayer

@onready var player = %PlayerTeam
@onready var team_dialog:TeamDialog = %TeamDialog

func _unhandled_input(event):
	if event.is_action_released("TeamDialog"):
		team_dialog.open(player.cryptidTeam)
