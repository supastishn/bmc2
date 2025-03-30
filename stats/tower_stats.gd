# File: res://stats/tower_stats.gd
class_name TowerStats
extends Resource

## Time in seconds between consecutive attacks.
@export var attack_cooldown: float = 1.0
## The radius of the tower's detection/attack range.
@export var range: float = 2.0
## If true, this tower can target Camo bloons.
@export var can_see_camo: bool = false
## The scene for the projectile this tower fires.
@export var projectile_scene: PackedScene
## Visual representation of the tower itself.
@export var mesh: Mesh # <<< ADDED

# Constructor to allow programmatic initialization
func _init(p_cooldown: float = 1.0,
			p_range: float = 2.0,
			p_can_see_camo: bool = false,
			p_projectile_scene: PackedScene = null,
			p_mesh: Mesh = null): # <<< ADDED PARAM
	attack_cooldown = p_cooldown
	range = p_range
	can_see_camo = p_can_see_camo
	projectile_scene = p_projectile_scene
	mesh = p_mesh # <<< ADDED ASSIGNMENT
