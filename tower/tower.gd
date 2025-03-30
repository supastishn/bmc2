# File: res://tower/tower.gd
extends Node3D

@export var stats: TowerStats
@export var projectile_stats: ProjectileStats # Assigned by Main.gd after factory call

# --- NEW STATE VARIABLES ---
var tower_name: String = "unknown" # Set by Main.gd on placement
var upgrade_path: String = "000"   # Current upgrade path (e.g., "102")
var total_spent: int = 0           # Tracks base cost + upgrade costs

@onready var range_area: Area3D = $Area3D
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var projectile_spawn_point: Marker3D = $ProjectileSpawnPoint
@onready var range_collision_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
# Ensure PlacementBody exists and has a CollisionShape3D for clicking
@onready var placement_body: StaticBody3D = $PlacementBody
@onready var placement_collision_shape: CollisionShape3D = $PlacementBody/CollisionShape3D


var targets_in_range = []

# --- Tower's Local Projectile Pool ---
var _projectile_pool: Array[Node] = []
@export var projectile_pool_size: int = 10 # How many projectiles to pre-warm

func _ready():
	# Basic validation and fallbacks (consider if fallbacks are desired)
	if not stats:
		printerr("Tower %s missing its TowerStats resource! Using default." % name)
		stats = TowerStats.new() # Assign a default to prevent crashes
	if not projectile_stats:
		printerr("Tower %s missing its ProjectileStats resource! Using default." % name)
		projectile_stats = ProjectileStats.new() # Assign a default
	if not stats.projectile_scene:
		printerr("Tower %s stats resource is missing its Projectile Scene! Using default." % name)
		# Assign a default scene if possible, otherwise attacking will fail
		stats.projectile_scene = preload("res://projectile/projectile.tscn")

	# Defer configuration to ensure stats are likely assigned by Main.gd
	call_deferred("_configure_tower")

	# Connect signals
	if not range_area.area_entered.is_connected(_on_range_area_entered):
		range_area.area_entered.connect(_on_range_area_entered)
	if not range_area.area_exited.is_connected(_on_range_area_exited):
		range_area.area_exited.connect(_on_range_area_exited)

	# Ensure CooldownTimer exists and connect its timeout signal
	if not cooldown_timer:
		printerr("CooldownTimer node not found in Tower %s!" % name)
		set_physics_process(false) # Disable processing if timer is missing
		return
	# Check connection status before connecting
	if not cooldown_timer.timeout.is_connected(_on_cooldown_timer_timeout):
		cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)

	# Initialize the local projectile pool (deferred)
	call_deferred("_initialize_projectile_pool")

	# Ensure the placement body is on a layer Main.gd can raycast against
	if placement_body:
		placement_body.collision_layer = 1 << (6 - 1) # Example: Layer 6 for placed towers
		placement_body.collision_mask = 0 # Doesn't need to detect anything itself
	else:
		printerr("Tower %s missing PlacementBody!" % name)


# Deferred setup function
func _configure_tower():
	# Check again if stats are valid before configuring
	if not stats or not projectile_stats:
		printerr("Tower %s configure deferred: Stats still not ready." % name)
		return

	print_debug("Configuring tower %s (%s)" % [name, upgrade_path])
	if mesh_instance and stats.mesh:
		mesh_instance.mesh = stats.mesh

	# Update range visualization/collision shape
	if range_collision_shape and range_collision_shape.shape:
		if range_collision_shape.shape is CylinderShape3D or range_collision_shape.shape is SphereShape3D:
			range_collision_shape.shape.radius = stats.range
			# Optional: Update visual range indicator if you have one
		else:
			print_debug("Tower %s range shape is not Cylinder or Sphere." % name)
	else:
		printerr("Tower %s missing CollisionShape3D or shape for range area!" % name)

	# Configure cooldown timer properties
	cooldown_timer.wait_time = stats.attack_cooldown
	cooldown_timer.one_shot = true # Ensure it's one-shot

	# Re-initialize projectile pool if stats changed significantly (optional, might be overkill)
	# Consider if projectile stats changes require pool re-initialization
	# call_deferred("_initialize_projectile_pool") # Maybe not needed if pool handles stats correctly


