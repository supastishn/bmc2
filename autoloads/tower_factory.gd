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
const TowerLoader = preload("res://autoloads/tower_loader.gd")
# --- Tower Meshes ---
const DART_MONKEY_MESH = preload("res://meshes/dart_monkey_mesh.tres")
const BOOMERANG_MONKEY_MESH = preload("res://meshes/boomerang_monkey_mesh.tres")
const BOMB_SHOOTER_MESH = preload("res://meshes/bomb_shooter_mesh.tres")
const TACK_SHOOTER_MESH = preload("res://meshes/tack_shooter_mesh.tres")
const ICE_MONKEY_MESH = preload("res://meshes/ice_monkey_mesh.tres")
const GLUE_GUNNER_MESH = preload("res://meshes/glue_gunner_mesh.tres")
const SNIPER_MONKEY_MESH = preload("res://meshes/sniper_monkey_mesh.tres")
const MONKEY_SUB_MESH = preload("res://meshes/monkey_sub_mesh.tres")
const MONKEY_BUCCANEER_MESH = preload("res://meshes/monkey_buccaneer_mesh.tres")
const MONKEY_ACE_MESH = preload("res://meshes/monkey_ace_mesh.tres")
const HELI_PILOT_MESH = preload("res://meshes/heli_pilot_mesh.tres")
const MORTAR_MONKEY_MESH = preload("res://meshes/mortar_monkey_mesh.tres")
const DARTLING_GUNNER_MESH = preload("res://meshes/dartling_gunner_mesh.tres")
const WIZARD_MONKEY_MESH = preload("res://meshes/wizard_monkey_mesh.tres")
const SUPER_MONKEY_MESH = preload("res://meshes/super_monkey_mesh.tres")
const NINJA_MONKEY_MESH = preload("res://meshes/ninja_monkey_mesh.tres")
const ALCHEMIST_MESH = preload("res://meshes/alchemist_mesh.tres")
const DRUID_MESH = preload("res://meshes/druid_mesh.tres")
const BANANA_FARM_MESH = preload("res://meshes/banana_farm_mesh.tres")
const SPIKE_FACTORY_MESH = preload("res://meshes/spike_factory_mesh.tres")
const MONKEY_VILLAGE_MESH = preload("res://meshes/monkey_village_mesh.tres")
const ENGINEER_MONKEY_MESH = preload("res://meshes/engineer_monkey_mesh.tres")

# --- Projectile Meshes ---
const DART_PROJECTILE_MESH = preload("res://meshes/dart_projectile_mesh.tres")
const BOOMERANG_PROJECTILE_MESH = preload("res://meshes/boomerang_projectile_mesh.tres")
const BOMB_PROJECTILE_MESH = preload("res://meshes/bomb_projectile_mesh.tres")
const TACK_PROJECTILE_MESH = preload("res://meshes/tack_projectile_mesh.tres")
const ICE_PROJECTILE_MESH = preload("res://meshes/ice_projectile_mesh.tres")
const GLUE_PROJECTILE_MESH = preload("res://meshes/glue_projectile_mesh.tres")
const SNIPER_PROJECTILE_MESH = preload("res://meshes/sniper_projectile_mesh.tres")
const HARPOON_PROJECTILE_MESH = preload("res://meshes/harpoon_projectile_mesh.tres")
const CANNONBALL_PROJECTILE_MESH = preload("res://meshes/cannonball_projectile_mesh.tres")
const ACE_PROJECTILE_MESH = preload("res://meshes/ace_projectile_mesh.tres")
const HELI_PROJECTILE_MESH = preload("res://meshes/heli_projectile_mesh.tres")
const MORTAR_PROJECTILE_MESH = preload("res://meshes/mortar_projectile_mesh.tres")
const DART_LASER_MESH = preload("res://meshes/dart_laser_mesh.tres")
const MAGIC_BOLT_MESH = preload("res://meshes/magic_bolt_mesh.tres")
const LASER_PROJECTILE_MESH = preload("res://meshes/laser_projectile_mesh.tres")
const SHURIKEN_PROJECTILE_MESH = preload("res://meshes/shuriken_projectile_mesh.tres")
const POTION_PROJECTILE_MESH = preload("res://meshes/potion_projectile_mesh.tres")
const THORN_PROJECTILE_MESH = preload("res://meshes/thorn_projectile_mesh.tres")
const SPIKE_PROJECTILE_MESH = preload("res://meshes/spike_projectile_mesh.tres")
const NAIL_PROJECTILE_MESH = preload("res://meshes/nail_projectile_mesh.tres")

