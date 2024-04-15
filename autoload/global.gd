@tool
extends Node

const map_size 			:= Vector2(1024, 768)
const map_stretch 		:= Vector2( 1,1 )
const game_area 		:= Rect2(Vector2.ZERO, map_size)
const gravity			:= 5.0
	
var world_node 			: Node2D
var playground_node 	: Node2D
var lobby 				: Node
var game_seed 			:= hash("poop")

## server check
var has_initial_server_data := false
var server_only := false

## Game settins
var max_amount_blood_splatter := 15 # being shot

var player_data_update_time := 1.0
var game_time_to_spawn := 3

var player_is_in_game := false
var player_is_spawned 	:= false :
	set(a):
		player_is_spawned = a
		print("player spawned ", player_is_spawned)
var player_input_disabled := false

enum GAME_STATE{CONNECTION,SPAWN,IN_GAME}
var curr_GAME_STATE = GAME_STATE.CONNECTION : 
	set(state):
		curr_GAME_STATE = state
		game_state_changed.emit( curr_GAME_STATE )
		print("Changed game state to ", GAME_STATE.keys()[ curr_GAME_STATE ])

## Signals
signal game_state_changed (state : GAME_STATE)
signal show_connection_screen # force open the connection screen in case of a disconnection or pressing ESC
signal show_spawn_screen

signal begin_game # Headless server wants to start the game

signal player_entered_world( player_id : int) ## called by the UI

signal player_death( player_id )
signal spawn_player( player_id )
signal create_projectile (weapon_data : Weapons, initial_position : Vector2, initial_direction : float)

## Settings
signal update_inputs

func _ready():
	_init_settings() # save default inputs
	load_settings() # load user inputs

var default_input := {}
var user_config := "user.cfg"

func _init_settings():
	for action : StringName in InputMap.get_actions():
		if not action.contains("ui_"): # Hide built-in actions
			var act = InputMap.action_get_events(action).front()
			if act is InputEventKey:
				default_input[ action ] = ["keyboard",	act.as_text_physical_keycode()]
			elif act is InputEventMouseButton:
				default_input[ action ] = ["mouse",		act.get_button_index()]
			else:
				push_error("invalid key")

func save_settings():
	var file = FileAccess.open("user://" + user_config, FileAccess.WRITE)
	var settings := {}
	var user_input := {}
	for action : StringName in InputMap.get_actions():
		if not action.contains("ui_"): # Hide built-in actions
			var act = InputMap.action_get_events(action).front()
			if act is InputEventKey:
				user_input[ action ] = ["keyboard",		act.as_text_physical_keycode()]
			elif act is InputEventMouseButton:
				user_input[ action ] = ["mouse",		act.get_button_index()]
			else:
				push_error("invalid key")
	settings["INPUT"] = user_input
	
	var json_string = JSON.stringify(settings,"\n")
	#file.store_line(json_string)
	file.store_pascal_string(json_string)
	print("Saved user settings.")
	
func load_settings(defaults := false):
	var user_input : Dictionary = default_input
	if not defaults:
		if FileAccess.file_exists("user://" + user_config):
			print("Loading saved user settings")
			var file = FileAccess.open("user://" + user_config, FileAccess.READ)
			#var json_string = file.get_line()
			var json_string = file.get_pascal_string()
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if not parse_result == OK:
				print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			else:
				var settings : Dictionary = json.get_data()
				user_input.clear()
				user_input = settings["INPUT"]
		else:
			print("Loading default user settings")
		
	for action in user_input:
		var my_action : InputEvent
		if user_input[ action ].front() == "mouse":
			my_action = InputEventMouseButton.new()
			my_action.set_button_index( 				user_input[ action ].back() )
		elif user_input[ action ].front() == "keyboard": 
			my_action = InputEventKey.new()
			my_action.set_physical_keycode( 			OS.find_keycode_from_string( user_input[ action ].back() ) )
		else:
			push_error("invalid key")
		InputMap.action_erase_events(action)
		InputMap.action_add_event( action, my_action )
	update_inputs.emit()
