# File: res://autoloads/tower_factory.gd
# --- AUTOLOAD SCRIPT (Name it TowerFactory in Project Settings) ---
extends Node

# Preload common resources
const BASE_TOWER_SCENE = preload("res://tower/tower.tscn")
const BASE_PROJECTILE_SCENE = preload("res://projectile/projectile.tscn")
# --- Define Meshes (Replace with your actual .tres files) ---
const DART_MONKEY_MESH = preload("res://meshes/dart_monkey_mesh.tres") # Example
const DART_PROJECTILE_MESH = preload("res://meshes/dart_projectile_mesh.tres") # Example
const SHARP_SHOTS_PROJECTILE_MESH = preload("res://meshes/sharp_dart_mesh.tres") # Example

# --- Tower Data Definition ---
# Structure:
# "tower-name": {
#   "base": { "tower": TowerStats, "projectile": ProjectileStats, "cost": int },
#   "path1": {
#       1: { "name": str, "cost": int, "desc": str, "func": Callable(ts, ps) },
#       ... up to tier 5
#   },
#   "path2": { ... },
#   "path3": { ... }
# }

var tower_data := {
	"dart-monkey": {
		"base": {
			"tower": TowerStats.new(0.95, 3.5, false, BASE_PROJECTILE_SCENE, DART_MONKEY_MESH),
			"projectile": ProjectileStats.new(35.0, 1, 0.7, 2, false, false, 0.0, DART_PROJECTILE_MESH),
			"cost": 200 # Base cost of Dart Monkey
		},
		"path1": {
			1: {"name": "Sharp Shots", "cost": 140, "desc": "+1 Pierce", "func": func(ts: TowerStats, ps: ProjectileStats):
	ps.pierce += 1
	ps.mesh = SHARP_SHOTS_PROJECTILE_MESH
			},
			2: {"name": "Razor Sharp", "cost": 220, "desc": "+2 Pierce", "func": func(ts: TowerStats, ps: ProjectileStats):
	ps.pierce += 2 # Adds on top of previous tier
			},
			# TODO: Add tiers 3, 4, 5 for path 1
			3: {"name": "Spike-o-pult", "cost": 300, "desc": "Throws heavy spike ball.", "func": func(ts,ps): pass}, # Placeholder
			4: {"name": "Juggernaut", "cost": 1500, "desc": "Huge damage to ceramics.", "func": func(ts,ps): pass}, # Placeholder
			5: {"name": "Ultra-Juggernaut", "cost": 15000, "desc": "Splits into 6 Juggernauts.", "func": func(ts,ps): pass}, # Placeholder
		},
		"path2": {
			1: {"name": "Quick Shots", "cost": 100, "desc": "15% Faster attack", "func": func(ts: TowerStats, ps: ProjectileStats): pass}, # Speed handled separately
			2: {"name": "Very Quick Shots", "cost": 180, "desc": "33% Faster attack", "func": func(ts: TowerStats, ps: ProjectileStats): pass}, # Speed handled separately
			# TODO: Add tiers 3, 4, 5 for path 2
			3: {"name": "Triple Shot", "cost": 400, "desc": "Throws 3 darts.", "func": func(ts,ps): pass}, # Placeholder
			4: {"name": "Super Monkey Fan Club", "cost": 8000, "desc": "Ability: Transform nearby darts.", "func": func(ts,ps): pass}, # Placeholder
			5: {"name": "Plasma Monkey Fan Club", "cost": 45000, "desc": "Ability: Transform nearby darts to plasma.", "func": func(ts,ps): pass}, # Placeholder
		},
		"path3": {
			1: {"name": "Long Range", "cost": 90, "desc": "+Range", "func": func(ts: TowerStats, ps: ProjectileStats):
	ts.range += 1.0
			},
			2: {"name": "Enhanced Eyesight", "cost": 170, "desc": "+Range, Camo Detect", "func": func(ts: TowerStats, ps: ProjectileStats):
	ts.range += 1.0 # Adds on top
	ts.can_see_camo = true
			},
			# TODO: Add tiers 3, 4, 5 for path 3
			3: {"name": "Crossbow", "cost": 550, "desc": "+Pierce, +Crit chance", "func": func(ts,ps): pass}, # Placeholder
			4: {"name": "Sharp Shooter", "cost": 1600, "desc": "Higher crit chance/damage.", "func": func(ts,ps): pass}, # Placeholder
			5: {"name": "Crossbow Master", "cost": 21500, "desc": "Attacks incredibly fast.", "func": func(ts,ps): pass}, # Placeholder
		}
	},
	# --- Add data for other towers ---
}