# --- Upgrade Meshes ---
const SHARP_SHOTS_PROJECTILE_MESH = preload("res://meshes/sharp_dart_mesh.tres")
const SPIKEBALL_MESH = preload("res://meshes/spikeball_mesh.tres")
const JUGGERNAUT_MESH = preload("res://meshes/juggernaut_mesh.tres")
const MINI_JUGGERNAUT_MESH = preload("res://meshes/mini_juggernaut_mesh.tres")
const BOLT_MESH = preload("res://meshes/bolt_mesh.tres")

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
			"tower": TowerStats.new(0.95, 3.2, false, BASE_PROJECTILE_SCENE, DART_MONKEY_MESH),
			"projectile": ProjectileStats.new(35.0, 1, 0.7, 2, false, 5.0, DART_PROJECTILE_MESH, "Sharp"),
			"cost": 200
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
	},
	# --- Phase 1: Additional towers (base only, abilities/auras stubbed) ---
	"boomerang-monkey": {
		"base": {
			"tower": TowerStats.new(1.0, 3.2, false, BASE_PROJECTILE_SCENE, null),
			"projectile": ProjectileStats.new(25.0, 1, 0.8, 4, false, 5.0, null, "Sharp"),
			"cost": 325
		},
		"path1": {}, "path2": {}, "path3": {}
	},
	"bomb-shooter": {
		"base": {
			"tower": TowerStats.new(1.4, 3.6, false, BASE_PROJECTILE_SCENE, null),
			"projectile": ProjectileStats.new(22.0, 1, 0.9, 30, false, 5.0, null, "Explosive"),
			"cost": 650
		},
		"path1": {}, "path2": {}, "path3": {}
	},
	"tack-shooter": {
		"base": {
			"tower": TowerStats.new(1.1, 2.5, false, BASE_PROJECTILE_SCENE, null),
			"projectile": ProjectileStats.new(30.0, 1, 0.5, 1, false, 5.0, null, "Sharp"),
			"cost": 300
		},
		"path1": {}, "path2": {}, "path3": {}
	},
	"sniper-monkey": {
		"base": {
			"tower": TowerStats.new(1.5, 100.0, true, BASE_PROJECTILE_SCENE, null),
			"projectile": ProjectileStats.new(120.0, 2, 1.0, 1, false, 5.0, null, "Sharp"),
			"cost": 300
		},
		"path1": {}, "path2": {}, "path3": {}
	},
	"ninja-monkey": {
		"base": {
			"tower": TowerStats.new(0.95, 3.5, true, BASE_PROJECTILE_SCENE, null),
			"projectile": ProjectileStats.new(32.0, 1, 0.7, 2, false, 5.0, null, "Sharp"),
			"cost": 425
		},
		"path1": {}, "path2": {}, "path3": {}
	},
	"wizard-monkey": {
		"base": {
			"tower": TowerStats.new(1.0, 3.6, false, BASE_PROJECTILE_SCENE, null),
			"projectile": ProjectileStats.new(40.0, 1, 0.8, 2, false, 5.0, null, "Energy"),
			"cost": 450
		},
		"path1": {}, "path2": {}, "path3": {}
	},
	"super-monkey": {
		"base": {
			"tower": TowerStats.new(0.055, 4.5, false, BASE_PROJECTILE_SCENE, null),
			"projectile": ProjectileStats.new(60.0, 1, 0.5, 1, false, 5.0, null, "Sharp"),
			"cost": 2500
		},
		"path1": {}, "path2": {}, "path3": {}
	}
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

