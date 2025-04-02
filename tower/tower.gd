# File: res://tower/tower.gd
extends Node3D

# Stats are dynamically assigned/updated
@export var stats: TowerStats
@export var projectile_stats: ProjectileStats

# --- NEW: Tower State ---
var tower_name: String = "unknown"
var upgrade_levels: Array[int] = [0, 0, 0] # Path 1, Path 2, Path 3 tiers
var total_spent: int = 0

@onready var range_area: Area3D = $Area3D
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var projectile_spawn_point: Marker3D = $ProjectileSpawnPoint
@onready var range_collision_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var targets_in_range = []
var _projectile_pool: Array[Node] = []
@export var projectile_pool_size: int = 10

# No _ready() needed here anymore, configuration happens after stats are set

# --- NEW: Called by Main.gd after instantiation and stat assignment ---
func set_initial_state(p_tower_name: String, base_cost: int):
	tower_name = p_tower_name
	total_spent = base_cost
	upgrade_levels = [0, 0, 0] # Ensure reset on placement
	# Initial configuration based on assigned 0-0-0 stats
	_configure_tower()
	# Initialize pool after configuration
	_initialize_projectile_pool()
	# Connect signals here, ensuring nodes are ready
	_connect_signals()


func _connect_signals():
	cooldown_timer = $CooldownTimer
	if range_area and not range_area.area_entered.is_connected(_on_range_area_entered):
		range_area.area_entered.connect(_on_range_area_entered)
	if range_area and not range_area.area_exited.is_connected(_on_range_area_exited):
		range_area.area_exited.connect(_on_range_area_exited)
	if cooldown_timer and not cooldown_timer.timeout.is_connected(_on_cooldown_timer_timeout):
		cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
	elif not cooldown_timer:
		printerr("CooldownTimer node not found in Tower %s!" % name)


func _configure_tower():
	if not stats or not projectile_stats:
		printerr("Tower %s configure failed: Stats not ready." % name)
		return

	# print_debug("Configuring tower %s with path %s" % [name, get_upgrade_path_string()])
	if mesh_instance and stats.mesh:
		mesh_instance.mesh = stats.mesh
	elif mesh_instance:
		print_debug("Tower %s configured, but no mesh found in stats." % name)

	range_collision_shape = $Area3D/CollisionShape3D
	if range_collision_shape and range_collision_shape.shape:
		# Use CylinderShape3D or SphereShape3D depending on what you use in the scene
		if range_collision_shape.shape is CylinderShape3D:
			range_collision_shape.shape.radius = stats.range
			# Optionally adjust height if needed: range_collision_shape.shape.height = some_value
		elif range_collision_shape.shape is SphereShape3D:
			range_collision_shape.shape.radius = stats.range
		else:
			printerr("Tower %s range shape is not Cylinder or Sphere!" % name)

	else:
		printerr("Tower %s missing CollisionShape3D or shape for range area!" % name)
	cooldown_timer = $CooldownTimer
	if cooldown_timer:
		cooldown_timer.wait_time = stats.attack_cooldown
		cooldown_timer.one_shot = true # Ensure it's one_shot
		cooldown_timer.stop() # Ensure it starts stopped
	else:
		printerr("Cannot configure cooldown timer - node not found!")


func _initialize_projectile_pool():
	# Clear existing pool first in case of reconfiguration
	for proj in _projectile_pool:
		if is_instance_valid(proj): proj.queue_free()
	_projectile_pool.clear()

	if not stats or not projectile_stats or not stats.projectile_scene:
		printerr("Tower %s cannot initialize projectile pool: Missing stats or scene." % name)
		return

	# print_debug("Tower %s initializing projectile pool (Size: %d)" % [name, projectile_pool_size])
	for i in range(projectile_pool_size):
		var proj = stats.projectile_scene.instantiate()
		# --- FIX START ---
		# Check if it's the correct type and has the necessary methods/script
		if proj is Area3D and proj.has_method("set_stats") and proj.has_method("pool_reset"):
			proj.owner_tower = self # Assign owner first
			proj.set_stats(projectile_stats) # Use the method to set stats and apply mesh/timer
			# No need to set mesh here, set_stats handles it
			_projectile_pool.append(proj)
			# print_debug("Added projectile %s to pool for tower %s" % [proj.name, name]) # Optional debug
		# --- FIX END ---
		else:
			printerr("Instantiated projectile scene is invalid or missing methods/properties for pooling.")
			if is_instance_valid(proj): proj.queue_free()