# --- Factory Functions ---

## Creates TowerStats and ProjectileStats based on name and upgrade path string (e.g., "120").
func create_stats(tower_name: String, upgrade_path_str: String) -> Dictionary:
	if not tower_data.has(tower_name):
		printerr("TowerFactory: Unknown tower name '", tower_name, "'")
		return {}

	if not upgrade_path_str.is_valid_int() or upgrade_path_str.length() != 3:
		printerr("TowerFactory: Invalid upgrade path string '", upgrade_path_str, "'. Must be 3 digits.")
		return {}

	var base_data = tower_data[tower_name].get("base")
	if not base_data or not base_data.has("tower") or not base_data.has("projectile"):
		printerr("TowerFactory: Base data missing for '", tower_name, "'")
		return {}

	# --- Duplicate the base stats ---
	var current_tower_stats: TowerStats = base_data.tower.duplicate(true) # Deep copy might be safer
	var current_projectile_stats: ProjectileStats = base_data.projectile.duplicate(true)

	# Parse upgrade path levels
	var p1 = int(upgrade_path_str[0])
	var p2 = int(upgrade_path_str[1])
	var p3 = int(upgrade_path_str[2])
	var path_levels = [p1, p2, p3]

	# Apply upgrades sequentially for each path based on levels
	for path_idx in range(3):
		var max_level = path_levels[path_idx]
		_apply_path_upgrades(tower_name, path_idx + 1, max_level, current_tower_stats, current_projectile_stats)

	# --- Apply Attack Speed Multipliers (Example for Dart Monkey Path 2) ---
	var cooldown_multiplier = 1.0
	if tower_name == "dart-monkey":
		match p2: # Check path 2 level
			1: cooldown_multiplier *= 0.85 # Quick Shots
			2: cooldown_multiplier *= 0.67 # Very Quick Shots (approx total multiplier)
			# 3: cooldown_multiplier *= X # Triple Shot? (Check BTD6 wiki if it affects speed)
			# 4, 5 are abilities or don't directly change base speed this way

	# Apply the final multiplier to the base cooldown
	current_tower_stats.attack_cooldown *= cooldown_multiplier

	# print_debug("Final Stats for %s %s:" % [tower_name, upgrade_path_str])
	# print_debug("  Tower: Range=%.1f, Cooldown=%.2f, Camo=%s" % [current_tower_stats.range, current_tower_stats.attack_cooldown, current_tower_stats.can_see_camo])
	# print_debug("  Projectile: Pierce=%d, Damage=%d, Speed=%.1f" % [current_projectile_stats.pierce, current_projectile_stats.damage, current_projectile_stats.speed])

	return {
		"tower": current_tower_stats,
		"projectile": current_projectile_stats
	}


## Helper function to apply upgrades for a single path up to a max level
func _apply_path_upgrades(tower_name: String, path_index: int, max_level: int, ts: TowerStats, ps: ProjectileStats):
	var path_key = "path" + str(path_index)
	if not tower_data[tower_name].has(path_key): return

	var path_upgrades = tower_data[tower_name][path_key]
	for level in range(1, max_level + 1):
		if path_upgrades.has(level):
			var upgrade_info = path_upgrades[level]
			if upgrade_info.has("func"):
				var upgrade_func: Callable = upgrade_info.func
				upgrade_func.call(ts, ps) # Apply the stat modification function
		# else: print_debug("Upgrade definition missing for %s path %d level %d" % [tower_name, path_index, level])


## --- NEW: Get details for a specific upgrade tier ---
func get_upgrade_details(tower_name: String, path_index: int, tier: int) -> Dictionary:
	if not tower_data.has(tower_name): return {}

	var path_key = "path" + str(path_index)
	if not tower_data[tower_name].has(path_key): return {}

	var path_upgrades = tower_data[tower_name][path_key]
	if path_upgrades.has(tier):
		var details = path_upgrades[tier].duplicate() # Return a copy
		details.erase("func") # Don't return the callable function itself
		return details
	else:
		return {} # Tier not defined


## --- NEW: Get base cost of a tower ---
func get_base_cost(tower_name: String) -> int:
	if tower_data.has(tower_name) and tower_data[tower_name].has("base") and tower_data[tower_name].base.has("cost"):
		return tower_data[tower_name].base.cost
	else:
		printerr("TowerFactory: Base cost not found for '", tower_name, "'")
		return 999999 # Return high value on error