# Pre-warms the tower's specific projectile pool
func _initialize_projectile_pool():
	if not stats or not projectile_stats or not stats.projectile_scene:
		printerr("Tower %s cannot initialize projectile pool: Missing stats or scene." % name)
		return

	# Clear existing pool before re-initializing (important if called after upgrade)
	for proj in _projectile_pool:
		if is_instance_valid(proj):
			proj.queue_free()
	_projectile_pool.clear()

	print("Tower %s initializing projectile pool (Size: %d)" % [name, projectile_pool_size])
	for i in range(projectile_pool_size):
		var proj = stats.projectile_scene.instantiate()
		# Check for necessary properties/methods before configuration
		if proj is Area3D and proj.has_method('set_stats') and proj.has_method("pool_reset"): # Assuming set_stats method exists
			proj.set_stats(projectile_stats) # Pass the specific stats
			proj.owner_tower = self
			# Mesh is now set within projectile based on its stats
			_projectile_pool.append(proj)
		else:
			printerr("Instantiated projectile scene is invalid or missing methods/properties for pooling.")
			if is_instance_valid(proj): proj.queue_free()


func _physics_process(delta):
	# Ensure stats are loaded before processing physics
	if not stats or not projectile_stats: return

	targets_in_range = targets_in_range.filter(Callable(self, "_is_target_valid"))
	if not targets_in_range.is_empty() and cooldown_timer.is_stopped():
		var target = choose_target()
		if is_instance_valid(target):
			attack(target)


func _is_target_valid(node):
	# ... (no changes needed here) ...
	if not is_instance_valid(node): return false
	var node_stats: BloonStats = null
	# Use safer 'get' method check
	if node.has_method("get",):
		node_stats = node.stats
	if node_stats and node_stats.is_camo and (not stats or not stats.can_see_camo):
		return false
	return true


func choose_target():
	# ... (no changes needed here) ...
	var best_target = null; var max_progress = -1.0
	for bloon_node in targets_in_range:
		if not _is_target_valid(bloon_node): continue
		if bloon_node is PathFollow3D:
			if bloon_node.progress > max_progress:
				max_progress = bloon_node.progress; best_target = bloon_node
	return best_target


func attack(target: Node3D):
	# ... (no changes needed here, relies on current stats) ...
	if not stats or not projectile_stats or not stats.projectile_scene: return

	# --- Request projectile from LOCAL pool ---
	var projectile_instance: Node = null
	if not _projectile_pool.is_empty():
		projectile_instance = _projectile_pool.pop_back()
		if projectile_instance.has_method("pool_reset"):
			projectile_instance.pool_reset()
		# Ensure the reused projectile has the *current* stats
		if projectile_instance.has_method("set_stats"):
			projectile_instance.set_stats(projectile_stats)
	else:
		# Fallback: Pool empty, instantiate a new one
		printerr("Tower %s projectile pool empty! Instantiating fallback." % name)
		projectile_instance = stats.projectile_scene.instantiate()
		if projectile_instance is Area3D and projectile_instance.has_method('set_stats'):
			projectile_instance.set_stats(projectile_stats) # Assign current stats
			projectile_instance.owner_tower = self
		else:
			printerr("Fallback projectile instance is invalid!")
			if is_instance_valid(projectile_instance): projectile_instance.queue_free()
			return

	# --- Configure and Launch ---
	look_at(target.global_position, Vector3.UP)

	get_tree().root.add_child(projectile_instance)
	projectile_instance.global_transform = projectile_spawn_point.global_transform

	if projectile_instance.has_method("set_target"): projectile_instance.set_target(target)
	elif projectile_instance.has_method("initialize_direction"): projectile_instance.initialize_direction(projectile_instance.global_transform.basis.z)

	if projectile_instance.has_method("activate"): projectile_instance.activate()

	cooldown_timer.start()


# Called by projectiles when they finish
func _return_projectile_to_pool(projectile: Node):
	# ... (no changes needed here) ...
	if not is_instance_valid(projectile):
		printerr("Tower %s received invalid projectile to return." % name)
		return
	_projectile_pool.append(projectile)


func _on_range_area_entered(area: Area3D):
	# ... (no changes needed here) ...
	if not stats: return
	var parent_node = area.get_parent()
	if not (is_instance_valid(parent_node) and parent_node.is_in_group("bloons")): return
	var bloon_stats: BloonStats = null
	if parent_node.has_method("get"): bloon_stats = parent_node.stats
	if not bloon_stats : return
	if bloon_stats.is_camo and not stats.can_see_camo: return
	if not parent_node in targets_in_range:
		targets_in_range.append(parent_node)


