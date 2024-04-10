extends CanvasLayer ## DEPRECATED

@onready var world = $".."

func _ready():
	set_multiplayer_authority( multiplayer.get_unique_id() )

func _on_spawn_pressed():
	Global.spawn_player.emit( multiplayer.get_unique_id() )

func _process(_delta):
	#spawn_button.disabled = Global.player_is_spawned
	#network_stats.text = str( multiplayer.multiplayer_peer.get_peer( 1 ).get_statistic( ENetPacketPeer.PEER_ROUND_TRIP_TIME ) )
	pass

func _on_disconnect_pressed():
	world.request_disconnect()