func _physics_process(delta):
	if not stats or not projectile_stats: return # Don't process if not configured
	
	# Filter out invalid targets first
	#print('original ', targets_in_range)
	targets_in_range = targets_in_range.filter(_is_target_valid)
	#print('new ', targets_in_range)
	# Check if ready to fire
	if not targets_in_range.is_empty() and cooldown_timer.is_stopped():
		var target = choose_target()
		if is_instance_valid(target): # Double check target validity
			attack(target)
		# else: print_debug("Chosen target was invalid.") # Optional debug


func _is_target_valid(node):
	# Check if the node itself is valid
	if not is_instance_valid(node):
		# print_debug("Target invalid: Node instance is not valid.") # Optional debug
		return false
	# Check if it's still in the scene tree (might have been removed by pooling)
	if not node.is_inside_tree():
		# print_debug("Target invalid: Node %s is not in tree." % node.name) # Optional debug
		return false
	# Check if it's a bloon (has stats)
	if not node.has_method("get") or node.get("stats") == null:
		# print_debug("Target invalid: Node %s has no stats." % node.name) # Optional debug
		return false
	var node_stats: BloonStats = node.stats
	# Check camo visibility
	if node_stats.is_camo and (not stats or not stats.can_see_camo):
		# print_debug("Target invalid: Node %s is camo, tower cannot see camo." % node.name) # Optional debug
		return false
	# Add any other checks if needed (e.g., specific immunities)
	return true


func choose_target():
	# Simple target selection: Choose the bloon furthest along the path
	var best_target = null
	var max_progress = -1.0
	for bloon_node in targets_in_range:
		# No need to call _is_target_valid again if filtered in _physics_process
		# but double-checking doesn't hurt if timing issues are suspected.
		# if not _is_target_valid(bloon_node): continue
		if bloon_node is PathFollow3D:
			# Use progress_ratio for consistency (0.0 to 1.0)
			if bloon_node.progress_ratio > max_progress:
				max_progress = bloon_node.progress_ratio
				best_target = bloon_node
	return best_target


func attack(target: Node3D):
	if not stats or not projectile_stats or not stats.projectile_scene:
		printerr("Attack cancelled: Missing stats or projectile scene.")
		return

	var projectile_instance: Node = null
	if not _projectile_pool.is_empty():
		projectile_instance = _projectile_pool.pop_back()
		# Reset should be called *after* retrieving from pool
		if projectile_instance.has_method("pool_reset"):
			projectile_instance.pool_reset()
		# print_debug("Reusing projectile from pool.") # Optional debug
	else:
		printerr("Tower %s projectile pool empty! Instantiating fallback." % name)
		projectile_instance = stats.projectile_scene.instantiate()
		# --- FIX START ---
		# Check if it's the correct type and has the necessary methods/script
		if projectile_instance is Area3D and projectile_instance.has_method("set_stats") and projectile_instance.has_method("pool_reset"):
			projectile_instance.owner_tower = self
			projectile_instance.set_stats(projectile_stats) # Use the method
			# print_debug("Instantiated fallback projectile.") # Optional debug
		# --- FIX END ---
		else:
			printerr("Fallback projectile instance is invalid!")
			if is_instance_valid(projectile_instance): projectile_instance.queue_free()
			return # Don't proceed if fallback failed

	# Ensure projectile instance is valid before proceeding
	if not is_instance_valid(projectile_instance):
		printerr("Attack failed: Projectile instance became invalid.")
		# Attempt to return it to pool if possible? Or just log error.
		return

	# --- Aim and Position ---
	# Ensure target is still valid before looking at it
	if not is_instance_valid(target):
		printerr("Attack cancelled: Target became invalid before firing.")
		# Return projectile to pool without firing
		_return_projectile_to_pool(projectile_instance)
		return

	look_at(target.global_position, Vector3.UP) # Aim the tower
	# Add projectile to the main scene tree (or a dedicated projectiles node)
	get_tree().root.add_child(projectile_instance)
	# Set projectile's position/rotation *after* adding to tree
	projectile_instance.global_transform = projectile_spawn_point.global_transform

	# --- Configure and Activate Projectile ---
	# Set target for homing projectiles
	if projectile_instance.has_method("set_target"):
		projectile_instance.set_target(target)
	# Set initial direction for non-homing
	elif projectile_instance.has_method("initialize_direction"):
		# Use the projectile's forward direction after being placed
		projectile_instance.initialize_direction(projectile_instance.global_transform.basis.z)

	# Activate the projectile (e.g., start its lifetime timer)
	if projectile_instance.has_method("activate"):
		projectile_instance.activate()
	else:
		printerr("Projectile %s missing activate() method!" % projectile_instance.name)

	# --- Start Cooldown ---
	cooldown_timer.start()
	# print_debug("Tower fired! Cooldown started.") # Optional debug


