extends Node2D

enum DATA{SEED, MAP_SIZE,}
enum PIXEL{ORIGINAL,CHANGED} # used by map_image_mask 
@onready var rng := RandomNumberGenerator.new()

var PLAYER 		= load("res://scene/player/player.tscn")
const EXPLOSION = preload("res://scene/effects/explosion.tscn")
const BULLET_TRAIL = preload("res://scene/effects/bullet_trail.tscn")

@onready var playground = $playground

## Textures
@onready var level_texture = $level_texture
@onready var background_texture = $background_texture
@onready var behind_level_texture = $behind_level_texture
@onready var strut_level_texture = $strut_level_texture
@onready var effects_level_texture = $effects_level_texture

@onready var server_update_timer = $server_update_timer

#@onready var ui = $UI
@onready var spawn_screen = $spawn_screen
@onready var connection_screen = $connection_screen

@onready var map_size : Vector2i
@onready var map_stretch : Vector2i

# https://fietkau.blog/2023/generating_terrain_simplex_noise
@export_category("Debug")
@export var verbose_logs := false
@export var verbose_network_logs := false
@export var debug_process_time := false
@export var debug_level := false
@export var gen_map := false:
	set(a):
		_generate_initial_map()
		_generate_background()
		
@export_category("Level Gen")
@export var noise : FastNoiseLite = preload("res://scene/world/world_fastnoise.tres")
@export var frequency := 2.0
@export var fade := 0.5
@export var threshold := 0.0

@export var level_image_format 			:= Image.FORMAT_RGBA8 ## IMPORTANT! Need to have an alpha channel.

@export_category("Network")
@export var level_image_mask_format 	:= Image.FORMAT_R8
@export var level_image_compression 	:= FileAccess.COMPRESSION_FASTLZ ## Check the apply_map_changes() function before changing this.

@export_category("Terrain")
@export var land_border_color := Color.CHOCOLATE
@export var land_border_size := 0.025
@export var land_color := Color.ORANGE
@export var land_color_variation := 0.5
@export var land_darkening := 50.0 # When the player digs the terrain

@export_category("Background")
@export var bg_noise : FastNoiseLite
@export var bg_bottom_color := Color.DARK_BLUE
@export var bg_top_color := Color.SKY_BLUE
@export var bg_color_variation := 0.5
@export var bg_color_step := 0.15

var players_in_game := []

## Map Generation
@onready var map_image 				:= Image.new()		# This image is very important. it is the map texture and the collision all in one.
@onready var map_image_strut		:= Image.new()			# This image hold data from the plataforms, rocks and etc.
@onready var map_image_effects		:= Image.new()			# This image hold data for blood effects and etc

@onready var map_image_initial	:= Image.new() # this mask is used by the server to send the current map to the peers. This hold the initial map shape. Used to make the background
@onready var map_image_mask 		:= PackedByteArray() # this mask is used by the server to send the current map to the peers. this should be a 1 bit depth image and CHANGED frequently



var spawn_point_amount := 5
var spawn_point_radius := 30
var spawn_point_floor := Rect2( Vector2.ZERO, Vector2(20,4) )
var spawn_points := []

@onready var weapons := Weapons.new()

#effect pooling ## TODO not sure if its needed yet
var bullet_trail_pool 	: Array[Node2D] = []
var explosion_pool 		: Array[Node2D] = []
var blood_trail_pool 	: Array[Node2D] = []

func _init():
	Global.world_node = self

func _ready():
	Global.player_is_in_game = true

	_load_server_settings(Global.game_seed, Global.map_size, [])
	
	multiplayer.peer_connected.connect(player_joined)
	multiplayer.peer_disconnected.connect(player_left)
	
	multiplayer.server_disconnected.connect( disconnected_from_server )
	server_update_timer.timeout.connect( push_server_data )
	
	#Global.player_death.connect(add_player)
	#Global.spawn_player.connect(request_add_player)
	#Global.create_projectile.connect(create_projectile)
	Global.player_entered_world.connect(request_add_player)
	Global.begin_game.connect( begin_game )
	
	_title_screen()

func _load_server_settings(_seed : int, _size : Vector2, _sp : Array):
	rng.seed		 = _seed
	map_size		 = _size
	spawn_points	 = _sp
	rng.set_state( 0 )
	
# startup, title screen map
func _title_screen():
	rng.seed = randi()
	noise.seed = randi()
	rng.set_state( 0 )
	
	_generate_initial_map()
	#_generate_background()
	
