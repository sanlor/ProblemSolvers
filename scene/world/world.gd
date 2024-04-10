extends Node2D

@onready var rng := RandomNumberGenerator.new()

var PLAYER 		= load("res://scene/player/player.tscn")
const EXPLOSION = preload("res://scene/effects/explosion.tscn")
const BULLET_TRAIL = preload("res://scene/effects/bullet_trail.tscn")

@onready var playground = $playground
@onready var level_texture = $level_texture
@onready var background_texture = $background_texture
@onready var behind_level_texture = $behind_level_texture
@onready var server_update_timer = $server_update_timer

#@onready var ui = $UI
@onready var spawn_screen = $spawn_screen
@onready var connection_screen = $connection_screen

# https://fietkau.blog/2023/generating_terrain_simplex_noise
@export var verbose_logs := false
@export var verbose_network_logs := false
@export var debug_level := false
@export var gen_map := false:
	set(a):
		_generate_map()
		_generate_background()

@export var noise : FastNoiseLite = preload("res://scene/world/world_fastnoise.tres")
@export var frequency := 2.0
@export var fade := 0.5
@export var threshold := 0.0

@onready var map_size : Vector2i
@onready var map_stretch : Vector2i

@export var level_image_format 			:= Image.FORMAT_RGBA8 ## IMPORTANT! Need to have an alpha channel.
@export var level_image_compression 	:= FileAccess.COMPRESSION_FASTLZ ## Check the apply_map_changes() function before changing this.

@export var land_border_color := Color.CHOCOLATE
@export var land_border_size := 0.025
@export var land_color := Color.ORANGE
@export var land_color_variation := 0.5

@export var bg_noise : FastNoiseLite
@export var bg_bottom_color := Color.DARK_BLUE
@export var bg_top_color := Color.SKY_BLUE
@export var bg_color_variation := 0.5
@export var bg_color_step := 0.15

#
var players_in_game := []


## Map Generation
@onready var map_image 	:= Image.new()

var spawn_point_amount := 5
var spawn_point_radius := 30
var spawn_point_floor := Rect2( Vector2.ZERO, Vector2(20,4) )
var spawn_points := Array()

@onready var weapons := Weapons.new()

#effect pooling ## TODO not sure if its needed yet
var bullet_trail_pool 	: Array[Node2D] = []
var explosion_pool 		: Array[Node2D] = []
var blood_trail_pool 	: Array[Node2D] = []

func _init():
	Global.world_node = self

func _ready():
	Global.player_is_in_game = true
	rng.seed		 = Global.game_seed
	map_size		 = Global.map_size
	map_stretch		 = Global.map_stretch
	
	multiplayer.peer_connected.connect(player_joined)
	multiplayer.peer_disconnected.connect(player_left)
	
	multiplayer.server_disconnected.connect( disconnected_from_server )
	server_update_timer.timeout.connect( push_server_changes )
	
	#Global.player_death.connect(add_player)
	#Global.spawn_player.connect(request_add_player)
	#Global.create_projectile.connect(create_projectile)
	Global.player_entered_world.connect(request_add_player)
	Global.begin_game.connect( begin_game )
	
	_title_screen()

# startup, title screen map
func _title_screen():
	_generate_map()
	_generate_background()
	
# server begun hosting or a single player game started.
func begin_game():
	if multiplayer.is_server():
		server_update_timer.start()
		print("server_update_timer started!")
		## force all clients to regenerate the map
		_generate_map.rpc()
		
# player disconnected and the map returned to the default
func stop_game():
	if multiplayer.multiplayer_peer:
		if multiplayer.is_server():
			server_update_timer.stop()
			
	## force all clients to regenerate the map
	_generate_map()
	_generate_background()

# player disconnected and the map returned to the default
func disconnected_from_server():
	for node in playground.get_children():
		node.queue_free()
	
	Global.game_seed = hash( randi() ) #reset game seed
	_generate_map()
	_generate_background()

