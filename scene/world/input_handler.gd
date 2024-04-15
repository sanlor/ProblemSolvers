extends Node

@onready var players_list_screen = $"../players_list_screen"
@onready var connection_screen = $"../connection_screen"

func _process(_delta):
	if Input.is_action_just_pressed("menu"):
		#Global.show_connection_screen.emit()
		connection_screen.toggle_menu()
		
		
	if Input.is_action_just_pressed("player_list"):
		players_list_screen.visible = true
		
	elif Input.is_action_just_released("player_list"):
		players_list_screen.visible = false
		