# server begun hosting or a single player game started.
func begin_game():
	if multiplayer.is_server():
		server_update_timer.start()
		#print("server_update_timer started!")
		## force all clients to regenerate the map
		if multiplayer.is_server():
			#_generate_map.rpc()
			_generate_initial_map() # server makes a map, push its map to the peers after ## FIXME
			
		
# player disconnected and the map returned to the default
func stop_game():
	if multiplayer.multiplayer_peer:
		if multiplayer.is_server():
			server_update_timer.stop()
			
	## force all clients to regenerate the map
	_generate_initial_map()
	#_generate_background()

# player disconnected and the map returned to the default
func disconnected_from_server():
	for node in playground.get_children():
		node.queue_free()
	
	Global.game_seed = hash( randi() ) #reset game seed
	_generate_initial_map()
	#_generate_background()

# function called when a new player joing the current game.
func player_joined( _id : int):
	if multiplayer.is_server():
		Network._update_player_data.rpc_id( _id )
		push_initial_server_data( _id )
		# Check for all players on the playground right now.
		for node : Node2D in playground.get_children():
			if node is Player:
				#_add_curr_player.rpc_id(_id, node.get_multiplayer_authority() )
				_add_curr_player.rpc_id(_id, node.user_network_id, node.position )
				# apply the name, color and such to the player
				node.apply_cosmetics()

# function called when a new player leave an ongoing game.
func player_left( id : int):
	players_in_game.erase( id )
	if multiplayer.is_server():
		_remove_player.rpc( id )

# When a user connect to a server, the server push all its current data to the client.
func push_initial_server_data(player_id):
	var data := [
		Global.game_seed, Global.map_size, 
		map_image_mask.compress( level_image_compression ), # The current map state				## REGULAR UPDATE
		map_image_initial.get_data().compress( level_image_compression ), # The initial map state		## ONETIME
		map_image_effects.get_data().compress( level_image_compression ), # Blood effects					## ONETIME
		map_image_strut.get_data().compress( level_image_compression ), # Plataforms, rockes, etc			## ONETIME
		spawn_points																						## ONETIME
		]
		
	if verbose_network_logs:
		print( "INITIAL SENT: raw image data is ", ( map_image_mask.size() + map_image_initial.get_data().size() + map_image_effects.get_data().size() + map_image_strut.get_data().size() ) / 1e+6," MB")
		print( "INITIAL SENT: compressed image data is ",(data[2].size() + data[3].size() + data[4].size() + data[5].size()) / 1e+6," MB")
		
	apply_initial_server_data.rpc_id(player_id, data)
	
# this func applies data pushed from the server.
@rpc("authority","call_remote")
func apply_initial_server_data( data : Array ):
	Global.notification_receiving_server_data.emit()
	var map_data 		: PackedByteArray = data[2].decompress(10000000, level_image_compression)
	var init_map_data 	: PackedByteArray = data[3].decompress(10000000, level_image_compression)
	var fx_map_data 	: PackedByteArray = data[4].decompress(10000000, level_image_compression)
	var strut_map_data 	: PackedByteArray = data[5].decompress(10000000, level_image_compression)
	
	#map_image_mask.set_data				(map_size.x, map_size.y, false, level_image_mask_format, map_data)
	map_image_mask =					map_data
	map_image_initial.set_data			(map_size.x, map_size.y, false, level_image_mask_format, init_map_data)
	map_image_effects.set_data			(map_size.x, map_size.y, false, level_image_format, fx_map_data)
	map_image_strut.set_data			(map_size.x, map_size.y, false, level_image_format, strut_map_data)
	
	if verbose_network_logs:
		print( "INITIAL RECEIVED: raw image data is ", (map_data.size() + init_map_data.size() + fx_map_data.size() + strut_map_data.size()) / 1024," KB - ", (map_data.size() + init_map_data.size() + fx_map_data.size() + strut_map_data.size()) )
		print( "INITIAL RECEIVED: compressed image data is ",(data[2].size() + data[3].size() + data[4].size() + data[5].size()) / 1024," KB - ", (data[2].size() + data[3].size() + data[4].size() + data[5].size()) )
		
	_load_server_settings(data[0], data[1], data[6])
	_client_load_map() ## RPC?
	Global.server_data_received.emit()
	Global.notification_received_server_data.emit()
	