# function called when a new player joing the current game.
func player_joined( _id : int):
	if multiplayer.is_server():
		Network._update_player_data.rpc_id( _id )

		# Check for all players on the playground right now.
		for node : Node2D in playground.get_children():
			if node is Player:
				#_add_curr_player.rpc_id(_id, node.get_multiplayer_authority() )
				_add_curr_player.rpc_id(_id, node.user_network_id )
				# apply the name, color and such to the player
				node.apply_cosmetics()

# function called when a new player leave an ongoing game.
func player_left( id : int):
	players_in_game.erase( id )
	if multiplayer.is_server():
		_remove_player.rpc( id )

# every X seconds, push the current map and game state to all peers
@rpc("authority","call_remote","reliable",1)
func push_server_changes():
	## Map
	var data := map_image.get_data().compress( level_image_compression )
	if verbose_network_logs:
		print( "SENT: raw image data is ", map_image.get_data().size() / 1e+6,"MB")
		print( "SENT: compressed image data is ",data.size() / 1e+6,"MB")
	apply_map_changes.rpc( data, map_image.get_data().size() )
	apply_spawn_points.rpc( spawn_points )

	

@rpc("authority","call_remote","reliable",1)
func apply_map_changes( remote_data : PackedByteArray, buffer : int):
	if remote_data is PackedByteArray:
		
		var data : PackedByteArray = remote_data.decompress(buffer, level_image_compression)
		if verbose_network_logs:
			print( "RECEIVED: raw image data is ", data.size() / 1e+6,"MB" )
			print( "RECEIVED: compressed image data is ",remote_data.size() / 1e+6,"MB" )
		map_image.set_data(map_size.x, map_size.y, false, level_image_format, data)
		level_texture.texture = ImageTexture.create_from_image( map_image )
	else:
		print("Unexpected data: ", typeof(remote_data) )
		

@rpc("authority","call_remote","reliable",1)
func apply_spawn_points(s : Array):
	spawn_points = s

@rpc("authority","call_local")
func apply_player_changes():
	for id : int in multiplayer.get_peers():
		if Network.players_connected.has(id):
			add_player( id )
		else:
			# something desync'ed.
			breakpoint

#region Multiplayer stuff

	
@rpc("any_peer","call_local")
func _remove_player( id : int ):
	for node : Node2D in playground.get_children():
		if node is Player:
			if node.get_multiplayer_authority() == id:
				node.queue_free()
				return

func request_add_player(id : int):
	rpc_id(1, "add_curr_player", id)

@rpc("any_peer","call_local")
func add_curr_player(id : int):
	if verbose_logs:
		print("SP_Player requested by ", multiplayer.get_remote_sender_id())
	#players_in_game.append( id )
	_add_curr_player.rpc( id )

@rpc("authority","call_local")
func _add_curr_player(id : int):
	add_player(id)
	

func add_player(id : int):
	var point : Vector2 = spawn_points.pick_random()
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
	var bg_image := Image.new()
	bg_image = Image.create(map_size.x, map_size.y, false, level_image_format)
	for x  : float in map_size.x - 1:
		for y  : float in map_size.y - 1:
			#var pixel : float = fade * (y / map_size.y) + (1 - fade) * noise.get_noise_2d( x * frequency, y * frequency ) 
			var variation : float = snapped( ( (y / map_size.y * bg_noise.get_noise_2d( x * frequency, y * frequency) + 1) / 2), bg_color_step )
			
			var color := bg_bottom_color.lerp( bg_top_color, variation )
			@warning_ignore("narrowing_conversion")
			bg_image.set_pixel( x,y,color )
			
	background_texture.texture 	= ImageTexture.create_from_image( bg_image )
	print("_generate_background() took ",Time.get_ticks_msec() - start," msecs.")