func _return_projectile_to_pool(projectile: Node):
	if not is_instance_valid(projectile):
		# print_debug("Attempted to return invalid projectile to pool.") # Optional debug
		return
	# Check if it's already in the pool to prevent duplicates
	if not projectile in _projectile_pool:
		_projectile_pool.append(projectile)
		# print_debug("Returned projectile %s to pool. Pool size: %d" % [projectile.name, _projectile_pool.size()]) # Optional debug
	# else: print_debug("Projectile %s already in pool?" % projectile.name) # Optional debug


func _on_range_area_entered(area: Area3D):
	print('yyy')
	if not stats: return # Tower not configured
	var parent_node = area.get_parent()

	# Check if it's a valid bloon node entering
	if not (is_instance_valid(parent_node) and parent_node.is_in_group("bloons")):
		return

	# Check if it has stats (might be redundant with group check but safe)
	if not parent_node.has_method("get") or parent_node.get("stats") == null:
		return

	var bloon_stats: BloonStats = parent_node.stats

	# Check for camo if necessary
	if bloon_stats.is_camo and not stats.can_see_camo:
		return # Ignore camo bloons if tower can't see them

	# Add to list if not already present
	if not parent_node in targets_in_range:
		targets_in_range.append(parent_node)
		# print_debug("Bloon entered range: %s. Targets: %d" % [parent_node.name, targets_in_range.size()]) # Optional debug


func _on_range_area_exited(area: Area3D):
	var parent_node = area.get_parent()
	# Remove if it exists in the list
	if parent_node in targets_in_range:
		targets_in_range.erase(parent_node)
		# print_debug("Bloon exited range: %s. Targets: %d" % [parent_node.name, targets_in_range.size()]) # Optional debug


func _on_cooldown_timer_timeout():
	# This function simply allows the timer's `is_stopped()` check to become true again.
	# No action needed here unless you want to trigger something specific on cooldown end.
	# print_debug("Cooldown finished.") # Optional debug
	pass


func _exit_tree():
	# Clean up projectiles when the tower is removed
	# print_debug("Tower %s exiting tree. Cleaning up %d pooled projectiles." % [name, _projectile_pool.size()]) # Optional debug
	for proj in _projectile_pool:
		if is_instance_valid(proj):
			# If the projectile is parented to root, free it directly
			if proj.get_parent() == get_tree().root:
				proj.queue_free()
			# Otherwise, let normal cleanup handle it (or free if necessary)
	_projectile_pool.clear()
	targets_in_range.clear() # Clear target list too

# --- NEW: Upgrade Logic ---

func get_upgrade_level(path_index: int) -> int:
	if path_index >= 1 and path_index <= 3:
		return upgrade_levels[path_index - 1]
	return -1 # Invalid path

func get_upgrade_path_string() -> String:
	return "%d%d%d" % [upgrade_levels[0], upgrade_levels[1], upgrade_levels[2]]