func _on_range_area_exited(area: Area3D):
	# ... (no changes needed here) ...
	var parent_node = area.get_parent()
	if parent_node in targets_in_range:
		targets_in_range.erase(parent_node)


# Function called when the cooldown timer finishes
func _on_cooldown_timer_timeout():
	# ... (no changes needed here) ...
	pass


# Optional: Clean up pooled nodes when the tower is freed
func _exit_tree():
	# ... (no changes needed here) ...
	for proj in _projectile_pool:
		if is_instance_valid(proj):
			proj.queue_free()
	_projectile_pool.clear()


# --- NEW FUNCTIONS ---

## Called by Main.gd after instantiating the tower.
func set_initial_state(p_tower_name: String, p_base_cost: int):
	tower_name = p_tower_name
	upgrade_path = "000"
	total_spent = p_base_cost
	# Name the node in the scene tree for easier debugging (optional)
	name = "%s_%s" % [tower_name.capitalize(), upgrade_path]


## Applies an upgrade based on path index and tier. Called by Main.gd.
func apply_upgrade(path_index: int, tier: int, cost: int) -> bool:
	if path_index < 1 or path_index > 3 or tier <= 0:
		printerr("Tower %s: Invalid path/tier for upgrade: %d/%d" % [name, path_index, tier])
		return false

	# --- Basic Upgrade Path Validation ---
	var path_array = [int(upgrade_path[0]), int(upgrade_path[1]), int(upgrade_path[2])]

	# 1. Check if the requested tier is the next one for the path
	if path_array[path_index - 1] != tier - 1:
		printerr("Tower %s: Cannot apply tier %d for path %d. Current tier is %d." % [name, tier, path_index, path_array[path_index - 1]])
		return false

	# 2. BTD6 Rule: Cannot have more than 2 paths upgraded past tier 2.
	# 3. BTD6 Rule: Cannot upgrade a path to tier 3+ if another path is already tier 3+. (Cross-pathing limit)
	var tier3plus_paths = 0
	for i in range(3):
		if path_array[i] >= 3:
			tier3plus_paths += 1

	if tier >= 3:
		# Check if trying to make a second path tier 3+
		if tier3plus_paths > 0 and path_array[path_index - 1] < 3:
			printerr("Tower %s: Cannot upgrade path %d to tier 3+. Another path is already tier 3+." % [name, path_index])
			return false
		# Check if trying to upgrade a path beyond tier 2 when two *other* paths are already tier 2
		var tier2_paths = 0
		for i in range(3):
			if i != path_index - 1 and path_array[i] >= 2:
				tier2_paths += 1
		if tier2_paths >= 2:
			printerr("Tower %s: Cannot upgrade path %d past tier 2. Two other paths are already tier 2+." % [name, path_index])
			return false


	# --- Construct New Path String ---
	path_array[path_index - 1] = tier
	var new_upgrade_path = "%d%d%d" % [path_array[0], path_array[1], path_array[2]]

	print("Tower %s: Attempting upgrade from %s to %s" % [name, upgrade_path, new_upgrade_path])

	# --- Get New Stats from Factory ---
	var new_stats_dict = TowerFactory.create_stats(tower_name, new_upgrade_path)
	if not new_stats_dict or not new_stats_dict.has("tower") or not new_stats_dict.has("projectile"):
		printerr("Tower %s: Failed to get new stats from TowerFactory for path %s" % [name, new_upgrade_path])
		return false

	# --- Apply New Stats ---
	self.stats = new_stats_dict.tower
	self.projectile_stats = new_stats_dict.projectile # CRITICAL: Update projectile stats too

	# --- Update Internal State ---
	self.upgrade_path = new_upgrade_path
	self.total_spent += cost
	self.name = "%s_%s" % [tower_name.capitalize(), upgrade_path] # Update node name (optional)

	# --- Reconfigure Tower Visuals/Behavior ---
	# Use call_deferred to avoid issues if called during physics process or signal handling
	call_deferred("_configure_tower")
	# Re-initialize projectile pool as stats (especially projectile stats) have changed
	call_deferred("_initialize_projectile_pool")

	print("Tower %s: Upgrade successful to %s. Total spent: %d" % [name, upgrade_path, total_spent])
	return true
