extends Projectile

@onready var main_sprite = $main_sprite
@onready var particles = $particles
@onready var collision_checker = $collision_checker

var weapon_data : Weapons
var direction := Vector2.ZERO
var running := true

var my_sprite : Texture2D
var my_max_speed : float
var my_accel : float
var my_blast_radius : int
var my_sfx : SoundEffect.TYPE
var my_damage : float

var my_velocity := 0.0
var world_node : Node2D

var weapons : Weapons

func _ready():
	world_node = Global.world_node
	main_sprite.texture = my_sprite

func _enter_tree():
	name = str( "projectile" )

func set_direction( dir : Vector2 ):
	direction = dir
	look_at( direction + global_position )

func set_weapon( weapon_id : Weapons.ID ):
	weapons = Weapons.new()
	weapon_data = weapons.DATA[weapon_id]
	my_sprite = weapon_data.projectile_sprite
	my_max_speed = weapon_data.projectile_speed
	my_accel = weapon_data.projectile_accel
	my_blast_radius = weapon_data.blast_radius
	my_sfx = weapon_data.projectile_sound
	my_damage = weapon_data.damage
	
	
func _check_collision():
	if world_node.is_colliding_with_something( collision_checker.global_position ):
		_explode()
		
func _explode():
	world_node.create_explosion.rpc_id(1, global_position, my_blast_radius, my_sfx, my_damage)
	
	# Hide the node while the animation finishes.
	main_sprite.visible = false
	running = false
	particles.emitting = false
	
	# Wait for the particles to die off.
	await get_tree().create_timer(2).timeout
	queue_free()
	
func _physics_process(delta):
	if running:
		_check_collision()
		my_velocity += my_accel
		my_velocity = clampf(my_velocity,0, my_max_speed)
		position += transform.x * my_velocity * delta

func _on_lifetime_timeout():
	_explode()
