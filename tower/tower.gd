# File: res://tower/tower.gd
extends Node3D

@export var stats: TowerStats
@export var projectile_stats: ProjectileStats # Assigned by Main.gd after factory call

@onready var range_area: Area3D = $Area3D
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var projectile_spawn_point: Marker3D = $ProjectileSpawnPoint
@onready var range_collision_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

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


# Deferred setup function
func _configure_tower():
	# Check again if stats are valid before configuring
	if not stats or not projectile_stats:
		printerr("Tower %s configure deferred: Stats still not ready." % name)
		return

	print_debug("Configuring tower %s" % name)
	if mesh_instance and stats.mesh:
		mesh_instance.mesh = stats.mesh

	if range_collision_shape and range_collision_shape.shape:
		if range_collision_shape.shape is CylinderShape3D or range_collision_shape.shape is SphereShape3D:
			range_collision_shape.shape.radius = stats.range
		else:
			print_debug("Tower %s range shape is not Cylinder or Sphere." % name)
	else:
		printerr("Tower %s missing CollisionShape3D or shape for range area!" % name)

	# Configure cooldown timer properties
	cooldown_timer.wait_time = stats.attack_cooldown
	cooldown_timer.one_shot = true # Ensure it's one-shot


# Pre-warms the tower's specific projectile pool
func _initialize_projectile_pool():
	if not stats or not projectile_stats or not stats.projectile_scene:
		printerr("Tower %s cannot initialize projectile pool: Missing stats or scene." % name)
		return

	print("Tower %s initializing projectile pool (Size: %d)" % [name, projectile_pool_size])
	for i in range(projectile_pool_size):
		var proj = stats.projectile_scene.instantiate()
		# Check for necessary properties/methods before configuration
		if proj is Area3D and proj.has_method('set') and proj.has_method("set",):
			proj.stats = projectile_stats
			proj.owner_tower = self
			# Apply mesh based on these stats
			var proj_mesh_inst = proj.get_node_or_null("MeshInstance3D")
			if proj_mesh_inst and projectile_stats.mesh:
				proj_mesh_inst.mesh = projectile_stats.mesh

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
	if not is_instance_valid(node): return false
	var node_stats: BloonStats = null
	# Use safer 'get' method check
	if node.has_method("get",):
		node_stats = node.stats
	if node_stats and node_stats.is_camo and (not stats or not stats.can_see_camo):
		return false
	return true


func choose_target():
	var best_target = null; var max_progress = -1.0
	for bloon_node in targets_in_range:
		if not _is_target_valid(bloon_node): continue
		if bloon_node is PathFollow3D:
			if bloon_node.progress > max_progress:
				max_progress = bloon_node.progress; best_target = bloon_node
	return best_target


func attack(target: Node3D):
	if not stats or not projectile_stats or not stats.projectile_scene: return

	# --- Request projectile from LOCAL pool ---
	var projectile_instance: Node = null
	if not _projectile_pool.is_empty():
		projectile_instance = _projectile_pool.pop_back()
		if projectile_instance.has_method("pool_reset"):
			projectile_instance.pool_reset()
	else:
		# Fallback: Pool empty, instantiate a new one
		printerr("Tower %s projectile pool empty! Instantiating fallback." % name)
		projectile_instance = stats.projectile_scene.instantiate()
		if projectile_instance is Area3D and projectile_instance.has_method('set') and projectile_instance.has_method("set",):
			projectile_instance.stats = projectile_stats
			projectile_instance.owner_tower = self
			# Apply mesh for fallback instance too
			var proj_mesh_inst = projectile_instance.get_node_or_null("MeshInstance3D")
			if proj_mesh_inst and projectile_stats.mesh:
				proj_mesh_inst.mesh = projectile_stats.mesh
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

	# --- START THE COOLDOWN TIMER --- <<< THIS WAS MISSING
	cooldown_timer.start()


# Called by projectiles when they finish
func _return_projectile_to_pool(projectile: Node):
	if not is_instance_valid(projectile):
		printerr("Tower %s received invalid projectile to return." % name)
		return
	_projectile_pool.append(projectile)


func _on_range_area_entered(area: Area3D):
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
	var parent_node = area.get_parent()
	if parent_node in targets_in_range:
		targets_in_range.erase(parent_node)


# Function called when the cooldown timer finishes
func _on_cooldown_timer_timeout():
	# The timer is one-shot, so it stops automatically.
	# No action needed here unless you want to trigger something specific
	# when the cooldown ends (e.g., a visual effect).
	# print_debug("Tower %s cooldown finished." % name) # Optional debug
	pass


# Optional: Clean up pooled nodes when the tower is freed
func _exit_tree():
	for proj in _projectile_pool:
		if is_instance_valid(proj):
			proj.queue_free()
	_projectile_pool.clear()