# Basic BTD6 path locking: Cannot have more than 2 paths with tier >= 3,
# and cannot have tiers like 3-3-0, 0-3-3, 3-0-3, etc. Only one path can go past tier 2 if another is already tier 3+.
# Or more simply: Sum of tiers on other paths cannot exceed 2 if this path goes to tier 3+.
func is_path_locked(path_index_to_check: int) -> bool:
	if path_index_to_check < 1 or path_index_to_check > 3: return true # Invalid path is locked

	var current_tier = upgrade_levels[path_index_to_check - 1]
	if current_tier >= 5: return true # Already max tier

	# Check BTD6 cross-pathing rules (simplified)
	# If you want to upgrade path X beyond tier 2 (i.e., to tier 3, 4, or 5)
	# the sum of the tiers of the *other two* paths cannot exceed 2.
	if current_tier >= 2: # If we are considering upgrading to tier 3 or higher
		var other_path1_idx = -1
		var other_path2_idx = -1
		# Determine the indices of the *other* two paths (0-based)
		match path_index_to_check:
			1: # Checking path 1, others are 2 (idx 1) and 3 (idx 2)
				other_path1_idx = 1
				other_path2_idx = 2
			2: # Checking path 2, others are 1 (idx 0) and 3 (idx 2)
				other_path1_idx = 0
				other_path2_idx = 2
			3: # Checking path 3, others are 1 (idx 0) and 2 (idx 1)
				other_path1_idx = 0
				other_path2_idx = 1

		if other_path1_idx != -1 and other_path2_idx != -1:
			var other_path1_tier = upgrade_levels[other_path1_idx]
			var other_path2_tier = upgrade_levels[other_path2_idx]

			if other_path1_tier + other_path2_tier > 2:
				# print_debug("Path %d locked: Other paths (%d, %d) sum to %d > 2" % [path_index_to_check, other_path1_tier, other_path2_tier, other_path1_tier + other_path2_tier])
				return true

	# Also, a path cannot be upgraded if it's already tier 2 and another path is tier 3+
	# This rule prevents paths like 3-2-2 or 2-3-2.
	if current_tier == 2:
		for i in range(3):
			# Check if *another* path (not the one we're checking) is already tier 3 or higher
			if i != (path_index_to_check - 1) and upgrade_levels[i] >= 3:
				# print_debug("Path %d locked: Cannot upgrade path to tier 3+ because path %d is already tier %d" % [path_index_to_check, i+1, upgrade_levels[i]])
				return true

	return false


func apply_upgrade(path_index: int, tier: int, cost: int) -> bool:
	# --- Validation ---
	if path_index < 1 or path_index > 3:
		printerr("ApplyUpgrade: Invalid path index ", path_index)
		return false
	# Ensure we are upgrading to the *next* tier sequentially
	if tier != upgrade_levels[path_index - 1] + 1:
		printerr("ApplyUpgrade: Invalid tier %d for path %d (current is %d)" % [tier, path_index, upgrade_levels[path_index - 1]])
		return false
	if is_path_locked(path_index):
		printerr("ApplyUpgrade: Path %d is locked." % path_index)
		return false
	if tier > 5:
		printerr("ApplyUpgrade: Tier %d exceeds max." % tier)
		return false

	# --- Get New Stats ---
	# Create a temporary copy of levels to generate the next path string
	var next_upgrade_levels = upgrade_levels.duplicate()
	next_upgrade_levels[path_index - 1] = tier
	var next_upgrade_path_str = "%d%d%d" % [next_upgrade_levels[0], next_upgrade_levels[1], next_upgrade_levels[2]]

	var new_stats_dict = TowerFactory.create_stats(tower_name, next_upgrade_path_str)
	if not new_stats_dict or not new_stats_dict.has("tower") or not new_stats_dict.has("projectile"):
		printerr("ApplyUpgrade: Failed to get new stats from factory for %s path %s" % [tower_name, next_upgrade_path_str])
		return false

	# --- Apply Changes ---
	print("Applying upgrade %s to tower %s" % [next_upgrade_path_str, name])
	self.stats = new_stats_dict.tower # Apply new tower stats
	self.projectile_stats = new_stats_dict.projectile # Apply new projectile stats
	upgrade_levels[path_index - 1] = tier # Update internal level tracking *after* success
	total_spent += cost

	# Reconfigure visuals, range, cooldown based on new TowerStats
	_configure_tower()
	# Re-initialize the projectile pool with new ProjectileStats (clears old, creates new)
	_initialize_projectile_pool()

	# Optional: Force a target re-evaluation if range/camo changed significantly
	# targets_in_range.clear() # Or re-check existing targets

	return true
