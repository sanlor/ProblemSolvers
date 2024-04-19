extends Node

func pos_to_id ( pos : Vector2 ) -> int:
	return int(pos.y + pos.x * Global.map_size.y)
	
func id_to_pos ( _id : int ) -> Vector2:
	return Vector2.ZERO