# every X seconds, push the current map and game state to all peers
func push_server_data():
	var data := [
		map_image_mask.compress( level_image_compression ), # The current map state				## REGULAR UPDATE
		]
	if verbose_network_logs:
		print( "SENT: raw image data is ",float(map_image_mask.size()) / 1024," KB")
		print( "SENT: compressed image data is ",float(data[0].size()) / 1024," KB")
		
	apply_server_data.rpc(data)
	
	
@rpc("authority","call_remote")
func apply_server_data( data : Array ):
	var map_data : PackedByteArray = data[0].decompress(10000000, level_image_compression)
	#map_image_mask.set_data(map_size.x, map_size.y, false, level_image_mask_format, map_data)
	map_image_mask = map_data
	if verbose_network_logs:
		print( "RECEIVED: raw image data is ", float(map_data.size()) / 1024," KB")
		print( "RECEIVED: compressed image data is ",float(data[0].size()) / 1024," KB")
		
	level_texture.texture = ImageTexture.create_from_image( map_image ) ## Apply the texture right now!


#region Multiplayer stuff
@rpc("any_peer","call_local")
func _remove_player( id : int ):
	for node : Node2D in playground.get_children():
		if node is Player:
			if node.get_multiplayer_authority() == id:
				node.queue_free()
				return

func request_add_player(id : int):
	rpc_id(1, "add_curr_player", id, spawn_points.pick_random())

@rpc("any_peer","call_local")
func add_curr_player(id : int, point : Vector2):
	if verbose_logs:
		print("SP_Player requested by ", multiplayer.get_remote_sender_id())
	_add_curr_player.rpc( id, point )

@rpc("authority","call_local")
func _add_curr_player(id : int, point : Vector2):
	add_player(id, point)
	

func add_player(id : int, point):
	#var point : Vector2 = Vector2(400,200)
	var player : Node2D = PLAYER.instantiate()
	
	player.user_network_id = id 
	player.global_position = point
	if verbose_logs:
		print("player created with id ",id," by ",multiplayer.get_unique_id())
	playground.add_child( player, true )
	
func request_disconnect():
	multiplayer.multiplayer_peer.close()
	#get_tree().change_scene_to_packed( MAIN_MENU )

#endregion

## Map setup
func _cleanup():
	spawn_points.clear()

# This function should be called rarelly.
func _generate_background():
	var start := Time.get_ticks_msec()
	# Drawing via script is pretti fun
	bg_noise.seed = randi()
	var bg_image := Image.new()
	bg_image = Image.create(map_size.x, map_size.y, false, level_image_format)
	for x  : float in map_size.x - 1:
		for y  : float in map_size.y - 1:
			var variation : float = snapped( ( (y / map_size.y * bg_noise.get_noise_2d( x * frequency, y * frequency) + 1) / 2), bg_color_step )
			var color := bg_bottom_color.lerp( bg_top_color, variation )
			@warning_ignore("narrowing_conversion")
			bg_image.set_pixel( x,y,color )
			
	background_texture.texture 	= ImageTexture.create_from_image( bg_image )
	if debug_process_time:
		print("_generate_background() took ",Time.get_ticks_msec() - start," msecs.")

@rpc("any_peer","call_local")
func _generate_initial_map(): ## generate the map when a player joins or a match starts
	Global.notification_level_generating.emit()
	await get_tree().process_frame # update loading screen
	_cleanup()
	var start := Time.get_ticks_msec()
	
	# init array
	map_image_mask.resize(map_size.x * map_size.y)
	map_image_mask.fill( PIXEL.ORIGINAL )
	
	map_image_initial = Image.create(map_size.x, map_size.y, false, level_image_mask_format)
	map_image_initial.fill( Color(0.0, 0.0, 0.0, 0.0) )
	
	map_image_effects 		= Image.create(map_size.x, map_size.y, false, level_image_format)
	map_image_effects.fill( Color(0.0, 0.0, 0.0, 0.0) )
	
	map_image_strut 	= map_image_effects.duplicate()
	
	for x  : float in map_size.x - 1:
		for y  : float in map_size.y - 1:
			var transparency : float = fade * (y / map_size.y) + (1 - fade) * noise.get_noise_2d( x * frequency, y * frequency )
				
			if transparency + land_border_size >= threshold and transparency - land_border_size >= threshold:
				transparency = 0.5
			elif transparency >= threshold:
				transparency = 1.0
			else:
				transparency = 0.0
				
			@warning_ignore("narrowing_conversion")
			map_image_initial.set_pixel( x,y,Color(transparency, 0, 0) )
			
	if debug_process_time:
		print("_generate_initial_map() took ",Time.get_ticks_msec() - start," msecs.")
			
	await get_tree().process_frame # update loading screen
	_generate_background()
	await get_tree().process_frame # update loading screen
	Global.notification_level_loading.emit()
	_client_load_map() ## Server side level load
	await get_tree().process_frame # update loading screen
	Global.notification_level_loaded.emit()
	_generate_spawn_points()
	await get_tree().process_frame # update loading screen

	
