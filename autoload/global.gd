@tool
extends Node

const map_size 			:= Vector2(800, 600)
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

enum GAME_STATE{CONNECTION,SPAWN,IN_GAME}
var curr_GAME_STATE = GAME_STATE.CONNECTION : 
	set(state):
		curr_GAME_STATE = state
		game_state_changed.emit( curr_GAME_STATE )
		#print("Changed game state to ", GAME_STATE.keys()[ curr_GAME_STATE ])

## Signals
signal game_state_changed (state : GAME_STATE)
signal show_connection_screen # force open the connection screen in case of a disconnection or pressing ESC
signal show_spawn_screen

signal begin_game # Headless server wants to start the game

signal player_entered_world( player_id : int) ## called by the UI

signal player_death( player_id )
signal spawn_player( player_id )
signal create_projectile (weapon_data : Weapons, initial_position : Vector2, initial_direction : float)