@rpc("any_peer","call_local")
func _generate_map():
	var start := Time.get_ticks_msec()
	_cleanup()
	var behind_map := Image.new()
	
	map_image = Image.create(map_size.x, map_size.y, false, level_image_format)
	map_image.fill( Color.TRANSPARENT )
	
	behind_map = Image.create(map_size.x, map_size.y, false, level_image_format)
	behind_map.fill( Color.TRANSPARENT )
	
	level_texture.texture 			= ImageTexture.create_from_image( map_image )
	behind_level_texture.texture 	= ImageTexture.create_from_image( behind_map )
	
	if not debug_level:
		for x  : float in map_size.x - 1:
			for y  : float in map_size.y - 1:
				var transparency : float = fade * (y / map_size.y) + (1 - fade) * noise.get_noise_2d( x * frequency, y * frequency )
				var pixel_color := Color(0,0,0,0)
				var bg_pixel_color := Color(0,0,0,0)
				var selected_color := land_border_color
				
				if transparency + land_border_size >= threshold and transparency - land_border_size >= threshold:
					selected_color = land_color
					
				if transparency >= threshold:
					transparency = 1.0
				else:
					transparency = 0.0
				
				if transparency != 0.0:
					pixel_color = selected_color * ( rng.randf_range(land_color_variation, 1) ) ## Cool effect
					bg_pixel_color = land_color * ( rng.randf_range(land_color_variation, 1) ) ## Cool effect
					
				@warning_ignore("narrowing_conversion")
				map_image.set_pixel( x,y,Color(pixel_color, transparency) )
				@warning_ignore("narrowing_conversion")
				behind_map.set_pixel( x,y,Color(bg_pixel_color / 2, transparency) ) # a darker color for the back of the level
				
	else:
		@warning_ignore("integer_division")
		for x  : float in map_size.x - 1:
			@warning_ignore("integer_division")
			for y  : float in (map_size.y - 1) / 2:
				@warning_ignore("narrowing_conversion")
				var pixel_color = land_color * ( rng.randf_range(land_color_variation, 1) ) ## Cool effect
				@warning_ignore("narrowing_conversion")
				@warning_ignore("integer_division")
				map_image.set_pixel( x,y + (map_size.y / 2),Color(pixel_color, 1.0) )
			
	map_image.resize(map_size.x * map_stretch.x, map_size.y * map_stretch.y, Image.INTERPOLATE_NEAREST)
	behind_map.resize(map_size.x * map_stretch.x, map_size.y * map_stretch.y, Image.INTERPOLATE_NEAREST)
	
	_generate_spawn_points()
	if multiplayer.multiplayer_peer:
		if multiplayer.is_server():
			push_server_changes()

	level_texture.texture.update( map_image )
	behind_level_texture.texture.update( behind_map )
	
	print("_generate_map() took ",Time.get_ticks_msec() - start," msecs.")
	
@rpc("any_peer","call_local")
func get_spawn_point() -> Vector2:
	return spawn_points.pick_random()
	
@rpc("any_peer","call_local")
func _generate_spawn_points():
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
				
				map_image.set_pixel(new_x ,new_y,Color.PINK )
			#	map_bitmap.set_bit(new_x ,new_y,true)
			
@rpc("any_peer","call_local","reliable")
func hitscan(source : Vector2, dir : Vector2, my_range : int, radius : int, sfx : SoundEffect.TYPE, damage : float):
	if verbose_logs:
		print("Hitscan requested by ", multiplayer.get_remote_sender_id())
	_hitscan.rpc(source, dir, my_range, radius, sfx, damage)
	
	if multiplayer.is_server():
		_hitscan(source, dir, my_range, radius, sfx, damage)
	
#@rpc("authority","call_local","reliable")
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

#@rpc("authority","call_local","reliable")
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
				if Global.game_area.has_point( Vector2i(new_x,new_y) ):
					map_image.set_pixel(new_x,new_y,Color(0,0,0,0))
	#level_texture.texture = ImageTexture.create_from_image( map_image )
	level_texture.texture.update( map_image )
	
@rpc("any_peer","call_local","reliable")
func stain_terrain(pos : Vector2, radius : int):
	_stain_terrain.rpc(pos, radius)
	
@rpc("authority","call_local","reliable")
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
						map_image.set_pixel(new_x,new_y, curr_pixel.lerp(Color.RED, randf_range(0.25,0.75) ) )
						
	level_texture.texture.update( map_image )
	
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
		if map_image.get_pixelv(pos).a != 0.0:
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
	
#func toggle_menu(): ## TODO
	#spawn_screen.visible = not spawn_screen.visible
	#
#func _input(event):
	#if event is InputEvent:
		#if event.is_action_pressed("menu") and multiplayer.multiplayer_peer:
			#toggle_menu()