@rpc("any_peer","call_local")
func _client_load_map():
	var start := Time.get_ticks_msec()
	
	var behind_map := Image.new()
	
	map_image = Image.create(map_size.x, map_size.y, false, level_image_format)
	map_image.fill( Color(0.0, 0.0, 0.0, 0.0) )
	
	behind_map = Image.create(map_size.x, map_size.y, false, level_image_format)
	behind_map.fill( Color(0.0, 0.0, 0.0, 0.0) )
	
	level_texture.texture 			= ImageTexture.create_from_image( map_image )
	behind_level_texture.texture 	= ImageTexture.create_from_image( behind_map )
	
	for x  : float in map_size.x - 1:
		for y  : float in map_size.y - 1:
			@warning_ignore("narrowing_conversion")
			var transparency 		: float	= map_image_initial.get_pixel( x, y ).r # Should return 1.0, 0.5 or 0.0
			@warning_ignore("narrowing_conversion")
			var bg_transparency 	: int	= ceili( map_image_initial.get_pixel( x, y ).r ) # Should return 1.0, 0.5 or 0.0
			
			## Mask check
			if map_image_mask[ Tool.pos_to_id( Vector2(x,y) ) ] == PIXEL.CHANGED:
				transparency = 0.0
			
			var pixel_color 	:= Color(0,0,0)
			var bg_pixel_color 	:= Color(0,0,0)
			var selected_color 	:= land_border_color
			var alpha 			:= 0.0
			var bg_alpha 		:= 0.0
			
			if transparency < 0.75 and transparency > 0.25: ## stupid floats. 0.5 != 0.49999999
				selected_color = land_color
				alpha = 1.0
				
			if transparency > 0.0:
				pixel_color = selected_color * ( rng.randf_range(land_color_variation, 1) ) ## Cool effect
				alpha = 1.0
				
			if bg_transparency != 0.0:
				bg_pixel_color = land_color * ( rng.randf_range(land_color_variation, 1) ) ## Cool effect
				bg_alpha = 1.0

				
			@warning_ignore("narrowing_conversion")
			map_image.set_pixel( x,y, Color(pixel_color, alpha) )
			@warning_ignore("narrowing_conversion")
			behind_map.set_pixel( x,y, Color(bg_pixel_color.darkened( land_darkening ), bg_alpha) ) # a darker color for the back of the level
			
	await get_tree().process_frame # update loading screen
	effects_level_texture.texture 			= ImageTexture.create_from_image( map_image_effects )
	strut_level_texture.texture 			= ImageTexture.create_from_image( map_image_strut )
	level_texture.texture 					= ImageTexture.create_from_image( map_image )
	behind_level_texture.texture 			= ImageTexture.create_from_image( behind_map )
	
	if debug_process_time:
		print("_client_load_map() took ",Time.get_ticks_msec() - start," msecs.")
	
func _generate_spawn_points(): ## FIXME 
	for n in spawn_point_amount:
		# get a random point
		var point := Vector2i( rng.randi_range(0 + spawn_point_radius,map_size.x - spawn_point_radius), rng.randi_range(0 + spawn_point_radius,map_size.y - spawn_point_radius) )
		
		_remove_terrain(point, spawn_point_radius) # carve a radius around the point
		spawn_points.append( point )
		
		# make a floor for the player to stand on
		@warning_ignore("integer_division")
		for x  : int in spawn_point_floor.size.x:
			@warning_ignore("integer_division")
			for y  : int in spawn_point_floor.size.y:
				@warning_ignore("integer_division")
				@warning_ignore("narrowing_conversion")
				var new_x : int = ( point.x + x ) - spawn_point_floor.size.x / 2
				@warning_ignore("integer_division")
				@warning_ignore("narrowing_conversion")
				var new_y : int = ( point.y + y + ( spawn_point_radius / 3) ) - spawn_point_floor.size.y / 2
				
				map_image_strut.set_pixel(new_x ,new_y,Color.PINK )
				
	strut_level_texture.texture 			= ImageTexture.create_from_image( map_image_strut )
	
