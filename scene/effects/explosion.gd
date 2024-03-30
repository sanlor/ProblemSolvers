extends AnimatedSprite2D

@onready var anim = $animation
@onready var audio = $audio

var sfx : SoundEffect.TYPE 

func _ready():
	anim.play("explosion")
	_play_sfx(sfx)

func _play_sfx( type : SoundEffect.TYPE ):
	audio.stream = SoundEffect.DATA[ type ]
	audio.play()

func _on_animation_player_animation_finished(_anim_name):
	queue_free()
