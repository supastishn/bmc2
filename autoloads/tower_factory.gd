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
#   "base": { "tower": TowerStats, "projectile": ProjectileStats },
#   "path1": { 1: Callable, 2: Callable, ... },
#   "path2": { ... },
#   "path3": { ... }
# }
# Callables take (tower_stats, projectile_stats) as arguments and modify them.

var tower_data := {
	"dart-monkey": {
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
			1: func(ts: TowerStats, ps: ProjectileStats):
				ps.pierce += 1
				ps.mesh = SHARP_SHOTS_PROJECTILE_MESH # Example: Change projectile mesh
				print("Applied Dart Monkey 1-0-0: Sharp Shots"),
			2: func(ts: TowerStats, ps: ProjectileStats):
				ps.pierce += 2 # Razor Sharp Shots adds +2 more pierce
				print("Applied Dart Monkey 2-0-0: Razor Sharp Shots"),
			# Add tiers 3, 4, 5 for path 1...
		},
		"path2": {
			1: func(ts: TowerStats, ps: ProjectileStats):
				ts.range += 0.5 # Quick Shots increases range slightly? (Check BTD6 wiki)
				print("Applied Dart Monkey 0-1-0: Quick Shots (Range Placeholder)"),
			2: func(ts: TowerStats, ps: ProjectileStats):
				ts.range += 0.5 # Very Quick Shots increases range slightly more?
				print("Applied Dart Monkey 0-2-0: Very Quick Shots (Range Placeholder)"),
			# Add tiers 3, 4, 5 for path 2... (Attack speed handled differently, see below)
		},
		"path3": {
			1: func(ts: TowerStats, ps: ProjectileStats):
				ts.range += 1.0 # Long Range Darts
				print("Applied Dart Monkey 0-0-1: Long Range Darts"),
			2: func(ts: TowerStats, ps: ProjectileStats):
				ts.can_see_camo = true # Enhanced Eyesight
				print("Applied Dart Monkey 0-0-2: Enhanced Eyesight"),
			# Add tiers 3, 4, 5 for path 3...
		}
	},
	# --- Add data for other towers ("tack-shooter", "sniper-monkey", etc.) ---
	# "tack-shooter": { ... }
}

# --- Factory Function ---

## Creates TowerStats and ProjectileStats based on name and upgrade path.
## Returns a Dictionary: { "tower": TowerStats, "projectile": ProjectileStats } or null on failure.
func create_stats(tower_name: String, upgrade_path: String) -> Dictionary:
	if not tower_data.has(tower_name):
		printerr("TowerFactory: Unknown tower name '", tower_name, "'")
		return {} # Return empty dict on failure

	if not upgrade_path.is_valid_int() or upgrade_path.length() != 3:
		printerr("TowerFactory: Invalid upgrade path '", upgrade_path, "'. Must be 3 digits.")
		return {}

	var base_data = tower_data[tower_name].get("base")
	if not base_data or not base_data.has("tower") or not base_data.has("projectile"):
		printerr("TowerFactory: Base data missing for '", tower_name, "'")
		return {}

	# --- IMPORTANT: Duplicate the base stats to avoid modifying the template ---
	# Use deep copy (true) to duplicate nested resources like projectile_scene if needed,
	# although we handle the projectile stats separately here.
	var current_tower_stats: TowerStats = base_data.tower.duplicate()
	var current_projectile_stats: ProjectileStats = base_data.projectile.duplicate()

	# Assign the duplicated projectile stats to the duplicated tower stats
	# This assumes the base tower stats points to a generic scene, but we want
	# it to hold the specific projectile stats we are configuring.
	# A better approach might be for TowerStats to not hold ProjectileStats directly,
	# but rather the scene, and the projectile gets its stats upon instantiation.
	# For now, let's keep it simple and assume TowerStats holds the configured projectile stats.
	# --- OR --- Maybe the projectile scene itself should load these stats?
	# Let's modify the approach: The factory returns BOTH stats objects.
	# The tower, when shooting, will instantiate the scene defined in its TowerStats,
	# and then assign the ProjectileStats returned by the factory to that instance.

	# Parse upgrade path
	var p1 = int(upgrade_path[0])
	var p2 = int(upgrade_path[1])
	var p3 = int(upgrade_path[2])

	# Apply upgrades sequentially for each path
	_apply_path_upgrades(tower_name, 1, p1, current_tower_stats, current_projectile_stats)
	_apply_path_upgrades(tower_name, 2, p2, current_tower_stats, current_projectile_stats)
	_apply_path_upgrades(tower_name, 3, p3, current_tower_stats, current_projectile_stats)

	# --- Special Handling for Attack Speed ---
	# Attack speed upgrades often multiply the base rate. We store the base cooldown
	# and apply multipliers based on upgrades. Let's add this logic here.
	# Example: Dart Monkey 0-1-0 (Quick Shots) = 15% faster -> cooldown * 0.85
	# Example: Dart Monkey 0-2-0 (Very Quick Shots) = 33% faster -> cooldown * 0.67 (approx)
	var cooldown_multiplier = 1.0
	if tower_name == "dart-monkey":
		if p2 >= 1: cooldown_multiplier *= 0.85 # Quick Shots
		if p2 >= 2: cooldown_multiplier *= (0.67 / 0.85) # Very Quick Shots (adjust multiplier)
		# Add multipliers for tiers 3, 4, 5...

	# Apply the final multiplier to the base cooldown stored in the duplicated stats
	current_tower_stats.attack_cooldown *= cooldown_multiplier

	print("Final Stats for %s %s:" % [tower_name, upgrade_path])
	print("  Tower: Range=%.1f, Cooldown=%.2f, Camo=%s" % [current_tower_stats.range, current_tower_stats.attack_cooldown, current_tower_stats.can_see_camo])
	print("  Projectile: Pierce=%d, Damage=%d, Speed=%.1f" % [current_projectile_stats.pierce, current_projectile_stats.damage, current_projectile_stats.speed])


	return {
		"tower": current_tower_stats,
		"projectile": current_projectile_stats
	}


## Helper function to apply upgrades for a single path
func _apply_path_upgrades(tower_name: String, path_index: int, max_level: int, ts: TowerStats, ps: ProjectileStats):
	var path_key = "path" + str(path_index)
	if not tower_data[tower_name].has(path_key):
		return # Path doesn't exist for this tower

	var path_upgrades = tower_data[tower_name][path_key]
	for level in range(1, max_level + 1):
		if path_upgrades.has(level):
			var upgrade_func: Callable = path_upgrades[level]
			upgrade_func.call(ts, ps) # Apply the upgrade function
		else:
			# Optional: Print warning if an expected upgrade level is missing
			# print_debug("TowerFactory: Upgrade %s path %d level %d not defined." % [tower_name, path_index, level])
			pass
