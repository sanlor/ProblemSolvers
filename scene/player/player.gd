extends Node2D
class_name Player

enum{STANDING, HURT, FLYING}
var curr_state = STANDING :
	set(state):
		curr_state = state
		print(self,": changed state to %s ." % curr_state)
## STANDING - Walking, stopped, shooting
## HURT - Being hurt, exploded and bouncing off walls
## FLYING - Using jetpack (TODO)

@onready var camera_2d = $Camera2D

@onready var pivot = $pivot
@onready var line = $pivot/line
@onready var aim_reticle = $pivot/aim_reticle

@onready var land_check = $main_sprite/land_check
@onready var near_land_check = $main_sprite/near_land_check
@onready var wall_right_check = $main_sprite/wall_right_check
@onready var near_wall_right_check = $main_sprite/near_wall_right_check
@onready var wall_left_check = $main_sprite/wall_left_check
@onready var near_wall_left_check = $main_sprite/near_wall_left_check

@onready var ceiling_check : Marker2D  = $main_sprite/ceiling_check
@onready var near_ceiling_check : Marker2D = $main_sprite/near_ceiling_check


@onready var bullet_origin = $pivot/bullet_origin

@onready var main_sprite 		= $main_sprite
@onready var weapon_sprite 		= $pivot/weapon

@onready var ui = $UI
@onready var player_name = $player_name
@onready var life_bar = $UI/life_bar

@onready var audio_stream_player : AudioStreamPlayer = $AudioStreamPlayer

@onready var world_node : Node2D = Global.world_node
@onready var weapons := Weapons.new()

## Player Data
@export var life := 200.0 :
	set(l):
		life = l
		_update_life_bar()
@export var speed = 200
@export var jump_speed = 300
@export var gravity = 10
@export var terminal_speed := 1000.0
@export var knockback_force := 50
@export var vertical_bounce_damp := 2.0
@export var horizontal_bounce_damp := 2.0
@export_range(0.0, 1.0) var friction = 0.1
@export_range(0.0 , 1.0) var acceleration = 0.05

@export var current_loadout : Array[Weapons.ID] = []
@export var user_network_id := 1

@export var collision_rect : Rect2
@export var i_frame := 0.1 ## I frames for being hurt / exploded. maybe unnecessary.
var curr_i_frame := 0.0
@export var recovery_time := 5.0 ## When you are HURT and stopped moving, how long should you stay in the HURT state?
var curr_recovery_time := 0.0

var curr_team : int
var curr_player_name := ""
var current_weapon : Weapons
#var weapon_cooldown := 0.1 # Temp
var current_cooldown := 0.0

var curr_weapon_sprite : Texture2D :
	set(text):
		curr_weapon_sprite = text
		if curr_weapon_sprite != null:
			weapon_sprite.texture = curr_weapon_sprite

var is_in_focus := true
var has_touched_ground := false # Used by the hit detection
		
var velocity := Vector2.ZERO :
	set(vel):
		velocity = vel.clamp( Vector2(-terminal_speed,-terminal_speed), Vector2(terminal_speed,terminal_speed) )
var dir : float

func _ready():
	camera_2d.enabled = is_multiplayer_authority()
	setup_camera()
	
	# hide these for other players
	if not is_multiplayer_authority():
		line.visible 			= false
		aim_reticle.visible 	= false
	else:
		load_weapon_data( current_loadout.front() )
		player_name.visible = false
		life_bar.max_value 	= life
		life_bar.value 		= life
		ui.visible = true
		
	apply_cosmetics()
	
func _enter_tree():
	set_multiplayer_authority( user_network_id )
	name = str( "player_",user_network_id )
	
	if is_multiplayer_authority():
		Global.player_is_spawned = true

func _exit_tree():
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		#if multiplayer.multiplayer_peer.has_multiplayer_peer():
		if is_multiplayer_authority():
			Global.player_is_spawned = false

func _update_life_bar():
	life_bar.value = life
	pass

