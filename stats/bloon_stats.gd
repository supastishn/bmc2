# File: res://stats/bloon_stats.gd
class_name BloonStats
extends Resource

## The health points of the bloon. How many hits it can take.
@export var health: int = 1
## How fast the bloon moves along the path (units per second).
@export var speed: float = 2.0
## How much cash the player gains when this bloon is popped.
@export var cash_value: int = 1
## Optional: Scene for the child bloon(s) to spawn when popped.
@export var child_bloon_scene: PackedScene = null
## Optional: Number of children to spawn.
@export var child_bloon_count: int = 0

## Optional: Special properties like camo, lead, regen.
@export var is_camo: bool = false
@export var is_lead: bool = false


# Constructor to allow programmatic initialization
func _init(p_health: int = 1,
			p_speed: float = 2.0,
			p_cash_value: int = 1,
			p_child_scene: PackedScene = null,
			p_child_count: int = 0,
			p_is_camo: bool = false,
			p_is_lead: bool = false):
	health = p_health
	speed = p_speed
	cash_value = p_cash_value
	child_bloon_scene = p_child_scene
	child_bloon_count = p_child_count
	is_camo = p_is_camo
	is_lead = p_is_lead