\tvar base_data = tower_data[tower_name].get("base")
\tif not base_data or not base_data.has("tower") or not base_data.has("projectile"):
\t\tprinterr("TowerFactory: Base data missing for '", tower_name, "'")
\t\treturn {}

	# --- Duplicate the base stats to avoid modifying originals ---
	# use shallow duplicate so we don’t accidentally share/choke on sub-resources
	var current_tower_stats: TowerStats = base_data.tower.duplicate()
	var current_projectile_stats: ProjectileStats = base_data.projectile.duplicate()

	# Ensure scenes are assigned
	current_tower_stats.projectile_scene = BASE_PROJECTILE_SCENE if current_tower_stats.projectile_scene == null else current_tower_stats.projectile_scene
	# For projectiles, mesh can be null; projectile.gd handles default

\t# Optionally load JSON definition for this tower (data-driven)
\tvar json_def: Dictionary = TowerLoader.load_tower_json(tower_name)

\t# Parse upgrade path levels
\tvar p1 = int(upgrade_path_str[0])

	var p2 = int(upgrade_path_str[1])
	var p3 = int(upgrade_path_str[2])
	var path_levels = [p1, p2, p3]

\t# If JSON exists, apply base overrides then JSON path mods; else use built-ins
\tif not json_def.is_empty():
\t\tif json_def.has("base"):
\t\t\tTowerLoader.apply_mods(current_tower_stats, current_projectile_stats, json_def.base)
\t\tfor path_idx in range(3):
\t\t\tvar max_level = path_levels[path_idx]
\t\t\tvar pkey = "path" + str(path_idx + 1)
\t\t\tif json_def.has(pkey):
\t\t\t\tvar path_def: Dictionary = json_def[pkey]
\t\t\t\tfor level in range(1, max_level + 1):
\t\t\t\t\tvar key = str(level)
\t\t\t\t\tif path_def.has(key) and path_def[key].has("mods"):
\t\t\t\t\t\tTowerLoader.apply_mods(current_tower_stats, current_projectile_stats, path_def[key].mods)
\telse:
\t\t# Apply upgrades sequentially for each path based on levels using built-ins
\t\tfor path_idx in range(3):
\t\t\tvar max_level = path_levels[path_idx]
\t\t\t_apply_path_upgrades(tower_name, path_idx + 1, max_level, current_tower_stats, current_projectile_stats)

	# --- Path-2 pure overrides for Dart Monkey attack_cooldown (point 2) ---
\tif tower_name == "dart-monkey" and json_def.is_empty():
\t\tmatch p2:
\t\t\t1:
\t\t\t\tcurrent_tower_stats.attack_cooldown = 0.95 * 0.85
			2:
				current_tower_stats.attack_cooldown = 0.6365
			3:
				current_tower_stats.attack_cooldown = 0.4774
			4, 5:
				current_tower_stats.attack_cooldown = 0.2387

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
    # Prefer JSON-defined metadata if available
    var json_def: Dictionary = TowerLoader.load_tower_json(tower_name)
    if not json_def.is_empty():
        var path_key = "path" + str(path_index)
        if json_def.has(path_key):
            var pdef: Dictionary = json_def[path_key]
            var key = str(tier)
            if pdef.has(key):
                var meta := {}
                if pdef[key].has("name"): meta["name"] = pdef[key].name
                if pdef[key].has("cost"): meta["cost"] = pdef[key].cost
                if pdef[key].has("desc"): meta["desc"] = pdef[key].desc
                return meta
        return {}

    # Fallback to built-in data
    if not tower_data.has(tower_name): return {}
    var path_key2 = "path" + str(path_index)
    if not tower_data[tower_name].has(path_key2): return {}
    var path_upgrades = tower_data[tower_name][path_key2]
    if path_upgrades.has(tier):
        var details = path_upgrades[tier].duplicate()
        details.erase("func")
        return details
    return {}


## --- NEW: Get base cost of a tower ---
func get_base_cost(tower_name: String) -> int:
	var json_def: Dictionary = TowerLoader.load_tower_json(tower_name)
	if not json_def.is_empty() and json_def.has("base") and json_def.base.has("cost"):
		return int(json_def.base.cost)
	if tower_data.has(tower_name) and tower_data[tower_name].has("base") and tower_data[tower_name].base.has("cost"):
		return tower_data[tower_name].base.cost
	printerr("TowerFactory: Base cost not found for '", tower_name, "'")
	return 999999 # Return high value on error