func apply_cosmetics():
	if MultiplayerLobby.players_connected.has( user_network_id ):
		main_sprite.modulate = MultiplayerLobby.players_connected[user_network_id][MultiplayerLobby.COLOR]
		curr_player_name = MultiplayerLobby.players_connected[user_network_id][MultiplayerLobby.NAME]
		curr_team = MultiplayerLobby.players_connected[user_network_id][MultiplayerLobby.TEAM]
		
		if curr_team != MultiplayerLobby.player_data[MultiplayerLobby.TEAM]:
			player_name.modulate = Color.ORANGE_RED
		else:
			player_name.modulate = Color.SEA_GREEN
	else:
		push_warning("missing player data")

func _shoot_weapon():
	if not current_loadout.is_empty():
		var bullet_direction : Vector2 = pivot.global_position.direction_to( get_global_mouse_position() )
		if current_weapon.is_hitscan:
			## Damage is instant
			## RPC ## shooting creates a hitscan request.
			world_node.hitscan.rpc_id(1, bullet_origin.global_position, bullet_direction, current_weapon.fire_range, current_weapon.blast_radius, current_weapon.projectile_sound, current_weapon.damage)
		else:
			## RPC ## shooting creates a projectile.
			world_node.create_projectile.rpc_id(1, current_weapon.weapon_id, bullet_origin.global_position, bullet_origin.global_position.direction_to( get_global_mouse_position() ))
		
		_play_sfx		( current_weapon.trigger_sound )
		_apply_recoil	( bullet_direction, current_weapon.recoil_force )
		
	else:
		push_warning("no weapons")

func check_if_is_in_range(pos : Vector2, radius : float) -> bool:
	if global_position.distance_to(pos) < radius / 1.8:
		return true
	else:
		return false

func _play_sfx( type : SoundEffect.TYPE ):
	if audio_stream_player.is_playing():
		audio_stream_player.stop()
	audio_stream_player.stream = SoundEffect.DATA[ type ]
	audio_stream_player.play()

func _update_line():
	if is_in_focus:
		pivot.look_at( get_global_mouse_position() )

func _user_input():
	# Cant move while hurt
	if curr_state != HURT:
		dir = Input.get_axis("walk_left", "walk_right")
		if dir != 0:
			velocity.x = lerp(velocity.x, dir * speed, acceleration)
		else:
			velocity.x = lerp(velocity.x, 0.0, friction)
			
		if Input.is_action_pressed("shoot") and not current_loadout.is_empty():
			if current_cooldown <= 0.0:
				_shoot_weapon()
				current_cooldown = current_weapon.firerate
				
		if Input.is_action_just_pressed("change_weapon"):
			change_weapon()
		
func change_weapon():
	current_loadout.push_back( current_loadout.pop_front() )
	load_weapon_data( current_loadout.front() )
	
func load_weapon_data(id : Weapons.ID):
	current_cooldown 	= weapons.DATA[id].firerate
	curr_weapon_sprite 	= weapons.DATA[id].sprite
	current_weapon = weapons.DATA[id]


func _cooldown( delta ):
	if current_cooldown > 0.0:
		current_cooldown -= 1.0 * delta
		
	if curr_i_frame >= 0.0:
		curr_i_frame -= 1 * delta

func apply_damage(direction : Vector2, recoil : float, amount : float):
	if curr_i_frame <= 0.0:
		has_touched_ground = false
		_apply_recoil( direction, recoil, true )
		life -= amount
		curr_i_frame = i_frame
		curr_state = HURT
	else:
		print("iframe")

func _apply_recoil(direction : Vector2, recoil : float, force : bool = false):
	# Apply a inverted force to the player
	if force:
		velocity = ( direction * -1 ) * (recoil / 4)
		#velocity.y -= knockback_force
		print(velocity," ",recoil)
	else:
		velocity += ( direction * -1 ) * (recoil)

