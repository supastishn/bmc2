# File: res://stats/tower_stats.gd
class_name TowerStats
extends Resource

## Time in seconds between consecutive attacks.
@export var attack_cooldown: float = 1.0
## The radius of the tower's detection/attack range.
@export var range: float = 2.0
## If true, this tower can target Camo bloons.
@export var can_see_camo: bool = false # Added property
## The scene for the projectile this tower fires.
@export var projectile_scene: PackedScene


# Constructor to allow programmatic initialization
func _init(p_cooldown: float = 1.0,
			p_range: float = 2.0,
			p_can_see_camo: bool = false, # Added parameter
			p_projectile_scene: PackedScene = null):
	attack_cooldown = p_cooldown
	range = p_range
	can_see_camo = p_can_see_camo # Assign parameter
	projectile_scene = p_projectile_scene
