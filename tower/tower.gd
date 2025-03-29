# File: res://tower/tower.gd
extends Node3D

## Assign a TowerStats resource file (.tres) in the Inspector.
@export var stats: TowerStats

@onready var range_area: Area3D = $Area3D
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var projectile_spawn_point: Marker3D = $ProjectileSpawnPoint
@onready var range_collision_shape: CollisionShape3D = $Area3D/CollisionShape3D

var targets_in_range = [] # Array to hold the actual bloon nodes (PathFollow3D)

func _ready():
	if not stats:
		printerr("Tower scene %s is missing its TowerStats resource!" % name)
		set_physics_process(false)
		return

	# --- Setup Range ---
	if range_collision_shape.shape is CylinderShape3D:
		range_collision_shape.shape.radius = stats.range
	elif range_collision_shape.shape is SphereShape3D:
		range_collision_shape.shape.radius = stats.range
	else:
		print("Warning: Tower range shape not Cylinder or Sphere.")

	# --- Connect Signals ---
	if not range_area.area_entered.is_connected(_on_range_area_entered):
		range_area.area_entered.connect(_on_range_area_entered)
	if not range_area.area_exited.is_connected(_on_range_area_exited):
		range_area.area_exited.connect(_on_range_area_exited)

	# --- Setup Cooldown Timer ---
	if not cooldown_timer:
		printerr("CooldownTimer node not found in Tower scene %s!" % name)
		set_physics_process(false)
		return
	cooldown_timer.wait_time = stats.attack_cooldown
	cooldown_timer.one_shot = true
	if not cooldown_timer.timeout.is_connected(_on_cooldown_timer_timeout):
		cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)


func _physics_process(delta):
	# Clean up invalid targets first
	targets_in_range = targets_in_range.filter(Callable(self, "_is_target_valid"))

	if not targets_in_range.is_empty() and cooldown_timer.is_stopped():
		var target = choose_target()
		if is_instance_valid(target):
			attack(target)


func _is_target_valid(node):
	# Additional check: If a camo bloon somehow got into the list but the tower lost camo detection (e.g. buff expired)
	if is_instance_valid(node) and node.stats and node.stats.is_camo and not stats.can_see_camo:
		return false
	return is_instance_valid(node)


func choose_target():
	# Basic "First" targeting: Find the valid bloon furthest along the path
	var best_target = null
	var max_progress = -1.0

	for bloon_node in targets_in_range:
		# Double check validity here, although filter should handle most cases
		if not _is_target_valid(bloon_node):
			continue # Skip invalid targets (e.g. camo bloons if tower can't see them)

		if bloon_node is PathFollow3D: # No need to check group again if it's already filtered
			if bloon_node.progress > max_progress:
				max_progress = bloon_node.progress
				best_target = bloon_node
	return best_target


func attack(target: Node3D):
	if not stats or not stats.projectile_scene:
		printerr("Cannot attack: Missing stats or projectile scene in Tower %s." % name)
		return

	look_at(target.global_position, Vector3.UP)

	var projectile_instance = stats.projectile_scene.instantiate()
	get_tree().root.add_child(projectile_instance)
	projectile_instance.global_transform = projectile_spawn_point.global_transform

	if projectile_instance.has_method("set_target"):
		projectile_instance.set_target(target)
	elif projectile_instance.has_method("initialize_direction"):
		projectile_instance.initialize_direction(projectile_instance.global_transform.basis.z)

	cooldown_timer.start()


func _on_range_area_entered(area: Area3D):
	if not stats: return # Tower has no stats, cannot detect

	var parent_node = area.get_parent()

	# Initial validation: Is it a valid bloon node?
	if not (is_instance_valid(parent_node) and parent_node.is_in_group("bloons")):
		return

	# --- Camo Check ---
	var bloon_stats: BloonStats = parent_node.stats
	if not bloon_stats:
		printerr("Entering bloon %s has no stats!" % parent_node.name)
		return # Cannot determine if camo

	# If the bloon is camo AND the tower cannot see camo, ignore it.
	if bloon_stats.is_camo and not stats.can_see_camo:
		print("Tower cannot see Camo bloon: ", parent_node.name)
		return # Do not add to targets_in_range
	# --- End Camo Check ---

	# Add valid, visible target
	if not parent_node in targets_in_range:
		targets_in_range.append(parent_node)
		print("Bloon entered range and is visible: ", parent_node.name)


func _on_range_area_exited(area: Area3D):
	var parent_node = area.get_parent()
	# No need for camo check on exit, just remove if it's in the list
	if parent_node in targets_in_range:
		targets_in_range.erase(parent_node)
		print("Bloon exited range: ", parent_node.name)


func _on_cooldown_timer_timeout():
	pass
