# File: res://autoloads/tower_factory.gd
# --- AUTOLOAD SCRIPT (Name it TowerFactory in Project Settings) ---
extends Node

# Preload common resources
# NOTE: Assuming projectile behavior (rebound, split, knockback) is handled
# within projectile.gd based on ProjectileStats flags.
# If specific scenes ARE needed, they should be created and preloaded.
# For now, we'll mostly use the base projectile scene and modify its stats/mesh.
const BASE_TOWER_SCENE: PackedScene = preload("res://tower/tower.tscn")
const BASE_PROJECTILE_SCENE: PackedScene = preload("res://projectile/projectile.tscn")
# --- Define Meshes (Replace with your actual .tres files) ---
const DART_MONKEY_MESH = preload("res://meshes/dart_monkey_mesh.tres") # Example
const DART_PROJECTILE_MESH = preload("res://meshes/dart_projectile_mesh.tres") # Example
const SHARP_SHOTS_PROJECTILE_MESH = preload("res://meshes/sharp_dart_mesh.tres") # Example
const SPIKEBALL_MESH = preload("res://meshes/spikeball_mesh.tres") # NEW
const JUGGERNAUT_MESH = preload("res://meshes/juggernaut_mesh.tres") # NEW
const MINI_JUGGERNAUT_MESH = preload("res://meshes/mini_juggernaut_mesh.tres") # NEW
const BOLT_MESH = preload("res://meshes/bolt_mesh.tres") # NEW

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

# --- Helper Func to update can_pop_lead based on damage type ---
func _update_can_pop_lead(ps: ProjectileStats):
	ps.can_pop_lead = not (ps.damage_type in ["Sharp"])


