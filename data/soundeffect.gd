extends Resource
class_name SoundEffect

enum TYPE {NONE,
	VERY_SMALL_EXPLOSION,SMALL_EXPLOSION,NORMAL_EXPLOSION,BIG_EXPLOSION,
	GUNSHOT,MISSILE_LAUNCH
	}
const DATA := {
	TYPE.VERY_SMALL_EXPLOSION: 	preload("res://art/sounds/explosion_vs.wav"),
	TYPE.SMALL_EXPLOSION: 		preload("res://art/sounds/explosion_s.wav"),
	TYPE.NORMAL_EXPLOSION: 		preload("res://art/sounds/explosion_m.wav"),
	TYPE.BIG_EXPLOSION: 		preload("res://art/sounds/explosion_l.wav"),
	TYPE.GUNSHOT: 				preload("res://art/sounds/gunshot.wav"),
	TYPE.MISSILE_LAUNCH:		preload("res://art/sounds/missile_launch.wav")
}
