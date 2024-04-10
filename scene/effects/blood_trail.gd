extends Sprite2D

@onready var world_node : Node2D = Global.world_node
@onready var gpu_particles_2d = $GPUParticles2D

const BLOOD = preload("res://art/player/blood.png")
const BLOOD_S = preload("res://art/player/blood_s.png")
const BONE_S = preload("res://art/player/bone_s.png")

var velocity := Vector2.ZERO
var direction := Vector2.ZERO
var lifetime := 10.0

func setup(pos : Vector2, dir : Vector2, force : float, is_bone := false):
	position 	= pos
	direction 	= dir
	velocity 	= dir * (force * 20.0)
	
	if is_bone:
		texture = BONE_S
	elif randi_range(0,9) > 8:
		texture = BLOOD
		gpu_particles_2d.texture = BLOOD
	else:
		texture = BLOOD_S
		gpu_particles_2d.texture = BLOOD_S

func _check_collision():
	if world_node.is_pixel_set(position):
		gpu_particles_2d.emitting = false
		world_node.stain_terrain.rpc_id(1, position, randi_range(2,16)) # request the world to stain the floor. 4 is TEMP
		set_process(false)
		await get_tree().create_timer(2).timeout
		queue_free()

func _process( delta ):
	# apply gravity
	velocity.y += Global.gravity
	position += velocity * delta
	
	_check_collision()
	
	# avoid stale blood flying around
	lifetime -= 1 * delta
	if lifetime <= 0.0:
		gpu_particles_2d.emitting = false
		queue_free()
		

func _on_tree_exiting():
	await gpu_particles_2d.finished