var tower_data := {
	"dart-monkey": {
		"base": {
			# 000: 32r, 0.95s, dart: 1d, 2p, sharp, speed 35, lifetime 0.7
			"tower": TowerStats.new(0.95, 3.5, false, BASE_PROJECTILE_SCENE, DART_MONKEY_MESH),
			"projectile": ProjectileStats.new(p_speed=35.0, p_damage=1, p_lifetime=0.7, p_pierce=2, p_mesh=DART_PROJECTILE_MESH, p_damage_type="Sharp"),
			"cost": 200 # Base cost of Dart Monkey
		},
		"path1": {
			# 100: +1p
			1: {"name": "Sharp Shots", "cost": 140, "desc": "+1 Pierce", "func": func(ts: TowerStats, ps: ProjectileStats):
	ps.pierce += 1
	ps.mesh = SHARP_SHOTS_PROJECTILE_MESH # Example mesh change
			},
			# 200: +2p (total +3p from base)
			2: {"name": "Razor Sharp", "cost": 220, "desc": "+2 Pierce", "func": func(ts: TowerStats, ps: ProjectileStats):
	ps.pierce += 2
			},
			# 300: Spikeball: 36.8r, 1.15s, 2d, 18p, shatter, slower speed?, rebound
			3: {"name": "Spike-o-pult", "cost": 300, "desc": "Throws heavy spike ball.", "func": func(ts: TowerStats, ps: ProjectileStats):
	ts.range = 4.1 # 32 * 1.15 = 36.8 -> Radius = 4.1? Approximation
	ts.attack_cooldown = 1.15 # Overrides base/path2 speed for this path
	#ts.projectile_scene = SPIKEBALL_SCENE # If using a separate scene
	ps.damage = 2
	ps.pierce = 18 # Base pierce for spikeball
	ps.damage_type = "Shatter"
	_update_can_pop_lead(ps)
	ps.speed = 17.5 # Approximation (half speed?)
	ps.can_rebound = true
	ps.mesh = SPIKEBALL_MESH
			},
			# 400: Jugg: 1.0s, 60p, +2fd, +3cd, knockback, normal type
			4: {"name": "Juggernaut", "cost": 1500, "desc": "Huge damage to ceramics.", "func": func(ts: TowerStats, ps: ProjectileStats):
	ts.attack_cooldown = 1.0
	ps.pierce = 60
	ps.extra_fortified_damage = 2
	ps.extra_ceramic_damage = 3
	ps.damage_type = "Normal"
	_update_can_pop_lead(ps)
	ps.applies_knockback = true
	ps.knockback_duration = 0.15
	ps.knockback_slow_ceramic_lead = -1.0
	ps.knockback_slow_other = -5.0
	ps.speed = 25.0 # Faster than spikeball? Approximation
	ps.mesh = JUGGERNAUT_MESH
			},
			# 500: Ultra: 5d, +5fd, +8cd, +20ld, 210p, emit mini-juggs
			5: {"name": "Ultra-Juggernaut", "cost": 15000, "desc": "Splits into 6 Juggernauts.", "func": func(ts: TowerStats, ps: ProjectileStats):
	ps.damage = 5
	ps.pierce = 210
	ps.extra_fortified_damage = 5 # Total, not additive from T4
	ps.extra_ceramic_damage = 8 # Total
	ps.extra_lead_damage = 20
	ps.emits_on_pierce_loss = true # Assuming 50% and 0 pierce triggers
	ps.emits_on_expire = true # Also emits remaining on expiration
	ps.emit_count = 6
	# Need a Mini Juggernaut projectile stats resource or scene
	# ps.emitted_projectile_scene = MINI_JUGGERNAUT_SCENE
	# Or create stats inline? For now, just flag it.
	# Mini Jug stats: 2d, +2fd(4), +3cd(5), 50p, normal, rebound
			},
		},
		"path2": {
			# Speed multipliers applied in create_stats
			1: {"name": "Quick Shots", "cost": 100, "desc": "15% Faster attack", "func": func(ts: TowerStats, ps: ProjectileStats): pass},
			2: {"name": "Very Quick Shots", "cost": 180, "desc": "33% Faster attack", "func": func(ts: TowerStats, ps: ProjectileStats): pass},
			# 030: Triple shot, 75%s (relative to T2? -> 0.6365*0.75=0.4774s)
			3: {"name": "Triple Shot", "cost": 400, "desc": "Throws 3 darts.", "func": func(ts: TowerStats, ps: ProjectileStats):
	ts.projectiles_per_shot = 3
	ts.spread_angle = 30.0
			},
			# 040: Fan Club Ability, 50%s (relative to T3? -> 0.4774*0.5=0.2387s)
			4: {"name": "Super Monkey Fan Club", "cost": 8000, "desc": "Ability: Transform nearby darts.", "func": func(ts: TowerStats, ps: ProjectileStats):
	ts.ability_name = "Fan Club"
	ts.ability_description = "Transforms up to 10 nearby Dart Monkeys into Super Monkeys for 15s."
	ts.ability_cooldown = 50.0
	ts.ability_duration = 15.0
	ts.ability_initial_cooldown = 16.67
			},
			# 050: PMFC Ability, buffs more darts, stronger buff
			5: {"name": "Plasma Monkey Fan Club", "cost": 45000, "desc": "Ability: Transform nearby darts to plasma.", "func": func(ts: TowerStats, ps: ProjectileStats):
	ts.ability_name = "Plasma Monkey Fan Club"
	ts.ability_description = "Transforms up to 20 nearby Dart Monkeys into Plasma Monkeys for 15s."
	# Cooldown/Duration usually carry over, description updates
			},
		},
		"path3": {
			# 001: +8r (40r total -> ~4.5 radius), +lifetime?
			1: {"name": "Long Range Darts", "cost": 90, "desc": "+Range", "func": func(ts: TowerStats, ps: ProjectileStats):
	ts.range = 4.5 # Approximation of 40r
	ps.lifetime *= 1.2 # Guess for increased lifetime
			},
			# 002: +8r (48r total -> ~5.4 radius), camo, +speed?, +lifetime?
			2: {"name": "Enhanced Eyesight", "cost": 170, "desc": "+Range, Camo Detect", "func": func(ts: TowerStats, ps: ProjectileStats):
	ts.range = 5.4 # Approximation of 48r
	ts.can_see_camo = true
	ps.speed *= 1.2 # Guess
	ps.lifetime *= 1.2 # Guess (cumulative with T1?)
			},
			# 003: Crossbow: 60r (~6.7 radius), bolt: 3d, 3p, faster speed?
			3: {"name": "Crossbow", "cost": 550, "desc": "Shoots powerful bolts.", "func": func(ts: TowerStats, ps: ProjectileStats):
	ts.range = 6.7 # Approximation of 60r
	#ts.projectile_scene = BOLT_SCENE # If using a separate scene
	ps.damage = 3
	ps.pierce = 3 # Base for bolt
	ps.speed *= 1.3 # Guess, bolt faster than dart
	ps.mesh = BOLT_MESH
			},
			# 004: Sharp Shooter: Crit (10 shots, 50d), 50%s (relative to T3 -> 0.95*0.5=0.475s), faster speed?
			4: {"name": "Sharp Shooter", "cost": 1600, "desc": "Deals critical damage sometimes.", "func": func(ts: TowerStats, ps: ProjectileStats):
	ts.attack_cooldown = 0.475 # Overrides base/path2 speed
	ps.crit_frequency = 10
	ps.crit_extra_damage = 50
	ps.speed *= 1.2 # Guess
			},
			# 005: Crossbow Master: 80r (~9.0 radius), 8d, 8p, 50%s (rel to T4 -> 0.475*0.5=0.2375s), Crit(5 shots, 80d), normal type
			5: {"name": "Crossbow Master", "cost": 21500, "desc": "Attacks incredibly fast.", "func": func(ts: TowerStats, ps: ProjectileStats):
	ts.range = 9.0 # Approximation of 80r
	ts.attack_cooldown = 0.2375
	ps.damage = 8
	ps.pierce = 8 # Base for CBM
	ps.crit_frequency = 5
	ps.crit_extra_damage = 80 # Total, not additive
	ps.damage_type = "Normal"
	_update_can_pop_lead(ps)
	ps.speed *= 1.1 # Guess
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

	# --- Duplicate the base stats to avoid modifying originals ---
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

	# --- Apply Attack Speed Multipliers (Specific Logic after base stats are modified) ---
	# NOTE: Path 1 T3+ and Path 3 T4+ set their own absolute cooldowns in their funcs.
	# Path 2 speed boosts should only apply if not overridden by Path 1/3 later tiers.
	var cooldown_multiplier = 1.0
	var is_speed_overridden = (p1 >= 3) or (p3 >= 4) # Check if path 1/3 overrides speed

	if tower_name == "dart-monkey" and not is_speed_overridden:
		# Base cooldown is 0.95s
		match p2: # Apply path 2 speed boosts cumulatively
			1: cooldown_multiplier *= 0.85 # 0.95 * 0.85 = 0.8075s
			2: cooldown_multiplier *= 0.85 * (0.8075 / 0.95 * 0.7882) # ~0.67 total multi -> 0.6365s
			   # Simplification: Use target values directly if known
			   # cooldown_multiplier = 0.67 # Target multiplier for T2
			   current_tower_stats.attack_cooldown = 0.6365 # Set directly based on 020 stats
			3: # Triple shot: 75%s relative to T2 -> 0.6365 * 0.75 = 0.4774s
			   current_tower_stats.attack_cooldown = 0.4774
			4: # Fan Club: 50%s relative to T3 -> 0.4774 * 0.5 = 0.2387s
			   current_tower_stats.attack_cooldown = 0.2387
			5: # PMFC: Same speed as T4
			   current_tower_stats.attack_cooldown = 0.2387

		# Apply multiplier only if T2 wasn't reached (direct values used above for T2+)
		if p2 < 2:
			current_tower_stats.attack_cooldown *= cooldown_multiplier

	# Crosspath Benefits application (Example: Path 3 T2 knockback boost for Jugg T4/5)
	if tower_name == "dart-monkey" and p1 >= 4 and p3 >= 2: # Juggernaut T4/5 with Enhanced Eyesight T2+
		current_projectile_stats.knockback_slow_ceramic_lead = -2.0 # -200%
		current_projectile_stats.knockback_slow_other = -8.0 # -800%

	# print_debug("Final Stats for %s %s:" % [tower_name, upgrade_path_str])
	# print_debug("  Tower: Range=%.1f, Cooldown=%.2f, Camo=%s" % [current_tower_stats.range, current_tower_stats.attack_cooldown, current_tower_stats.can_see_camo])
	# print_debug("  Projectile: Dmg=%d, Pierce=%d, Speed=%.1f, Type=%s" % [
		# current_projectile_stats.damage,
		# current_projectile_stats.pierce,
		# current_projectile_stats.speed,
		# current_projectile_stats.damage_type
	#])

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
