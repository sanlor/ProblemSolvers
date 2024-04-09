extends Line2D

@export var fade_time := 1.0

func _enter_tree():
	clear_points()

func setup(source : Vector2, destination : Vector2):
	add_point(source)
	add_point(destination)

func _process(delta):
	
	modulate.a -= fade_time * delta
	if modulate.a <= 0.0:
		queue_free()
