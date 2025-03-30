# File: res://autoloads/tower_factory.gd
# --- AUTOLOAD SCRIPT (Name it TowerFactory in Project Settings) ---
extends Node

# Preload common resources (adjust paths as needed)
const BASE_TOWER_SCENE = preload("res://tower/tower.tscn")
const BASE_PROJECTILE_SCENE = preload("res://projectile/projectile.tscn")
const DART_MESH = preload("res://meshes/dart_monkey_mesh.tres") # Example: Replace with actual mesh resource
const DART_PROJECTILE_MESH = preload("res://meshes/dart_projectile_mesh.tres") # Example
const SHARP_SHOTS_PROJECTILE_MESH = preload("res://meshes/sharp_dart_mesh.tres") # Example for upgrade

# --- Tower Data Definition ---
# Structure:
# "tower-name": {
#   "base_cost": int,
#   "base": { "tower": TowerStats, "projectile": ProjectileStats },
#   "path1": {
#       1: { "name": "...", "cost": ..., "apply": Callable(ts, ps) },
#       ...
#    },
#   "path2": { ... },
#   "path3": { ... }
# }

var tower_data := {
	"dart-monkey": {
		"base_cost": 100, # <<< ADDED BASE COST
		"base": {
			"tower": TowerStats.new(
				0.95, # Cooldown
				3.5,  # Range
				false,# Can see camo
				BASE_PROJECTILE_SCENE,
				DART_MESH
			),
			"projectile": ProjectileStats.new(
				15.0, # Speed
				1,    # Damage
				0.7,  # Lifetime
				2,    # Pierce
				false,# Can pop lead
				false,# Homing
				0.0,  # Turn rate
				DART_PROJECTILE_MESH
			)
		},
		"path1": {
			1: {
				"name": "Sharp Shots", "cost": 140,
				"apply": func(ts: TowerStats, ps: ProjectileStats):
	ps.pierce += 1
	ps.mesh = SHARP_SHOTS_PROJECTILE_MESH
	print("Applied Dart Monkey 1-0-0: Sharp Shots")
			},
			2: {
				"name": "Razor Sharp Shots", "cost": 220,
				"apply": func(ts: TowerStats, ps: ProjectileStats):
	ps.pierce += 2 # Adds +2 *additional* pierce (total +3 from base)
	print("Applied Dart Monkey 2-0-0: Razor Sharp Shots")
			},
			# Add tiers 3, 4, 5 for path 1...
			# 3: { "name": "Spike-o-pult", "cost": 300, "apply": func(ts,ps): ... },
		},
		"path2": {
			1: {
				"name": "Quick Shots", "cost": 100,
				"apply": func(ts: TowerStats, ps: ProjectileStats):
					# Attack speed handled separately in create_stats
	print("Applied Dart Monkey 0-1-0: Quick Shots")
			},
			2: {
				"name": "Very Quick Shots", "cost": 200,
				"apply": func(ts: TowerStats, ps: ProjectileStats):
					# Attack speed handled separately in create_stats
	print("Applied Dart Monkey 0-2-0: Very Quick Shots")
			},
			# Add tiers 3, 4, 5 for path 2...
		},
		"path3": {
			1: {
				"name": "Long Range Darts", "cost": 90,
				"apply": func(ts: TowerStats, ps: ProjectileStats):
	ts.range += 1.0
	print("Applied Dart Monkey 0-0-1: Long Range Darts")
			},
			2: {
				"name": "Enhanced Eyesight", "cost": 120,
				"apply": func(ts: TowerStats, ps: ProjectileStats):
	ts.range += 1.0 # Stacks with Long Range Darts
	ts.can_see_camo = true
	print("Applied Dart Monkey 0-0-2: Enhanced Eyesight")
			},
			# Add tiers 3, 4, 5 for path 3...
		}
	},
	# --- Add data for other towers ---
}

# --- Factory Function ---