@rpc("any_peer","call_local","reliable")
func hitscan(source : Vector2, dir : Vector2, my_range : int, radius : int, sfx : SoundEffect.TYPE, damage : float):
	if verbose_logs:
		print("Hitscan requested by ", multiplayer.get_remote_sender_id())
	_hitscan.rpc(source, dir, my_range, radius, sfx, damage)
	
	if multiplayer.is_server():
		_hitscan(source, dir, my_range, radius, sfx, damage)

@rpc("authority","call_remote","reliable")
func _hitscan(source : Vector2, dir : Vector2, my_range : int, radius : int, sfx : SoundEffect.TYPE, damage : float):
	for i in my_range:
		var ray_check : Vector2i = source + (dir * i)
		if is_inside_the_map( ray_check ):
			# check for players on the path of hitscan. if hit, create explosion and stop the scan.
			for node in playground.get_children():
				if node is Player:
					if node.check_if_is_in_range(ray_check, radius):
						_add_bullet_trail(source,ray_check)
						_create_explosion(ray_check, radius, sfx, damage)
						return
						
			# check for terrain hit
			if is_pixel_set( ray_check ):
				_add_bullet_trail(source,ray_check)
				_create_explosion(ray_check, radius, sfx, damage)
				return
				
			elif i == my_range - 1:
				# did not hit anything, create a trail anyway
				_add_bullet_trail(source,ray_check)
		else:
			# Its outside of the map. stop scanning.
			_add_bullet_trail(source,ray_check)
			break
		
			
	if verbose_logs:
		print( "Hitscan created by ", multiplayer.get_unique_id() )

func _add_bullet_trail(source : Vector2, destination : Vector2):
	var trail = BULLET_TRAIL.instantiate()
	playground.add_child(trail,true)
	trail.setup(source,destination)

@rpc("any_peer","call_local","reliable")
func create_projectile(weapon_id : Weapons.ID, initial_position : Vector2, initial_direction : Vector2):
	if verbose_logs:
		print("Rocket requested by ", multiplayer.get_remote_sender_id())
	_create_projectile.rpc( weapon_id, initial_position, initial_direction )
	
	if multiplayer.is_server():
		_create_projectile( weapon_id, initial_position, initial_direction )

@rpc("authority","call_remote","reliable")
func _create_projectile(weapon_id : Weapons.ID, initial_position : Vector2, initial_direction : Vector2):
	var projectile : Node2D = weapons.PROJECTILE_DATA[weapon_id].instantiate() ## PLACEHOLDER
	#projectile.set_multiplayer_authority( user_network_id )
	projectile.set_position( initial_position )
	projectile.set_weapon( weapon_id )
	projectile.set_direction( initial_direction )
	projectile.name = str( hash(initial_position + initial_direction) )
	playground.add_child( projectile, true )
	if verbose_logs:
		print( "Rocket created by ", multiplayer.get_unique_id() )

# every kind of damage can create a explosion.
@rpc("any_peer","call_local","reliable")
func create_explosion(pos : Vector2, radius : int, sfx : SoundEffect.TYPE, damage : float):
	if verbose_logs:
		print("Explosion requested by ", multiplayer.get_remote_sender_id())
	#_create_explosion.rpc(pos, radius, sfx, damage)
	
	if multiplayer.is_server():
		_create_explosion.rpc(pos, radius, sfx, damage)

@rpc("authority","call_local","reliable")
#@rpc("authority","call_remote","reliable")
func _create_explosion(pos : Vector2, radius : float, sfx : SoundEffect.TYPE, damage : float):
	# remove the terrain for the explosion ## TODO support adding terrain back
	_remove_terrain(pos,radius)
	# apply animation to the explosion
	var effect := EXPLOSION.instantiate()
	effect.position = pos
	effect.scale *= (radius / 25.0)
	effect.sfx = sfx
	playground.add_child(effect)
	
	# only the server can apply damage
	if multiplayer.is_server():
		# check for damage
		var players_damaged := [] # players cant be damaged twice in the same explosion
		for node in playground.get_children():
			if node is Player and not players_damaged.has( node ): ## maybe its slow?
				if node.check_if_is_in_range(pos, radius):
					players_damaged.append( node )
					## node.global_position.distance_to( pos ) / radius makes the recoil to be stronger of weaker depending of the distance from the center of the explosion.
					var force = (node.global_position.distance_to( pos ) / radius) *  radius 
					var dir = node.global_position.direction_to( pos )
					node.apply_damage.rpc( dir, force, damage )
					
					if not node.check_health(): # Return true if life is above 0
						#Player is dead, broadcast it to all peers
						node.kill_player.rpc( true )
	if verbose_logs:
		print( "explosion created by ", multiplayer.get_unique_id() )

