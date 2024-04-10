extends Resource
class_name Weapons

enum ID{HAND, CHAIN, BAZOOKA}
var DATA := {
	Weapons.ID.HAND: 		load("res://data/handgun.tres"),
	Weapons.ID.CHAIN: 		load("res://data/chaingun.tres"),
	Weapons.ID.BAZOOKA: 	load("res://data/bazooka.tres"),
}
var PROJECTILE_DATA := {
	Weapons.ID.BAZOOKA: load("res://scene/weapons/base_projectile.tscn"),
}

@export var weapon_id : ID
@export var weapon_name : String ## Name of the weapon

@export var damage : int
@export var blast_radius : int
@export var firerate : float
@export var fire_spread : float = 0.0
@export var fire_range : float = 500.0
@export var sprite : Texture2D
@export var recoil_force : float
@export var cooldown_cost : float ## how much the player can fire a weapon before waiting
@export var is_hitscan : bool ## is the damage instant?
@export var is_gravity_affected : bool ## if its not instant, is afffected by gravity (ex: a missile or a granade)
@export var can_leave_trail : bool
@export var trigger_sound : SoundEffect.TYPE ## Noise made when the gun is activated

@export var projectile : String ## the filepath of the projectile.
@export var projectile_sprite : Texture2D
@export var projectile_speed : int
@export var projectile_accel : float
@export var projectile_sound : SoundEffect.TYPE ## Noise made when the projectile hits something
