extends TextureRect

var map_image : Image
var map_size := Vector2(200,200) # the bigger the level, the slower it is
var map_array := Array()
var stretch := 3
var pixel_radius := 25 # size of the ball of sand
@onready var map_rect := Rect2(Vector2.ZERO,map_size)
@onready var thread := Thread.new()
@onready var mutex := Mutex.new()


func _ready():
	size = map_size * stretch
	
	#Make a 2D array
	map_array.resize(map_size.x)
	for i in map_array.size():
		map_array[i] = Array()
		
	for a : Array in map_array:
		a.resize(map_size.y)
		a.fill( Color.BLACK )
		
	print("Array size is ",map_array.size())
	map_image = Image.create(map_size.x,map_size.y, false, Image.FORMAT_L8) # Image.FORMAT_L8 = force Black and white
	_reset_map()

func _get_index(pos_x : int, pos_y : int) -> int: ## DEPRECATED
	return int(pos_y + pos_x * map_size.y )

func _reset_map():
	# init the level with a black canvas
	map_image.fill( Color.BLACK )
	
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == 1: ## Left Click
			if event.is_pressed() == true:
				_change_sand( get_global_mouse_position() / stretch , Color.WHITE)
				print( "Create sand at ",get_global_mouse_position() / stretch )
		elif event.button_index == 2: ## right Click
			_change_sand( get_global_mouse_position() / stretch , Color.BLACK)
			print( "Remove sand at ",get_global_mouse_position() / stretch )

func _change_sand(pos,color):
	mutex.lock()
	for x : float in pixel_radius:
		for y : float in pixel_radius:
			var new_x : int = pos.x - x + (pixel_radius / 2) 
			var new_y : int = pos.y - y + (pixel_radius / 2)
			if pos.distance_to( Vector2(new_x,new_y).round() ) < pixel_radius / 2:
				if map_rect.has_point( Vector2(new_x,new_y) ):
					map_array[new_x][new_y] = color
					
	mutex.unlock()
	
func _falling_sand():
	for x in map_size.x:
		for y in map_size.y:
			# check botton to top
			var new_x : int = map_size.x - x - 1
			var new_y : int = map_size.y - y - 1

			if map_array[new_x][new_y] == Color.WHITE: # check if pixel is white
				if map_rect.has_point( Vector2( new_x,new_y + 1 ) ): # check pixel below
					if map_array[new_x][new_y + 1] == Color.BLACK:
						map_array[new_x][new_y + 1] = Color.WHITE
						map_array[new_x][new_y] = Color.BLACK
						
					elif map_array[new_x][new_y + 1] == Color.WHITE or new_y + 1 == map_size.y: # there is a white pixel below
						var dir : int 
						if randi_range(1,2) == 1: ## out of ideas how to get a random 1 or -1.
							dir = -1
						else:
							dir = 1
								
						if map_rect.has_point( Vector2( new_x + dir,new_y + 1 ) ):# check pixel ar a random downward direction.
							if map_array[new_x+ dir][new_y + 1] == Color.BLACK:
								map_array[new_x+ dir][new_y + 1] = Color.WHITE
								map_array[new_x][new_y] = Color.BLACK
	call_deferred("_async_finish")
	
func _make_image():
	map_image.fill( Color.BLACK )
	for x in map_size.x:
		for y in map_size.y:
			map_image.set_pixel(x,y, map_array[x][y] )
	
func _async_finish():
	#thread.wait_to_finish()
	_make_image()
	var img = ImageTexture.create_from_image( map_image ) # make an image
	set_texture(img) # apply image to texture
	
func _process(_delta):
	var start := Time.get_ticks_msec()
	#if not thread.is_started():
		#thread.start(_falling_sand)
	_falling_sand()
	print("Loop took ",Time.get_ticks_msec() - start," msecs")