@rpc("any_peer","call_local","reliable")
func request_death( player_node : Player ):
	player_node.kill_player.rpc( false )
	
# https://stackoverflow.com/questions/4590846/how-do-you-loop-through-a-circle-of-values-in-a-2d-array
func _remove_terrain(pos : Vector2, radius : float):
	var center := Vector2(pos.x, pos.y)
	for x : float in radius:
		for y : float in radius:
			@warning_ignore("narrowing_conversion")
			@warning_ignore("integer_division")
			var new_x : int = pos.x - x + (radius / 2)
			@warning_ignore("narrowing_conversion")
			@warning_ignore("integer_division")
			var new_y : int = pos.y - y + (radius / 2)
			@warning_ignore("integer_division")
			@warning_ignore("narrowing_conversion")
			if center.distance_to( Vector2(new_x,new_y).round() ) < radius / 2:
				if Global.game_area.has_point( Vector2(new_x,new_y).round() ):
					
					map_image.set_pixel				(new_x,new_y,Color(0,0,0,0))
					map_image_effects.set_pixel		(new_x,new_y,Color(0,0,0,0))
					#map_image_mask.set_pixel		(new_x,new_y,Color(0,0,0,0))
					map_image_mask[ Tool.pos_to_id( Vector2(new_x,new_y) ) ] = PIXEL.CHANGED ##TODO
	
	effects_level_texture.texture.update( map_image_effects )
	level_texture.texture.update( map_image )
	
@rpc("any_peer","call_local","reliable")
func stain_terrain(pos : Vector2, radius : int):
	_stain_terrain.rpc(pos, radius)
	
@rpc("authority","call_local","reliable") # server doesnt need these info
func _stain_terrain(pos : Vector2, radius : int): ## after the blood drop hits the floor, it should stain the floor
	for x : float in radius:
		for y : float in radius:
			@warning_ignore("narrowing_conversion")
			@warning_ignore("integer_division")
			var new_x : int = pos.x - x + (radius / 2)
			@warning_ignore("narrowing_conversion")
			@warning_ignore("integer_division")
			var new_y : int = pos.y - y + (radius / 2)
			@warning_ignore("integer_division")
			@warning_ignore("narrowing_conversion")
			if pos.distance_to( Vector2(new_x,new_y).round() ) < radius / 2:
				if Global.game_area.has_point( Vector2(new_x,new_y).round() ):
					var curr_pixel := map_image.get_pixel(new_x,new_y)
					if not is_equal_approx(curr_pixel.a, 0.0): # if the pixel is not transparent, add blood
						map_image_effects.set_pixel(new_x,new_y, curr_pixel.lerp(Color.RED, randf_range(0.25,0.75) ) )
						
	#level_texture.texture.update( map_image )
	effects_level_texture.texture = ImageTexture.create_from_image(map_image_effects)
	
func is_colliding_with_something(pos : Vector2):
	if is_pixel_set(pos):
		return true
	else:
		for node in playground.get_children():
			if node is Player:
				if node.check_if_is_in_range(pos, 5): # 5 is TEMP
					return true
		return false

func is_pixel_set(pos : Vector2) -> bool:
	# check if pos is inside the map. THis avoid errors of OOB get_pixel().
	if Global.game_area.has_point(pos):
		# Transparent means unoccupied. Check if the alpha channel is 0. It should always be 1 or 0
		if map_image.get_pixelv(pos).a != 0.0 or map_image_strut.get_pixelv(pos).a != 0.0:
			return true
		else:
			return false
	## Horizontal map limits are solid
	elif (pos.x >= 0.0 and pos.x <= Global.map_size.x):
		return false
	## bottom is not and lead to death.
	else:
		return true
	
func is_inside_the_map(pos : Vector2) -> bool:
	if (pos.x >= 0.0 and pos.x <= Global.map_size.x) and pos.y <= Global.map_size.y:
		return true
	#return Global.game_area.has_point(pos)
	print("outside")
	return false