## Creates TowerStats and ProjectileStats based on name and upgrade path.
## Returns a Dictionary: { "tower": TowerStats, "projectile": ProjectileStats } or empty on failure.
func create_stats(tower_name: String, upgrade_path: String) -> Dictionary:
	if not tower_data.has(tower_name):
		printerr("TowerFactory: Unknown tower name '", tower_name, "'")
		return {}

	if not upgrade_path.is_valid_int() or upgrade_path.length() != 3:
		printerr("TowerFactory: Invalid upgrade path '", upgrade_path, "'. Must be 3 digits.")
		return {}

	var base_data = tower_data[tower_name].get("base")
	if not base_data or not base_data.has("tower") or not base_data.has("projectile"):
		printerr("TowerFactory: Base data missing for '", tower_name, "'")
		return {}

	# --- Duplicate the base stats ---
	var current_tower_stats: TowerStats = base_data.tower.duplicate(true) # Deep copy might be safer
	var current_projectile_stats: ProjectileStats = base_data.projectile.duplicate(true)

	# Parse upgrade path
	var p1 = int(upgrade_path[0])
	var p2 = int(upgrade_path[1])
	var p3 = int(upgrade_path[2])

	# Apply upgrades sequentially for each path
	_apply_path_upgrades(tower_name, 1, p1, current_tower_stats, current_projectile_stats)
	_apply_path_upgrades(tower_name, 2, p2, current_tower_stats, current_projectile_stats)
	_apply_path_upgrades(tower_name, 3, p3, current_tower_stats, current_projectile_stats)

	# --- Special Handling for Attack Speed ---
	var cooldown_multiplier = 1.0
	if tower_name == "dart-monkey":
		if p2 >= 1: cooldown_multiplier *= 0.85 # Quick Shots (15% faster)
		if p2 >= 2: cooldown_multiplier *= (1.0 / (1.0/0.85 * 1.15)) # Very Quick Shots (further 15% faster) -> ~0.739
		# Add multipliers for tiers 3, 4, 5...

	current_tower_stats.attack_cooldown *= cooldown_multiplier

	# print_debug("Final Stats for %s %s:" % [tower_name, upgrade_path])
	# print_debug("  Tower: Range=%.1f, Cooldown=%.2f, Camo=%s" % [current_tower_stats.range, current_tower_stats.attack_cooldown, current_tower_stats.can_see_camo])
	# print_debug("  Projectile: Pierce=%d, Damage=%d, Speed=%.1f" % [current_projectile_stats.pierce, current_projectile_stats.damage, current_projectile_stats.speed])

	return {
		"tower": current_tower_stats,
		"projectile": current_projectile_stats
	}


## Helper function to apply upgrades for a single path
func _apply_path_upgrades(tower_name: String, path_index: int, max_level: int, ts: TowerStats, ps: ProjectileStats):
	var path_key = "path" + str(path_index)
	if not tower_data[tower_name].has(path_key):
		return

	var path_upgrades = tower_data[tower_name][path_key]
	for level in range(1, max_level + 1):
		if path_upgrades.has(level):
			var upgrade_info: Dictionary = path_upgrades[level]
			var upgrade_func: Callable = upgrade_info["apply"]
			upgrade_func.call(ts, ps) # Apply the upgrade function
		else:
			pass # Level not defined

# --- NEW GETTER FUNCTIONS ---

## Gets the display name and cost for a specific upgrade.
## Returns: Dictionary { "name": String, "cost": int } or empty if not found.
func get_upgrade_details(tower_name: String, path_index: int, tier: int) -> Dictionary:
	if not tower_data.has(tower_name): return {}
	var path_key = "path" + str(path_index)
	if not tower_data[tower_name].has(path_key): return {}
	var path_upgrades = tower_data[tower_name][path_key]
	if not path_upgrades.has(tier): return {}

	var upgrade_info = path_upgrades[tier]
	return {
		"name": upgrade_info.get("name", "Unnamed Upgrade"),
		"cost": upgrade_info.get("cost", 999999)
	}

## Gets the base cost of a tower.
## Returns: int cost or -1 if not found.
func get_base_cost(tower_name: String) -> int:
	if not tower_data.has(tower_name): return -1
	return tower_data[tower_name].get("base_cost", -1)

## Gets the maximum tier available for a given path.
## Returns: int max_tier (e.g., 5) or 0 if path doesn't exist.
func get_max_tier_for_path(tower_name: String, path_index: int) -> int:
	if not tower_data.has(tower_name): return 0
	var path_key = "path" + str(path_index)
	if not tower_data[tower_name].has(path_key): return 0
	var path_upgrades = tower_data[tower_name][path_key]
	var max_tier = 0
	for key in path_upgrades.keys():
		if key is int and key > max_tier:
			max_tier = key
	return max_tier
