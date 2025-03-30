# File: res://stats/projectile_stats.gd
class_name ProjectileStats
extends Resource

## How fast the projectile travels (units per second).
@export var speed: float = 15.0
## How much damage the projectile deals on hit.
@export var damage: int = 1
## How long the projectile exists before disappearing (seconds).
@export var lifetime: float = 2.0
## Number of bloons this projectile can hit before disappearing.
@export var pierce: int = 1
## If true, this projectile can damage Lead bloons.
@export var can_pop_lead: bool = false
## If true, the projectile will attempt to track a target.
@export var homing_enabled: bool = false
## How quickly the projectile turns towards its target (radians/sec factor).
@export var homing_turn_rate: float = 5.0
## Visual representation of the projectile.
@export var mesh: Mesh # <<< ADDED

# Constructor to allow programmatic initialization
func _init(p_speed: float = 15.0,
			p_damage: int = 1,
			p_lifetime: float = 2.0,
			p_pierce: int = 1,
			p_can_pop_lead: bool = false,
			p_homing_enabled: bool = false,
			p_homing_turn_rate: float = 5.0,
			p_mesh: Mesh = null): # <<< ADDED PARAM
	speed = p_speed
	damage = p_damage
	lifetime = p_lifetime
	pierce = p_pierce
	can_pop_lead = p_can_pop_lead
	homing_enabled = p_homing_enabled
	homing_turn_rate = p_homing_turn_rate
	mesh = p_mesh # <<< ADDED ASSIGNMENT