func _collision_check( ):
	var is_near_land 			: bool = world_node.is_pixel_set( near_land_check.global_position )
	var is_in_land 				: bool = world_node.is_pixel_set( land_check.global_position )
	
	var is_near_ceiling 		: bool = world_node.is_pixel_set( near_ceiling_check.global_position )
	var is_in_ceiling 			: bool = world_node.is_pixel_set( ceiling_check.global_position )
	
	var is_near_wall_right 		: bool = world_node.is_pixel_set( near_wall_right_check.global_position )
	var is_in_wall_right 		: bool = world_node.is_pixel_set( wall_right_check.global_position )
	
	var is_near_wall_left 		: bool = world_node.is_pixel_set( near_wall_left_check.global_position )
	var is_in_wall_left 		: bool = world_node.is_pixel_set( wall_left_check.global_position )

	## VERTICAL
	if is_near_land:
		if curr_i_frame <= 0.0: # after i frames has passed
			has_touched_ground = true
			
		if curr_state == HURT: ## friction while being HURT and draggin on the terrain
			## slowdown the player if its touching the ground
			## TODO apply some effect, like smoke
			velocity = velocity.bounce( Vector2(0,1) ) / vertical_bounce_damp
				
		else:
			if velocity.y > 0.0:
				velocity.y = 0.0
				
			if Input.is_action_just_pressed("jump") and is_multiplayer_authority(): ## PLACEHOLDER
				velocity.y -= jump_speed
			
			if is_in_land:
				#while world_node.is_pixel_set( land_check.global_position ):
					position.y -= 1
					
	elif is_near_ceiling:
		if curr_state == HURT:
			velocity = velocity.bounce( Vector2(0,1) ) / vertical_bounce_damp
		elif velocity.y < 0.0:
			velocity.y = -velocity.y # Bounce when hitting the ceiling
			
		if is_in_ceiling:
			#while world_node.is_pixel_set( ceiling_check.global_position ):
				position.y += 1
	# If not standing on something, apply gravity
	else:
		velocity.y += gravity
	
	## HORIZONTAL
	if is_near_wall_right and not is_near_wall_left:
		if curr_state == HURT:
			velocity = velocity.bounce( Vector2(1,0) ) / horizontal_bounce_damp
			
		elif velocity.x > 0.0:
			velocity.x = 0.0
			
		if is_in_wall_right:
			#while world_node.is_pixel_set( wall_right_check.global_position ):
				position.x -= 1
				
	elif is_near_wall_left and not is_near_wall_right:
		if curr_state == HURT:
			velocity = velocity.bounce( Vector2(-1,0) ) / horizontal_bounce_damp
		
		elif velocity.x < 0.0:
			velocity.x = 0.0
			
		if is_in_wall_left:
			#while world_node.is_pixel_set( wall_left_check.global_position ):
				position.x += 1
				
	if is_near_wall_left and is_near_wall_right: ## DEBUG
		print("sandwich")

	
func _update_animation():
	# if dir == 0, do nothing
	if dir > 0.0:
		main_sprite.flip_h = false
	elif dir < 0.0:
		main_sprite.flip_h = true
	
	# adjust the weapon sprite
	if global_position.direction_to( get_global_mouse_position() ).x > 0.0:
		weapon_sprite.flip_v = false
	else:
		weapon_sprite.flip_v = true

func _notification(what):
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		is_in_focus = false
	elif what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
		is_in_focus = true

func _process( delta ):
	if global_position.y >= Global.game_area.end.y:
		Global.emit_signal( "player_death", multiplayer.get_unique_id() )
		print(self," is dead (OOB) ",global_position.abs())
		queue_free()
	
	if multiplayer.multiplayer_peer == null:
		#disconnected from server
		queue_free() 
		
	elif is_multiplayer_authority():
		_user_input()
		_update_animation()
		_update_line()
		_cooldown( delta )
		_collision_check( )
		
		#print(velocity)
		position += velocity * delta ## Apply velocity after all calculations.
		
		if curr_state == HURT:
			# firction applied by the _collision_check().
			#print(velocity.length())
			if velocity.length() < 0.25 and velocity.y < 0.0 and has_touched_ground: ## 1 is TEMP
				curr_state = STANDING ## TODO improve this. players can recover midair
		
		
	player_name.text = curr_player_name
	$player_DEBUG.text = str(curr_state)

func setup_camera():
	camera_2d.limit_bottom	 = Global.map_size.y
	camera_2d.limit_right	 = Global.map_size.x
