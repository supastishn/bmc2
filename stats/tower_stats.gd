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
# --- NEW Properties ---
## Number of projectiles fired in a single attack sequence.
@export var projectiles_per_shot: int = 1
## Angle in degrees between projectiles if projectiles_per_shot > 1.
@export var spread_angle: float = 0.0
## Name of the tower's ability, if any.
@export var ability_name: String = ""
## Description of the tower's ability.
@export var ability_description: String = ""
## Cooldown of the ability in seconds.
@export var ability_cooldown: float = 0.0
## Duration of the ability effect in seconds.
@export var ability_duration: float = 0.0
## Initial cooldown of the ability when the tower is placed/upgraded.
@export var ability_initial_cooldown: float = 0.0

# Constructor to allow programmatic initialization
func _init(p_cooldown: float = 1.0,
			p_range: float = 2.0,
			p_can_see_camo: bool = false,
			p_projectile_scene: PackedScene = null,
			p_mesh: Mesh = null, # <<< ADDED PARAM
			p_projectiles_per_shot: int = 1,
			p_spread_angle: float = 0.0,
			p_ability_name: String = "",
			p_ability_description: String = "",
			p_ability_cooldown: float = 0.0,
			p_ability_duration: float = 0.0,
			p_ability_initial_cooldown: float = 0.0):
	attack_cooldown = p_cooldown
	range = p_range
	can_see_camo = p_can_see_camo
	projectile_scene = p_projectile_scene
	mesh = p_mesh # <<< ADDED ASSIGNMENT
	projectiles_per_shot = p_projectiles_per_shot
	spread_angle = p_spread_angle
	ability_name = p_ability_name
	ability_description = p_ability_description
	ability_cooldown = p_ability_cooldown
	ability_duration = p_ability_duration
	ability_initial_cooldown = p_ability_initial_cooldown
