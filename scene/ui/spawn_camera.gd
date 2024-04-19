extends Camera2D

@onready var target = $"../target"

var cam_speed := 350.0

func _ready():
	limit_top = 0
	limit_left = 0
	@warning_ignore("narrowing_conversion")
	limit_bottom = Global.map_size.y
	@warning_ignore("narrowing_conversion")
	limit_right = Global.map_size.x
	
func cam_control(delta):
	if Input.is_action_just_released("camera_zoom_down"):
		zoom -= Vector2(0.25, 0.25)
	if Input.is_action_just_released("camera_zoom_up"): #and get_zoom() > Vector2.ONE:
		zoom += Vector2(0.25, 0.25)
		
	zoom = zoom.clamp( Vector2.ONE, Vector2(10,10))
	
	if not zoom == Vector2.ONE:
		position.y += (Input.get_axis("camera_move_up","camera_move_down") * cam_speed * delta) / zoom.x
		position.x += (Input.get_axis("camera_move_left","camera_move_right") * cam_speed * delta) / zoom.x
		
		position = position.clamp(Global.map_size / (zoom * 2), Global.map_size / zoom) # Felt really smart writing this.

func _physics_process(delta):
	cam_control(delta)
	
	if enabled and Input.is_action_just_pressed("click"):
		target.global_position = get_global_mouse_position() / zoom
