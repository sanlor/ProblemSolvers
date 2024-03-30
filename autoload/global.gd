extends Node

const map_size 			:= Vector2(800, 600)
const map_stretch 		:= Vector2( 1,1 )
const game_area 		:= Rect2(Vector2.ZERO, map_size)

var world_node 			: Node2D
var playground_node 	: Node2D
var game_seed 			:= hash("poop")

var player_is_in_game := false
var player_is_spawned 	:= false :
	set(a):
		player_is_spawned = a
		print("player spawned ", player_is_spawned)

## Signals
signal player_death( player_id )
signal spawn_player( player_id )
signal create_projectile (weapon_data : Weapons, initial_position : Vector2, initial_direction : float)
